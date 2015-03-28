//
//  ViewController.m
//  v-Server
//
//  Created by Sergey Seitov on 27.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ViewController.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#include "Common.h"

@interface ViewController () {
    dispatch_queue_t _serverQueue;
}

@property (unsafe_unretained) IBOutlet NSTextView *log;
- (IBAction)start:(NSButton *)sender;

@property (strong, nonatomic) GCDAsyncSocket *serverSocket;
@property (strong, nonatomic) GCDAsyncSocket *firstClient;
@property (strong, nonatomic) GCDAsyncSocket *secondClient;
@property (nonatomic) BOOL isRunning;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    _serverQueue = dispatch_queue_create("socketQueue", NULL);
    _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_serverQueue];
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

#pragma mark - Socket delegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    if (_firstClient) {
        _secondClient = newSocket;
    } else {
        _firstClient = newSocket;
    }
    [newSocket readDataWithTimeout:-1 tag:1];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSDictionary* packet = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    if ([[packet objectForKey:@"command"] intValue] == Accept) {
        if (_firstClient && _secondClient) {
            [self printLog:@"accept second socket"];
            [_firstClient writeData:data withTimeout:-1 tag:1];
            [_secondClient writeData:data withTimeout:-1 tag:1];
        } else {
            [self printLog:@"accept first socket"];
        }
    } else if ([[packet objectForKey:@"command"] intValue] == Finish) {
        if (_firstClient) {
            [_firstClient writeData:data withTimeout:-1 tag:tag];
        }
        if (_secondClient) {
            [_secondClient writeData:data withTimeout:-1 tag:tag];
        }
    } else {
        if (sock == _firstClient) {
            [_secondClient writeData:data withTimeout:-1 tag:tag];
        } else {
            [_firstClient writeData:data withTimeout:-1 tag:tag];
        }
    }
    [sock readDataWithTimeout:-1 tag:tag];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (sock == _firstClient) {
        [self printLog:@"disconnect first socket"];
        _firstClient = nil;
    } else {
        [self printLog:@"disconnect second socket"];
        _secondClient = nil;
    }
}

@end
