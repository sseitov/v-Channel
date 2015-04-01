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
    
    dispatch_semaphore_t _sem;
    dispatch_queue_t _readSocketQueue;
    dispatch_queue_t _writeSocketQueue;
    dispatch_queue_t _readDelegateQueue;
    dispatch_queue_t _writeDelegateQueue;
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

@property (strong, nonatomic) GCDAsyncSocket *readSocket;
@property (strong, nonatomic) GCDAsyncSocket *writeSocket;
@property (strong, nonatomic) NSMutableData* readData;

@property (atomic) BOOL isConnected;

@property (strong, nonatomic) VideoController* video;

@end

@implementation CallController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _sem = dispatch_semaphore_create(0);
    
    _readSocketQueue = dispatch_queue_create("readSocketQueue", DISPATCH_QUEUE_SERIAL);
    _writeSocketQueue = dispatch_queue_create("writeSocketQueue", DISPATCH_QUEUE_SERIAL);
    _readDelegateQueue = dispatch_queue_create("readDelegateQueue", DISPATCH_QUEUE_SERIAL);
    _writeDelegateQueue = dispatch_queue_create("writeDelegateQueue", DISPATCH_QUEUE_SERIAL);
    
    _readSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_readDelegateQueue socketQueue:_readSocketQueue];
    _writeSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_writeDelegateQueue socketQueue:_writeSocketQueue];
    
    _readData = [NSMutableData new];
    
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
    if (self.incommingCall) {
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Video"]) {
        _video = [segue destinationViewController];
        _video.delegate = self;
        _video.title = _peer[@"email"];
    }
}

- (IBAction)call:(UIButton*)sender
{
    if (self.isConnected) {
        self.isConnected = NO;
        [_readSocket disconnect];
        [_writeSocket disconnect];
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
        [_readSocket connectToHost:SERVER_HOST onPort:SERVER_PORT withTimeout:CONNECTION_TIMEOUT error:nil];
    }
}

- (IBAction)acceptIncomming:(UIButton *)sender
{
    [_ringtone stop];
    [_animation stopAnimating];
    self.isConnected = YES;
    [_readSocket connectToHost:SERVER_HOST onPort:SERVER_PORT withTimeout:CONNECTION_TIMEOUT error:nil];
}

- (IBAction)rejectIncomming:(UIButton *)sender
{
    [_ringtone stop];
    [_animation stopAnimating];
    self.isConnected = NO;
    [_readSocket connectToHost:SERVER_HOST onPort:SERVER_PORT withTimeout:CONNECTION_TIMEOUT error:nil];
}

- (void)accept
{
    self.incommingCall = YES;
    dispatch_async(dispatch_get_main_queue(), ^() {
        [_ringtone stop];
        [self performSegueWithIdentifier:@"Video" sender:self];
    });
}

- (void)reject
{
    self.incommingCall = NO;
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

#pragma mark - VideoController delegate

- (void)sendVideoCommand:(enum Command)command withData:(NSData*)data
{
    struct Packet packet;
    packet.command = command;
    packet.media = Video;
    packet.dataLength = data ? (uint32_t)data.length : 0;
    
    if (packet.dataLength > 0 && data) {
        NSMutableData *sendData = [NSMutableData dataWithBytes:&packet length:sizeof(packet)];
        [sendData appendData:data];
        [_writeSocket writeData:sendData withTimeout:WRITE_TIMEOUT tag:MASTER];
    } else {
        [_writeSocket writeData:[NSData dataWithBytes:&packet length:sizeof(packet)] withTimeout:WRITE_TIMEOUT tag:MASTER];
    }
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
}

- (void)didFinish
{
    self.isConnected = NO;
    self.incommingCall = NO;
    [_writeSocket disconnect];
    [self.delegate callControllerDidFinish];
}

#pragma mark - Socket delegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    if (sock == _readSocket) {
        if (self.incommingCall) {
            if (self.isConnected) {
                [_writeSocket connectToHost:SERVER_HOST onPort:SERVER_PORT withTimeout:CONNECTION_TIMEOUT error:nil];
            } else {
                self.incommingCall = NO;
                [_readSocket disconnect];
                dispatch_async(dispatch_get_main_queue(), ^() {
                    [self updateGUI];
                });
            }
        } else {
            [_writeSocket connectToHost:SERVER_HOST onPort:SERVER_PORT withTimeout:CONNECTION_TIMEOUT error:nil];
        }
    } else {
        [_readSocket readDataWithTimeout:READ_TIMEOUT tag:MASTER];
        self.isConnected = YES;
        self.incommingCall = NO;
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    if (tag == MASTER) {
        [_readData appendData:data];
        if (_readData.length >= sizeof(struct Packet)) {
            struct Packet *pPacket = (struct Packet *)_readData.bytes;
            if (_readData.length >= pPacket->dataLength + sizeof(struct Packet)) {
                switch (pPacket->command) {
                    case Accept:
                        [self accept];
                        break;
                    default:
                        if (_readData.length >= pPacket->dataLength + sizeof(struct Packet)) {
                            if (pPacket->dataLength > 0) {
                                if (pPacket->media == Video) {
                                    NSData* params = [NSData dataWithBytes:((uint8_t*)data.bytes+sizeof(struct Packet)) length:pPacket->dataLength];
                                    [_video receiveVideoCommand:pPacket->command withData:params];
                                }
                            } else {
                                if (pPacket->media == Video) {
                                    [_video receiveVideoCommand:pPacket->command withData:nil];
                                }
                            }
                        }
                        break;
                }
                [_readData replaceBytesInRange:NSMakeRange(0, pPacket->dataLength + sizeof(struct Packet)) withBytes:NULL length:0];
            }
        }
        [sock readDataWithTimeout:READ_TIMEOUT tag:MASTER];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    if (tag == MASTER) {
        dispatch_semaphore_signal(_sem);
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (self.isConnected) {
        self.isConnected = NO;
        if (!self.incommingCall) {
            [self reject];
        } else {
            dispatch_semaphore_signal(_sem);
            [_video shutdown];
            self.incommingCall = NO;
            dispatch_async(dispatch_get_main_queue(), ^() {
                [self.delegate callControllerDidFinish];
            });
        }
    }
}

@end
