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

- (void)disconnect;

@end

@implementation Channel

- (void)disconnect
{
    [_readSocket disconnect];
    [_writeSocket disconnect];
}

@end

@interface Room : NSObject

@property (strong, nonatomic) Channel *master;
@property (strong, nonatomic) Channel *slave;

@end

@implementation Room

@end

@interface ViewController () {
    dispatch_queue_t _socketQueue;
    dispatch_queue_t _delegateQueue;
}

@property (unsafe_unretained) IBOutlet NSTextView *log;
- (IBAction)clearLog:(id)sender;

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

- (IBAction)clearLog:(id)sender
{
    [_log setString:@""];
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
    
    [_room.master.writeSocket writeData:[NSData dataWithBytes:&acceptPacket length:sizeof(struct Packet)] withTimeout:WRITE_TIMEOUT tag:0];
    [_room.master.readSocket readDataWithTimeout:READ_TIMEOUT tag:MASTER];
    
    [_room.slave.writeSocket writeData:[NSData dataWithBytes:&acceptPacket length:sizeof(struct Packet)] withTimeout:WRITE_TIMEOUT tag:0];
    [_room.slave.readSocket readDataWithTimeout:READ_TIMEOUT tag:SLAVE];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    if (!_room) {
        _room = [[Room alloc] init];
        _room.master = [Channel new];
        _room.master.writeSocket = newSocket;
        [self printLog:@"<<<<<<<< Create room"];
        [self printLog:@"Add write socket into master channel "];
    } else {
        if (_room.slave) {
            if (_room.slave.writeSocket) {
                _room.slave.readSocket = newSocket;
                [self printLog:@"Add read socket into slave channel"];
                [self sendAccept];
            } else {
                _room.slave.writeSocket = newSocket;
                [self printLog:@"Add slave channel write socket"];
            }
        } else {
            _room.master.readSocket = newSocket;
            [self printLog:@"Add read socket into master channel. Create slave channel and wait response."];
            _room.slave = [Channel new];
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    if (tag == MASTER) {
        [_room.slave.writeSocket writeData:data withTimeout:WRITE_TIMEOUT tag:MASTER];
    } else if (tag == SLAVE) {
        [_room.master.writeSocket writeData:data withTimeout:WRITE_TIMEOUT tag:SLAVE];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    if (tag == MASTER) {
        [_room.master.readSocket readDataWithTimeout:READ_TIMEOUT tag:MASTER];
    } else if (tag == SLAVE) {
        [_room.slave.readSocket readDataWithTimeout:READ_TIMEOUT tag:SLAVE];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (_room) {
        [_room.master disconnect];
        [_room.slave disconnect];
        _room = nil;
        [self printLog:@"Close room >>>>>>>>"];
    }
}

@end
