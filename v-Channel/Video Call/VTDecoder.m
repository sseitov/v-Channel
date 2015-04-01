//
//  VTDecoder.m
//  DirectVideo
//
//  Created by Sergey Seitov on 03.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VTDecoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface VTDecoder () {
    VTDecompressionSessionRef _session;
    CMVideoFormatDescriptionRef _videoFormat;
    CMSampleTimingInfo _timingInfo;
}

@property (nonatomic) int numFrames;

@end

void DeompressionDataCallbackHandler(void *decompressionOutputRefCon,
                                     void *sourceFrameRefCon,
                                     OSStatus status,
                                     VTDecodeInfoFlags infoFlags,
                                     CVImageBufferRef imageBuffer,
                                     CMTime presentationTimeStamp,
                                     CMTime presentationDuration );

@implementation VTDecoder

- (CMSampleTimingInfo*)timing
{
    return &_timingInfo;
}

- (BOOL)openForWidth:(int)width height:(int)height sps:(NSData*)sps pps:(NSData*)pps
{
    const uint8_t* const parameterSetPointers[2] = { (const uint8_t*)sps.bytes, (const uint8_t*)pps.bytes };
    const size_t parameterSetSizes[2] = { sps.length, pps.length };
    OSStatus err = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                       2,
                                                                       parameterSetPointers,
                                                                       parameterSetSizes,
                                                                       4,
                                                                       &_videoFormat);
    if (err != noErr) {
        return NO;
    }
    
    NSDictionary* destinationPixelBufferAttributes = @{
                                                       (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
                                                       (id)kCVPixelBufferWidthKey : [NSNumber numberWithInt:width],
                                                       (id)kCVPixelBufferHeightKey : [NSNumber numberWithInt:height],
                                                       (id)kCVPixelBufferOpenGLCompatibilityKey : [NSNumber numberWithBool:YES]
                                                       };

    VTDecompressionOutputCallbackRecord outputCallback;
    outputCallback.decompressionOutputCallback = DeompressionDataCallbackHandler;
    outputCallback.decompressionOutputRefCon = (__bridge void*)self;
    
    OSStatus status = VTDecompressionSessionCreate(NULL,
                                          _videoFormat,
                                          NULL,
                                          (__bridge CFDictionaryRef)destinationPixelBufferAttributes,
                                          &outputCallback,
                                          &_session);
    if (status == noErr) {
        VTSessionSetProperty(_session, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)[NSNumber numberWithInt:1]);
        VTSessionSetProperty(_session, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
        _numFrames = 0;
        self.isOpened = YES;
        return YES;
    } else {
        return NO;
    }
}

- (void)close
{
    if (_session) {
        VTDecompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = NULL;
    }
    if (_videoFormat) {
        CFRelease(_videoFormat);
        _videoFormat = NULL;
    }
    self.isOpened = NO;
}

- (void)decodeData:(NSData*)data
{
    _timingInfo.presentationTimeStamp = CMTimeMake(_numFrames, 1000.0);
    _timingInfo.duration =CMTimeMake(1, 25);
    _timingInfo.decodeTimeStamp = kCMTimeInvalid;
    
    CMBlockBufferRef newBBufOut = NULL;
    OSStatus err = CMBlockBufferCreateWithMemoryBlock(
                                                      NULL,                 // CFAllocatorRef structureAllocator
                                                      (void*)data.bytes,    // void *memoryBlock
                                                      data.length,          // size_t blockLengt
                                                      kCFAllocatorNull,     // CFAllocatorRef blockAllocator
                                                      NULL,                 // const CMBlockBufferCustomBlockSource
                                                      0,                    // size_t offsetToData
                                                      data.length,          // size_t dataLength
                                                      FALSE,                // CMBlockBufferFlags flags
                                                      &newBBufOut);         // CMBlockBufferRef *newBBufOut
    if (err != noErr) {
        return;
    }
    
    CMSampleBufferRef decodeBuffer;
    err = CMSampleBufferCreate(kCFAllocatorDefault,
                               newBBufOut,
                               YES, NULL, NULL, // dataready
                               _videoFormat,
                               1,               // num samples
                               1,               // numSampleTimingEntries
                               &_timingInfo,
                               0, NULL,         // sampleSizeArray
                               &decodeBuffer);
    CFRelease(newBBufOut);
    if (err != noErr) {
        return;
    }
    err = VTDecompressionSessionDecodeFrame(_session,
                                            decodeBuffer,
                                            kVTDecodeFrame_EnableAsynchronousDecompression | kVTDecodeFrame_1xRealTimePlayback,
                                            decodeBuffer,
                                            NULL);
    if (err != noErr) {
        NSLog(@"decode error: %d", (int)err);
    } else {
        VTDecompressionSessionWaitForAsynchronousFrames(_session);
        _numFrames++;
    }
}

@end

void DeompressionDataCallbackHandler(void *decompressionOutputRefCon,
                                     void *sourceFrameRefCon,
                                     OSStatus status,
                                     VTDecodeInfoFlags infoFlags,
                                     CVImageBufferRef imageBuffer,
                                     CMTime presentationTimeStamp,
                                     CMTime presentationDuration )
{
    if (status == noErr) {
        VTDecoder* decoder = (__bridge VTDecoder*)decompressionOutputRefCon;
        CMVideoFormatDescriptionRef videoInfo = NULL;
        OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(NULL, imageBuffer, &videoInfo);
        if (status == noErr) {
            CMSampleBufferRef sampleBuffer = NULL;
            status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                                        imageBuffer,
                                                        true,
                                                        NULL,
                                                        NULL,
                                                        videoInfo,
                                                        decoder.timing,
                                                        &sampleBuffer);
            CFRelease(videoInfo);
            if (status == noErr) {
                [decoder.delegate decoder:decoder decodedBuffer:sampleBuffer];
            }
        }
    }
    CMSampleBufferRef decodeBuffer = (CMSampleBufferRef)sourceFrameRefCon;
    CFRelease(decodeBuffer);
}
