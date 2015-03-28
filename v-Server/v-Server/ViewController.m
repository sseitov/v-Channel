//
//  ViewController.m
//  v-Server
//
//  Created by Sergey Seitov on 27.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ViewController.h"
#include "Common.h"

#import "Channel.h"

@interface ViewController () {
    dispatch_queue_t _socketQueue;
    dispatch_queue_t _delegateQueue;
}

@property (unsafe_unretained) IBOutlet NSTextView *log;
- (IBAction)start:(NSButton *)sender;

@property (strong, nonatomic) GCDAsyncSocket *serverSocket;
@property (nonatomic) BOOL isRunning;
@property (strong, nonatomic) Channel *channel;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _socketQueue = dispatch_queue_create("socketQueue", NULL);
    _delegateQueue = dispatch_queue_create("delegateQueue", NULL);

    _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_delegateQueue socketQueue:_socketQueue];
}

- (void)setRepresentedObject:(id)representedObject
{
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
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

- (IBAction)start:(NSButton *)sender
{
    if (!_isRunning) {
        NSError *error = nil;
        if(![_serverSocket acceptOnPort:SERVER_PORT error:&error])
        {
            [self printLog:[NSString stringWithFormat:@"Error starting server: %@", error]];
            return;
        } else {
            [self printLog:[NSString stringWithFormat:@"Server started on port: %d", SERVER_PORT]];
            [sender setTitle:@"Stop"];
            _isRunning = YES;
        }
    } else {
        [_serverSocket disconnect];
        [self printLog:@"Server stopped."];
        [sender setTitle:@"Start"];
        _isRunning = NO;
    }
}
/*
- (Channel*)channelForSocket:(GCDAsyncSocket*)socket
{
    for (Channel *channel in _channels) {
        if ([channel containsSocket:socket]) {
            return channel;
        }
    }
    return nil;
}
*/
#pragma mark - Socket delegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    if (!_channel) {
        _channel = [[Channel alloc] initWithSocket:newSocket];
        [self printLog:@"create room"];
    } else {
        [_channel addSocket:newSocket];
        [self printLog:@"add second socket into room"];
    }
    [newSocket readDataWithTimeout:-1 tag:READ_TAG];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    [[NSNotificationCenter defaultCenter] postNotificationName:WriteFinishNotification
                                                        object:[NSNumber numberWithLong:tag]];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    if (tag == READ_TAG && _channel && [_channel containsSocket:sock]) {
        enum Command result = [_channel readData:data fromSocket:sock];
        if (result == Finish || result == Accept) {
            [sock writeData:data withTimeout:-1 tag:0];
        }
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (_channel) {
        if ([_channel leaveSocket:sock]) {
            [self printLog:@"disconnect first socket"];
        } else {
            [self printLog:@"disconnect second socket and close room"];
            [self printLog:@"======================================="];
            _channel = nil;
        }
    }
}


@end
