//
//  VideoController.m
//  iNear
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VideoController.h"
#import "DragView.h"
#import "Camera.h"
#import "VTEncoder.h"
#import "VTDecoder.h"
#import "AppDelegate.h"

@interface VideoController () <AVCaptureVideoDataOutputSampleBufferDelegate, VTEncoderDelegate, VTDecoderDelegate> {
    
    dispatch_queue_t _captureQueue;
}

@property (weak, nonatomic) IBOutlet DragView *selfView;
@property (weak, nonatomic) IBOutlet VideoLayerView *peerView;

- (IBAction)switchCamera:(id)sender;
- (IBAction)endCall:(UIBarButtonItem*)sender;

@property (strong, nonatomic) VTEncoder* encoder;
@property (strong, nonatomic) VTDecoder* decoder;
@property (atomic) BOOL decoderIsOpened;

@property (nonatomic) UIDeviceOrientation orientation;
@property (nonatomic) double aspectRatio;
@property (nonatomic) BOOL isCapture;


@end

@implementation VideoController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[Camera shared] startup];
    _captureQueue = dispatch_queue_create("com.vchannel.VideoCall", DISPATCH_QUEUE_SERIAL);

    _encoder = [[VTEncoder alloc] init];
    _encoder.delegate = self;
    
    _decoder = [[VTDecoder alloc] init];
    _decoder.delegate = self;
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:)
                                                 name: UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)shutdown
{
    NSLog(@"close video");
    [self stopCapture];
    [_decoder close];
    [[Camera shared] shutdown];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)videoReceiveCommand:(enum Command)command withData:(NSData*)data
{
    switch (command) {
        case VideoStart:
            if (!_decoder.isOpened) {
                NSDictionary* params = [NSJSONSerialization JSONObjectWithData:data
                                                                       options:kNilOptions
                                                                         error:nil];
                if (params && [_decoder openForWidth:[params[@"width"] intValue]
                                              height:[params[@"height"] intValue]
                                                 sps:[[NSData alloc] initWithBase64EncodedString:params[@"sps"] options:kNilOptions]
                                                 pps:[[NSData alloc] initWithBase64EncodedString:params[@"pps"] options:kNilOptions]])
                {
                    [self.delegate videoSendCommand:VideoStarted withData:nil];
                }
                
            }
            break;
        case VideoStarted:
            self.decoderIsOpened = YES;
            break;
        case VideoData:
            if (_decoder.isOpened) {
                [_decoder decodeData:data];
            }
            break;
        case Finish:
            break;
        default:
            break;
    }

}

- (void)deviceOrientationDidChange:(NSNotification*)notify
{
    [self stopCapture];
    _orientation = [[UIDevice currentDevice] orientation];
    [self startCapture];
}

- (void)viewWillAppear:(BOOL)animated
{
    _orientation = [[UIDevice currentDevice] orientation];
}

- (void)startCapture
{
    if (!self.isCapture) {
        [[Camera shared].output setSampleBufferDelegate:self queue:_captureQueue];
        self.isCapture = YES;
    }
}

- (void)stopCapture
{
    if (self.isCapture) {
        [[Camera shared].output setSampleBufferDelegate:nil queue:_captureQueue];
        [_encoder close];
        [_selfView clear];
        self.isCapture = NO;
    }
}

- (IBAction)switchCamera:(id)sender
{
    [self stopCapture];
    [[Camera shared] switchCamera];
    [self startCapture];
}

- (IBAction)endCall:(UIBarButtonItem*)sender
{
    [self.delegate videoSendCommand:Finish withData:nil];
}

#pragma mark - AVCaptureVideoDataOutput delegate

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (connection.supportsVideoOrientation && connection.videoOrientation != (AVCaptureVideoOrientation)_orientation) {
        [connection setVideoOrientation:(AVCaptureVideoOrientation)_orientation];
    }
    CVImageBufferRef pixelBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!_encoder.isOpened) {
        CGSize sz = CVImageBufferGetDisplaySize(pixelBuffer);
        if (UIInterfaceOrientationIsLandscape(_orientation)) {
            [_encoder openForWidth:sz.width height:sz.height];
        } else {
            [_encoder openForWidth:sz.height height:sz.width];
        }
        _aspectRatio = sz.width / sz.height;
    }
    if (_encoder.isOpened) {
        [_encoder encodeBuffer:pixelBuffer];
    }
    [_selfView drawBuffer:sampleBuffer];
}

#pragma mark - VTEncoder delegare

- (void)encoder:(VTEncoder*)encoder encodedData:(NSData*)data
{
    if (!self.decoderIsOpened) {
        CGSize sz;
        if (_aspectRatio <= 1.) {
            sz.width = _peerView.frame.size.width;
            sz.height = _peerView.frame.size.width * _aspectRatio;
        } else {
            sz.height = _peerView.frame.size.height;
            sz.width = _peerView.frame.size.height / _aspectRatio;
        }
        
        NSDictionary *params = @{@"width" : [NSNumber numberWithInt:sz.width],
                                 @"height" : [NSNumber numberWithInt:sz.height],
                                 @"sps" : [_encoder.sps base64EncodedStringWithOptions:kNilOptions],
                                 @"pps" : [_encoder.pps base64EncodedStringWithOptions:kNilOptions]};
        [self.delegate videoSendCommand:VideoStart withData:[NSJSONSerialization dataWithJSONObject:params
                                                                                            options:kNilOptions
                                                                                              error:nil]];
    } else {
        [self.delegate videoSendCommand:VideoData withData:data];
    }
}

#pragma mark - VTDeccoder delegare

- (void)decoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
    [_peerView drawBuffer:buffer];
    CFRelease(buffer);
}

@end
