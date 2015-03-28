//
//  Channel.m
//  v-Server
//
//  Created by Sergey Seitov on 28.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "Channel.h"
#include "Common.h"

NSString* const WriteFinishNotification = @"WriteFinishNotification";

@interface Channel () {
    GCDAsyncSocket *socketPair[2];
    long writeTag[2];
    
    NSMutableData *receivedData[2];
    NSData *sendData[2];
    struct Packet *pPacket[2];
}

@end

@implementation Channel

- (id)initWithSocket:(GCDAsyncSocket*)socket
{
    self = [super init];
    if (self) {
        CFUUIDRef newUniqueId = CFUUIDCreate(kCFAllocatorDefault);
        _uuid = (__bridge_transfer NSString*)CFUUIDCreateString(kCFAllocatorDefault, newUniqueId);
        CFRelease(newUniqueId);
        
        socketPair[0] = socket;
        writeTag[0] = arc4random();
        receivedData[0] = [NSMutableData new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleWrite:) name:WriteFinishNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addSocket:(GCDAsyncSocket*)socket
{
    socketPair[1] = socket;
    writeTag[1] = arc4random();
    receivedData[1] = [NSMutableData new];
}

- (BOOL)leaveSocket:(GCDAsyncSocket*)socket
{
    if (socketPair[0] == socket) {
        socketPair[0] = nil;
    } else if (socketPair[1] == socket) {
        socketPair[1] = nil;
    }
    return (socketPair[0] || socketPair[1]);
}

- (BOOL)containsSocket:(GCDAsyncSocket*)socket
{
    return (socket == socketPair[0] || socket == socketPair[1]);
}

- (void)handleWrite:(NSNotification*)notify
{
    long tag = [notify.object longValue];
    int index = -1;
    if (tag == writeTag[0]) {
        index = 0;
    } else if (tag == writeTag[1]) {
        index = 1;
    }
    if (index >= 0) {
        [socketPair[index] readDataWithTimeout:-1 tag:READ_TAG];
    }
}

- (enum Command)readData:(NSData*)data fromSocket:(GCDAsyncSocket*)socket
{
    int index = (socket == socketPair[0]) ? 1 : 0;
    [receivedData[index] appendData:data];
    if (receivedData[index].length >= HEADER_SIZE) {
        pPacket[index] = (struct Packet *)receivedData[index].bytes;
        if (receivedData[index].length >= pPacket[index]->dataLength + HEADER_SIZE) {
            sendData[index] = [NSData dataWithBytes:receivedData[index].bytes
                                             length:(pPacket[index]->dataLength + HEADER_SIZE)];
            enum Command result = pPacket[index]->command;
            [receivedData[index] replaceBytesInRange:NSMakeRange(0, pPacket[index]->dataLength + HEADER_SIZE) withBytes:NULL length:0];
            [socketPair[index] writeData:sendData[index] withTimeout:-1 tag:writeTag[index]];
            return result;
        }
    }
    [socketPair[index] readDataWithTimeout:-1 tag:READ_TAG];
    return NoCommand;
}

@end
