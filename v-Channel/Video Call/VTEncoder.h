//
//  VTEncoder.h
//  DirectVideo
//
//  Created by Sergey Seitov on 02.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@class VTEncoder;

@protocol VTEncoderDelegate <NSObject>

- (void)encoder:(VTEncoder*)encoder encodedData:(NSData*)data;

@end

@interface VTEncoder : NSObject

@property (weak, nonatomic) id<VTEncoderDelegate> delegate;
@property (nonatomic) int width;
@property (nonatomic) int height;
@property (strong, nonatomic) NSData* sps;
@property (strong, nonatomic) NSData* pps;
@property (nonatomic) BOOL isOpened;

- (BOOL)openForWidth:(int)width height:(int)height;
- (void)close;
- (void)encodeBuffer:(CVImageBufferRef)buffer;

@end
