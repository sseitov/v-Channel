//
//  ServerController.m
//  IOSocket
//
//  Created by Sergey Seitov on 29.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ServerController.h"
#include "Common.h"
#include "Channel.h"

@interface ServerController () {
    dispatch_queue_t _socketQueue;
    dispatch_queue_t _delegateQueue;
}

@property (weak, nonatomic) IBOutlet UITextView *logView;

@property (strong, nonatomic) GCDAsyncSocket *serverSocket;
@property (strong, nonatomic) Channel *channel;

@end

@implementation ServerController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _socketQueue = dispatch_queue_create("socketQueue", DISPATCH_QUEUE_SERIAL);
    _delegateQueue = dispatch_queue_create("delegateQueue", DISPATCH_QUEUE_SERIAL);
    
    _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_delegateQueue socketQueue:_socketQueue];
}

- (BOOL)start
{
    NSError *error = nil;
    if(![_serverSocket acceptOnPort:SERVER_PORT error:&error])
    {
        [self printLog:[NSString stringWithFormat:@"Error starting server: %@", error]];
        return NO;
    } else {
        [self printLog:[NSString stringWithFormat:@"Server started on port: %d", SERVER_PORT]];
        return YES;
    }
}

- (void)printLog:(NSString*)text
{
    dispatch_async(dispatch_get_main_queue(), ^() {
        _logView.text = [_logView.text stringByAppendingString:[NSString stringWithFormat:@"%@\n", text]];
    });
}

#pragma mark - Socket delegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    if (!_channel) {
        _channel = [[Channel alloc] init];
        _channel.writeSocket = newSocket;
        [self printLog:@"Write Socket Connected"];
    } else {
        _channel.readSocket = newSocket;
        [self printLog:@"Read Socket Connected"];
        [self printLog:@"Send Accept command"];
        struct Packet acceptPacket = {Accept, 0};
        [_channel.writeSocket writeData:[NSData dataWithBytes:&acceptPacket length:sizeof(struct Packet)] withTimeout:WRITE_TIMEOUT tag:0];
        [_channel.readSocket readDataWithTimeout:READ_TIMEOUT tag:READ_TAG];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    if (tag == READ_TAG && _channel) {
        [_channel.writeSocket writeData:data withTimeout:WRITE_TIMEOUT tag:WRITE_TAG];
        [_channel.readSocket readDataWithTimeout:READ_TIMEOUT tag:READ_TAG];
    }
}

@end
