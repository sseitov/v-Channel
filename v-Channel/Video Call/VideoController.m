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

enum MediaType {
    Video,
    Audio
};

enum Command {
    Start,
    Started,
    Stop,
    Data,
    Finish
};

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
        NSDictionary *json = message.message;
        if ([[json objectForKey:@"media"] intValue] == Video) {
            switch ([[json objectForKey:@"command"] intValue]) {
                case Start:
                    if (!_decoder.isOpened) {
                        NSDictionary* params = [json objectForKey:@"data"];
                        if ([_decoder openForWidth:[[params objectForKey:@"width"] intValue]
                                            height:[[params objectForKey:@"height"] intValue]
                                               sps:[[NSData alloc] initWithBase64EncodedString:[params objectForKey:@"sps"] options:kNilOptions]
                                               pps:[[NSData alloc] initWithBase64EncodedString:[params objectForKey:@"pps"] options:kNilOptions]])
                        {
                            [self started];
                        }
                    }
                    break;
                case Started:
                    self.decoderIsOpened = YES;
                    break;
                case Stop:
                    [_decoder close];
                    [_peerView clear];
                    self.decoderIsOpened = NO;
                    break;
                case Data:
                    if (_decoder.isOpened) {
                        [_decoder decodeData:[[NSData alloc] initWithBase64EncodedString:[json objectForKey:@"data"]
                                                                                 options:kNilOptions]];
                    }
                    break;
                case Finish:
                    [self finish];
                    break;
                default:
                    break;
            }
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
//        [_decoder close];
        [_selfView clear];
//        [_peerView clear];
        self.isCapture = NO;
        
        NSError *error;
        NSDictionary *json = @{@"media" : [NSNumber numberWithInt:Video], @"command" : [NSNumber numberWithInt:Stop]};
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
        NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSLog(@"send %d bytes", (int)jsonStr.length);
        [PubNub sendMessage:jsonStr toChannel:_outChannel];

    }
}

- (IBAction)switchCamera:(id)sender
{
    [self stopCapture];
    [[Camera shared] switchCamera];
    [self startCapture];
}

- (void)finish
{
    [self stopCapture];
    [[PNObservationCenter defaultCenter] removeMessageReceiveObserver:self];
    [PubNub unsubscribeFrom:@[_inChannel]];
    [[Camera shared] shutdown];
    
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
  
    [self.delegate callControllerDidFinish];
}

- (void)started
{
    NSError *error;
    NSDictionary *json = @{@"media" : [NSNumber numberWithInt:Video], @"command" : [NSNumber numberWithInt:Started]};
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"send %d bytes", (int)jsonStr.length);
    [PubNub sendMessage:jsonStr toChannel:_outChannel];
}

- (IBAction)endCall:(UIBarButtonItem*)sender
{
    NSError *error;
    NSDictionary *json = @{@"media" : [NSNumber numberWithInt:Video], @"command" : [NSNumber numberWithInt:Finish]};
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"send %d bytes", (int)jsonStr.length);
    [PubNub sendMessage:jsonStr toChannel:_outChannel];

    [self finish];
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
    NSDictionary *json;
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
        json = @{@"media" : [NSNumber numberWithInt:Video],
                 @"command" : [NSNumber numberWithInt:Start],
                 @"data" : params};
    } else {
        json = @{@"media" : [NSNumber numberWithInt:Video],
                 @"command" : [NSNumber numberWithInt:Data],
                 @"data" : [data base64EncodedStringWithOptions:kNilOptions]};
    }
    
    NSError *error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
    if (!error) {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSLog(@"send %d bytes", (int)jsonString.length);
        [PubNub sendMessage:jsonString toChannel:_outChannel];
    }
}

#pragma mark - VTDeccoder delegare

- (void)decoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer
{
    [_peerView drawBuffer:buffer];
    CFRelease(buffer);
}

@end
