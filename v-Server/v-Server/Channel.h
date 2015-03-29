//
//  Channel.h
//  v-Server
//
//  Created by Sergey Seitov on 28.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#include "Common.h"

extern NSString* const WriteFinishNotification;

@interface Channel : NSObject

- (id)initWithSocket:(GCDAsyncSocket*)socket;
- (void)addSocket:(GCDAsyncSocket*)socket;
- (BOOL)leaveSocket:(GCDAsyncSocket*)socket;

- (enum Command)readData:(NSData*)data fromSocket:(GCDAsyncSocket*)socket;

- (BOOL)containsSocket:(GCDAsyncSocket*)socket;

@property (strong, nonatomic, readonly) NSString* uuid;

@end
