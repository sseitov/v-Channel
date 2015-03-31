//
//  ViewController.m
//  v-Server
//
//  Created by Sergey Seitov on 27.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ViewController.h"
#include "Common.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>

@interface Channel : NSObject

@property (strong, nonatomic) GCDAsyncSocket *readSocket;
@property (strong, nonatomic) GCDAsyncSocket *writeSocket;

@end

@implementation Channel

@end

@interface Room : NSObject

@property (strong, nonatomic) Channel *rightChannel;
@property (strong, nonatomic) Channel *leftChannel;

@end

@implementation Room

@end

@interface ViewController () {
    dispatch_queue_t _socketQueue;
    dispatch_queue_t _delegateQueue;
}

@property (unsafe_unretained) IBOutlet NSTextView *log;

@property (strong, nonatomic) GCDAsyncSocket *serverSocket;
@property (nonatomic) BOOL isRunning;
@property (strong, nonatomic) Room *room;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _socketQueue = dispatch_queue_create("socketQueue", DISPATCH_QUEUE_SERIAL);
    _delegateQueue = dispatch_queue_create("delegateQueue", DISPATCH_QUEUE_SERIAL);

    _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                               delegateQueue:_delegateQueue
                                                 socketQueue:_socketQueue];
    NSError *error = nil;
    if(![_serverSocket acceptOnPort:SERVER_PORT error:&error])
    {
        [self printLog:[NSString stringWithFormat:@"Error starting server: %@", error]];
        return;
    } else {
        [self printLog:[NSString stringWithFormat:@"Server started on port: %d", SERVER_PORT]];
        _isRunning = YES;
    }

}

- (void)printLog:(NSString*)text
{
    dispatch_async(dispatch_get_main_queue(), ^() {
        NSString *paragraph = [NSString stringWithFormat:@"%@\n", text];
        
        NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1];
        [attributes setObject:[NSColor purpleColor] forKey:NSForegroundColorAttributeName];
        
        NSAttributedString *as = [[NSAttributedString alloc] initWithString:paragraph attributes:attributes];
        
        [[_log textStorage] appendAttributedString:as];
    });
}

#pragma mark - Socket delegate

- (void)sendAccept
{
    [self printLog:@"Send Accept command"];
    struct Packet acceptPacket = {Accept, 0};
    
    [_room.rightChannel.writeSocket writeData:[NSData dataWithBytes:&acceptPacket length:sizeof(struct Packet)] withTimeout:WRITE_TIMEOUT tag:0];
    [_room.rightChannel.readSocket readDataWithTimeout:READ_TIMEOUT tag:READ_RIGHT_TAG];
    
    [_room.leftChannel.writeSocket writeData:[NSData dataWithBytes:&acceptPacket length:sizeof(struct Packet)] withTimeout:WRITE_TIMEOUT tag:0];
    [_room.leftChannel.readSocket readDataWithTimeout:READ_TIMEOUT tag:READ_LEFT_TAG];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    if (!_room) {
        _room = [[Room alloc] init];
        _room.rightChannel = [Channel new];
        _room.rightChannel.writeSocket = newSocket;
        [self printLog:@"Create room"];
        [self printLog:@"Add right channel write socket"];
    } else {
        if (_room.leftChannel) {
            if (_room.leftChannel.writeSocket) {
                _room.leftChannel.readSocket = newSocket;
                [self printLog:@"Add left channel read socket"];
                [self sendAccept];
            } else {
                _room.leftChannel.writeSocket = newSocket;
                [self printLog:@"Add left channel write socket"];
            }
        } else {
            _room.rightChannel.readSocket = newSocket;
            [self printLog:@"Add right channel read socket"];
            _room.leftChannel = [Channel new];
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    if (tag == READ_RIGHT_TAG) {
        [_room.leftChannel.writeSocket writeData:data withTimeout:WRITE_TIMEOUT tag:100];
        [_room.rightChannel.readSocket readDataWithTimeout:READ_TIMEOUT tag:READ_RIGHT_TAG];
    } else if (tag == READ_LEFT_TAG) {
        [_room.rightChannel.writeSocket writeData:data withTimeout:WRITE_TIMEOUT tag:200];
        [_room.leftChannel.readSocket readDataWithTimeout:READ_TIMEOUT tag:READ_LEFT_TAG];
    }
}

@end
