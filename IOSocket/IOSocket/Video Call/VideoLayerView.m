//
//  VideoLayerView.m
//  iNear
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "VideoLayerView.h"

@interface VideoLayerView ()

@property (strong, nonatomic) AVSampleBufferDisplayLayer *videoLayer;

@end

@implementation VideoLayerView

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (!_videoLayer) {
        _videoLayer = [[AVSampleBufferDisplayLayer alloc] init];
        _videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        _videoLayer.backgroundColor = [[UIColor clearColor] CGColor];
        [self.layer addSublayer:_videoLayer];
    }
    _videoLayer.bounds = self.bounds;
    _videoLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
}

- (void)drawBuffer:(CMSampleBufferRef)videoBuffer
{
    [_videoLayer enqueueSampleBuffer:videoBuffer];
}

- (void)clear
{
    [_videoLayer flushAndRemoveImage];
}

@end
