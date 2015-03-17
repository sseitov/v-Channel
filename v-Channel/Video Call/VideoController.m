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
#import "PNImports.h"

@interface VideoController () <AVCaptureVideoDataOutputSampleBufferDelegate, VTEncoderDelegate, VTDecoderDelegate> {
    
    dispatch_queue_t _captureQueue;
}

@property (weak, nonatomic) IBOutlet DragView *selfView;
@property (weak, nonatomic) IBOutlet VideoLayerView *peerView;

- (IBAction)switchCamera:(id)sender;
- (IBAction)endCall:(UIBarButtonItem*)sender;

@property (strong, nonatomic) VTEncoder* encoder;
@property (strong, nonatomic) VTDecoder* decoder;

@property (nonatomic) UIDeviceOrientation orientation;
@property (nonatomic) double aspectRatio;
@property (nonatomic) BOOL isCapture;

@property (strong, nonatomic) PNChannel *inChannel;
@property (strong, nonatomic) PNChannel *outChannel;

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
    
    _outChannel = [PNChannel channelWithName:[Storage getLogin] shouldObservePresence:YES];
    _inChannel = [PNChannel channelWithName:_peer.userId shouldObservePresence:YES];
    [PubNub subscribeOn:@[_inChannel]];
    
    [[PNObservationCenter defaultCenter] addMessageReceiveObserver:self withBlock:^(PNMessage *message) {
        NSData* data = [[NSData alloc] initWithBase64EncodedString:message.message options:kNilOptions];
        NSLog(@"received %d bytes", (int)data.length);
        if (!_decoder.isOpened) {
            CGSize sz;
            if (_aspectRatio <= 1.) {
                sz.width = _peerView.frame.size.width;
                sz.height = _peerView.frame.size.width * _aspectRatio;
            } else {
                sz.height = _peerView.frame.size.height;
                sz.width = _peerView.frame.size.height / _aspectRatio;
            }
            [_decoder openForWidth:sz.width height:sz.height sps:_encoder.sps pps:_encoder.pps];
        }
        if (_decoder.isOpened) {
            [_decoder decodeData:data];
        }
    }];

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
    [self startCapture];
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
        [_decoder close];
        [_selfView clear];
        [_peerView clear];
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
    [self stopCapture];
    [[PNObservationCenter defaultCenter] removeMessageReceiveObserver:self];
    [PubNub unsubscribeFrom:@[_inChannel]];
    [[Camera shared] shutdown];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self.navigationController popViewControllerAnimated:YES];
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
    NSString *dataStr = [data base64EncodedStringWithOptions:kNilOptions];
    NSLog(@"send %d bytes", (int)dataStr.length);
    [PubNub sendMessage:dataStr toChannel:_outChannel];
}

#pragma mark - VTDeccoder delegare

- (void)decoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
    [_peerView drawBuffer:buffer];
    CFRelease(buffer);
}

@end
