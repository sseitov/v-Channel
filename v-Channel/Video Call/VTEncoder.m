//
//  VTEncoder.m
//  DirectVideo
//
//  Created by Sergey Seitov on 02.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VTEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface VTEncoder () {
    VTCompressionSessionRef _session;
}

- (BOOL)hasParameters;
- (BOOL)getParametersFromSample:(CMSampleBufferRef)sampleBuffer;

@property (nonatomic) int numFrames;

@end

void CompressionDataCallbackHandler(void *outputCallbackRefCon,
                                    void *sourceFrameRefCon,
                                    OSStatus status,
                                    VTEncodeInfoFlags infoFlags,
                                    CMSampleBufferRef sampleBuffer );

@implementation VTEncoder

- (BOOL)openForWidth:(int)width height:(int)height
{
    OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264,
                                                 NULL, NULL,
                                                 NULL, CompressionDataCallbackHandler, (__bridge void*)self, &_session);
    if (status != noErr) {
        _session = NULL;
        self.isOpened = NO;
        return NO;
    } else {
        VTSessionSetProperty(_session, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        VTSessionSetProperty(_session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
//        VTSessionSetProperty(_session, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_3_0);
        VTSessionSetProperty(_session, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
        _numFrames = 0;
        _width = width;
        _height = height;
        self.isOpened = YES;
        return YES;
    }
}

- (void)close
{
    if (_session) {
        VTCompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = NULL;
    }
    self.sps = nil;
    self.pps = nil;
    self.isOpened = NO;
}

- (void)encodeBuffer:(CVImageBufferRef)buffer
{
    if (self.isOpened) {
        CMTime presentationTimeStamp = CMTimeMake(_numFrames, 1000.0);
        CMTime duration = CMTimeMake(1, 25);
        VTEncodeInfoFlags infoFlagsOut;
        OSStatus err = VTCompressionSessionEncodeFrame(_session, buffer, presentationTimeStamp, duration,
                                                       NULL, NULL, &infoFlagsOut);
        if (err != noErr) {
            NSLog(@"error comression session %d", (int)err);
        } else {
            VTCompressionSessionCompleteFrames(_session, kCMTimeInvalid);
            _numFrames++;
        }
    }
}


- (BOOL)hasParameters
{
    return (self.sps != nil && self.pps != nil);
}

- (BOOL)getParametersFromSample:(CMSampleBufferRef)sampleBuffer
{
    CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
    size_t spsSize, ppsSize;
    size_t spsCount, ppsCount;
    const uint8_t* sps, *pps;
    
    OSStatus err = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sps, &spsSize, &spsCount, NULL );
    if (err != noErr) {
        return NO;
    }
    err = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pps, &ppsSize, &ppsCount, NULL );
    if (err != noErr) {
        return NO;
    }
    self.sps = [NSData dataWithBytes:sps length:spsSize];
    self.pps = [NSData dataWithBytes:pps length:ppsSize];
    return YES;
}

@end

void CompressionDataCallbackHandler(void *outputCallbackRefCon,
                                    void *sourceFrameRefCon,
                                    OSStatus status,
                                    VTEncodeInfoFlags infoFlags,
                                    CMSampleBufferRef sampleBuffer )
{
    if (status != noErr) {
        NSLog(@"error encode callback");
    } else {
        VTEncoder* encoder = (__bridge VTEncoder*)outputCallbackRefCon;
        if (![encoder hasParameters]) {
            [encoder getParametersFromSample:sampleBuffer];
        }
        CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        size_t lengthAtOffset, totalLength;
        char *dataPointer;
        OSStatus err = CMBlockBufferGetDataPointer(dataBuffer, 0, &lengthAtOffset, &totalLength, &dataPointer);
        if (err == noErr) {
            NSData* data = [[NSData alloc] initWithBytes:dataPointer length:totalLength];
            [encoder.delegate encoder:encoder encodedData:data];
        }
    }
}
