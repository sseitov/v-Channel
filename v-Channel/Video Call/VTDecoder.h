//
//  VTDecoder.h
//  DirectVideo
//
//  Created by Sergey Seitov on 03.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@class VTDecoder;

@protocol VTDecoderDelegate <NSObject>

- (void)decoder:(VTDecoder*)decoder decodedBuffer:(CMSampleBufferRef)buffer;

@end

@interface VTDecoder : NSObject

@property (weak, nonatomic) id<VTDecoderDelegate> delegate;
@property (nonatomic) BOOL isOpened;

- (BOOL)openForWidth:(int)width height:(int)height sps:(NSData*)sps pps:(NSData*)pps;
- (void)close;
- (void)decodeData:(NSData*)data;

@end
