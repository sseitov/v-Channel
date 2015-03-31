//
//  ViewController.m
//  IOSocket
//
//  Created by Sergey Seitov on 29.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ViewController.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "ServerController.h"
#import "VideoController.h"
#include "Common.h"

@interface ViewController () <VideoControllerDelegate> {
    dispatch_queue_t _readQueue;
    dispatch_queue_t _writeQueue;
}

@property (strong, nonatomic) GCDAsyncSocket *readSocket;
@property (strong, nonatomic) GCDAsyncSocket *writeSocket;

@property (weak, nonatomic) ServerController *server;
@property (weak, nonatomic) VideoController *client;

@property (strong, nonatomic) NSMutableData* readData;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _readQueue = dispatch_queue_create("readQueue", DISPATCH_QUEUE_SERIAL);
    _writeQueue = dispatch_queue_create("writeQueue", DISPATCH_QUEUE_SERIAL);
    _readSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_readQueue];
    _writeSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_writeQueue];
    
    _readData = [NSMutableData new];
}

- (void)viewDidAppear:(BOOL)animated
{
    if ([_server start]) {
        [_readSocket connectToHost:SERVER_HOST onPort:SERVER_PORT withTimeout:CONNECTION_TIMEOUT error:nil];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UINavigationController *vc = segue.destinationViewController;
    if ([segue.identifier isEqualToString:@"Video"]) {
        _client = (VideoController*)vc.topViewController;
        _client.delegate = self;
    } else {
        _server = (ServerController*)vc.topViewController;
    }
}

#pragma mark - Socket delegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    if (sock == _readSocket) {
        [_writeSocket connectToHost:SERVER_HOST onPort:SERVER_PORT withTimeout:CONNECTION_TIMEOUT error:nil];
    } else {
        [_readSocket readDataWithTimeout:READ_TIMEOUT tag:READ_LEFT_TAG];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    if (tag != READ_LEFT_TAG) {
        return;
    }
    [_readData appendData:data];
    if (_readData.length >= sizeof(struct Packet)) {
        struct Packet *pPacket = (struct Packet *)_readData.bytes;
        if (_readData.length >= pPacket->dataLength + sizeof(struct Packet)) {
            switch (pPacket->command) {
                case Accept:
                    [_client startCapture];
                    break;
                default:
                    if (pPacket->dataLength > 0) {
                        if (pPacket->media == Video) {
                            NSData* params = [NSData dataWithBytes:((uint8_t*)data.bytes+sizeof(struct Packet)) length:pPacket->dataLength];
                            [_client receiveVideoCommand:pPacket->command withData:params];
                        }
                    } else {
                        if (pPacket->media == Video) {
                            [_client receiveVideoCommand:pPacket->command withData:nil];
                        }
                    }
                    break;
            }
            [_readData replaceBytesInRange:NSMakeRange(0, pPacket->dataLength + sizeof(struct Packet)) withBytes:NULL length:0];
        }
    }
    [sock readDataWithTimeout:READ_TIMEOUT tag:READ_LEFT_TAG];
}

#pragma mark - Video delegate

- (void)sendVideoCommand:(enum Command)command withData:(NSData*)data
{
    struct Packet packet;
    packet.command = command;
    packet.media = Video;
    packet.dataLength = data ? (uint32_t)data.length : 0;
    
    if (packet.dataLength > 0 && data) {
        NSMutableData *sendData = [NSMutableData dataWithBytes:&packet length:sizeof(packet)];
        [sendData appendData:data];
        [_writeSocket writeData:sendData withTimeout:WRITE_TIMEOUT tag:1];
    } else {
        [_writeSocket writeData:[NSData dataWithBytes:&packet length:sizeof(packet)] withTimeout:WRITE_TIMEOUT tag:1];
    }
}

@end
