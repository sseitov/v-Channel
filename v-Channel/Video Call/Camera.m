//
//  Camera.m
//  DirectVideo
//
//  Created by Sergey Seitov on 02.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "Camera.h"

@interface Camera () {
    
    AVCaptureSession* _session;
    AVCaptureVideoPreviewLayer* _preview;
}

@end

@implementation Camera

+(Camera*)shared
{
    static Camera* _shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [self new];
    });
    return _shared;
}

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (void) startup
{
    if (_session == nil) {
        // create capture device with video input
        _session = [[AVCaptureSession alloc] init];
        AVCaptureDevice* dev = [self cameraWithPosition:AVCaptureDevicePositionFront];
        AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:dev error:nil];
        [_session addInput:input];
        
        _output = [[AVCaptureVideoDataOutput alloc] init];
        _output.videoSettings = self.captureSettings;
        [_session addOutput:_output];
        [_session setSessionPreset:AVCaptureSessionPresetLow];
        
        // start capture and a preview layer
        [_session commitConfiguration];
        [_session startRunning];
                
        _preview = [AVCaptureVideoPreviewLayer layerWithSession:_session];
        _preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
}

- (NSDictionary*)captureSettings
{
    //kCVPixelFormatType_32BGRA
    return @{(id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]};
}

- (void) shutdown
{
    if (_session)
    {
        [_session stopRunning];
        _session = nil;
    }
}

- (AVCaptureVideoPreviewLayer*)getPreviewLayer
{
    return _preview;
}

-(void)switchCamera
{
    //Change camera source
    if(_session) {
        //Indicate that some changes will be made to the session
        [_session beginConfiguration];
        
        //Remove existing input
        AVCaptureInput* currentCameraInput = [_session.inputs objectAtIndex:0];
        [_session removeInput:currentCameraInput];
        
        //Get new input
        AVCaptureDevice *newCamera = nil;
        if(((AVCaptureDeviceInput*)currentCameraInput).device.position == AVCaptureDevicePositionBack) {
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
        } else {
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
        }
        
        //Add input to session
        AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newCamera error:nil];
        [_session addInput:newVideoInput];
        
        //Commit all the configuration changes at once
        [_session commitConfiguration];
    }
}

// Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position) return device;
    }
    return nil;
}

@end
