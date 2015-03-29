//
//  CallController.m
//  v-Channel
//
//  Created by Sergey Seitov on 16.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "CallController.h"
#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import "VideoController.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>

#include "Common.h"

@interface CallController () <VideoControllerDelegate> {
    dispatch_queue_t _socketQueue;
    dispatch_queue_t _delegateQueue;
    long _writeTag;
}

@property (weak, nonatomic) IBOutlet UIImageView *photo;
@property (weak, nonatomic) IBOutlet UIImageView *animation;
@property (weak, nonatomic) IBOutlet UIButton *acceptButton;
@property (weak, nonatomic) IBOutlet UIButton *rejectButton;
@property (weak, nonatomic) IBOutlet UIButton *callButton;

- (IBAction)call:(UIButton*)sender;
- (IBAction)acceptIncomming:(UIButton *)sender;
- (IBAction)rejectIncomming:(UIButton *)sender;

@property (strong, nonatomic) AVAudioPlayer *ringtone;

@property (strong, nonatomic) GCDAsyncSocket* socket;
@property (strong, nonatomic) NSMutableData* channelData;
@property (nonatomic) BOOL isConnected;
@property (nonatomic) enum Command acceptCommand;

@property (strong, nonatomic) VideoController* video;

@end

@implementation CallController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _socketQueue = dispatch_queue_create("socketQueue", NULL);
    _delegateQueue = dispatch_queue_create("delegateQueue", NULL);
    _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_delegateQueue socketQueue:_socketQueue];
    _writeTag = arc4random();
    _channelData = [NSMutableData new];
    
    if (_peer[@"displayName"]) {
        self.title = _peer[@"displayName"];
    } else {
        self.title = _peer.username;
    }
    if (_peer[@"photo"]) {
        _photo.image = [UIImage imageWithData:_peer[@"photo"]];
        _photo.layer.cornerRadius = _photo.frame.size.width/2;
        _photo.clipsToBounds = YES;
    }

    if (![AppDelegate isPad]) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                              target:self
                                                                                              action:@selector(done)];
    }
    NSMutableArray *gifs = [NSMutableArray array];
    for (int i=0; i<24; i++) {
        NSString* name = [NSString stringWithFormat:@"tmp-%d.gif", i];
        [gifs addObject:[UIImage imageNamed:name]];
    }
    _animation.image = [UIImage imageNamed:@"tmp-0.gif"];
    _animation.animationImages = gifs;
    _animation.animationDuration = 2.0f;
    _animation.animationRepeatCount = 0;
    
    [self prepareButton:_acceptButton];
    [self prepareButton:_rejectButton];
    [self prepareButton:_callButton];
}

- (void)prepareButton:(UIButton*)button
{
    button.layer.borderWidth = 1.0;
    button.layer.masksToBounds = YES;
    button.layer.cornerRadius = 7.0;
    button.layer.borderColor = button.backgroundColor.CGColor;
}

- (void)done
{
    [self.delegate callControllerDidFinish];
}

- (void)viewWillAppear:(BOOL)animated
{
    _acceptButton.hidden = YES;
    _rejectButton.hidden = YES;
    _callButton.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [self updateGUI];
}

- (void)updateGUI
{
    if (_incommingCall) {
        _ringtone = [[AVAudioPlayer alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"ringtone"
                                                                                         withExtension:@"wav"] error:nil];
        _ringtone.numberOfLoops = -1;
        if ([_ringtone prepareToPlay]) {
            [_ringtone play];
        }
        [_animation startAnimating];
        _acceptButton.hidden = NO;
        _rejectButton.hidden = NO;
        _callButton.hidden = YES;
    } else {
        _acceptButton.hidden = YES;
        _rejectButton.hidden = YES;
        _callButton.hidden = NO;
        
        [_animation stopAnimating];
        [_callButton setTitle:@"Call" forState:UIControlStateNormal];
        _callButton.backgroundColor = [UIColor colorWithRed:42./255. green:128./255. blue:83./255. alpha:1.];
    }
}

- (void)accept
{
    dispatch_async(dispatch_get_main_queue(), ^() {
        [_ringtone stop];
        [self updateGUI];
        [self performSegueWithIdentifier:@"Video" sender:self];
    });
}

- (void)reject
{
    [_socket disconnect];
    _isConnected = NO;
    dispatch_async(dispatch_get_main_queue(), ^() {
        [_ringtone stop];
        _ringtone = [[AVAudioPlayer alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"busy"
                                                                                         withExtension:@"wav"] error:nil];
        _ringtone.numberOfLoops = 0;
        if ([_ringtone prepareToPlay]) {
            [_ringtone play];
        }
        [self updateGUI];
    });
}

- (void)finish
{
    [_socket disconnect];
    _isConnected = NO;
    [_video shutdown];
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self.delegate callControllerDidFinish];
    });
}

- (IBAction)call:(UIButton*)sender
{
    if (_isConnected) {
        [_socket disconnect];
        _isConnected = NO;
        [_ringtone stop];
        [sender setTitle:@"Call" forState:UIControlStateNormal];
        sender.backgroundColor = [UIColor colorWithRed:42./255. green:128./255. blue:83./255. alpha:1.];
        [_animation stopAnimating];
    } else {
        [AppDelegate pushCallCommandToUser:_peer[@"email"]];
        _ringtone = [[AVAudioPlayer alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"calling" withExtension:@"wav"] error:nil];
        _ringtone.numberOfLoops = -1;
        if ([_ringtone prepareToPlay]) {
            [_ringtone play];
        }
        [sender setTitle:@"End Call" forState:UIControlStateNormal];
        sender.backgroundColor = [UIColor colorWithRed:1. green:102./255. blue:102./255. alpha:1.];
        [_animation startAnimating];
        _acceptCommand = NoCommand;
        [_socket connectToHost:SERVER_HOST onPort:SERVER_PORT withTimeout:CONNECTION_TIMEOUT error:nil];
    }
}

- (IBAction)acceptIncomming:(UIButton *)sender
{
    [_ringtone stop];
    [_animation stopAnimating];
    _acceptCommand = Accept;
    _incommingCall = NO;
    [_socket connectToHost:SERVER_HOST onPort:SERVER_PORT withTimeout:CONNECTION_TIMEOUT error:nil];
}

- (IBAction)rejectIncomming:(UIButton *)sender
{
    [_ringtone stop];
    [_animation stopAnimating];
    _acceptCommand = Reject;
    [_socket connectToHost:SERVER_HOST onPort:SERVER_PORT withTimeout:CONNECTION_TIMEOUT error:nil];
    _incommingCall = NO;
    [self updateGUI];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Video"]) {
        _video = [segue destinationViewController];
        _video.delegate = self;
        _video.title = _peer[@"email"];
    }
}

- (void)videoSendCommand:(enum Command)command withData:(NSData*)data
{
    struct Packet packet;
    packet.command = command;
    packet.dataLength = data ? (uint32_t)data.length : 0;
    
    if (packet.dataLength > 0 && data) {
        NSMutableData *sendData = [NSMutableData dataWithBytes:&packet length:sizeof(packet)];
        [sendData appendData:data];
        [_socket writeData:sendData withTimeout:WRITE_TIMEOUT tag:_writeTag];
    } else {
        [_socket writeData:[NSData dataWithBytes:&packet length:sizeof(packet)] withTimeout:WRITE_TIMEOUT tag:_writeTag];
    }
}

#pragma mark - Socket delegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    _isConnected = YES;
    [_channelData setLength:0];
    if (_acceptCommand) {
        struct Packet packet = {_acceptCommand, 0};
        if (_acceptCommand == Reject) {
            _isConnected = NO;
        }
        [sock writeData:[NSData dataWithBytes:&packet length:sizeof(packet)] withTimeout:WRITE_TIMEOUT tag:_writeTag];
    } else {
        [sock readDataWithTimeout:READ_TIMEOUT tag:READ_TAG];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    [_channelData appendData:data];
    if (_channelData.length >= sizeof(Packet)) {
        struct Packet *pPacket = (struct Packet *)_channelData.bytes;
        switch (pPacket->command) {
            case Accept:
                [self accept];
                [_channelData replaceBytesInRange:NSMakeRange(0, pPacket->dataLength + sizeof(Packet)) withBytes:NULL length:0];
                break;
            case Reject:
                [self reject];
                break;
            case Finish:
                [self finish];
                break;
            default:
                if (_channelData.length >= pPacket->dataLength + sizeof(Packet)) {
                    if (pPacket->dataLength > 0) {
                        NSData* params = [NSData dataWithBytes:((uint8_t*)data.bytes+sizeof(Packet)) length:pPacket->dataLength];
                        [_video videoReceiveCommand:pPacket->command withData:params];
                    } else {
                        [_video videoReceiveCommand:pPacket->command withData:nil];
                    }
                    [_channelData replaceBytesInRange:NSMakeRange(0, pPacket->dataLength + sizeof(Packet)) withBytes:NULL length:0];
                }
                break;
        }
    }
    [sock readDataWithTimeout:READ_TIMEOUT tag:READ_TAG];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    if (tag == _writeTag) {
        [_socket readDataWithTimeout:READ_TIMEOUT tag:READ_TAG];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    [self finish];
}

@end
