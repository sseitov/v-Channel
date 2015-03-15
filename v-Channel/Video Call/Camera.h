//
//  Camera.h
//  DirectVideo
//
//  Created by Sergey Seitov on 02.01.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface Camera : NSObject

+(Camera*)shared;

@property (strong, nonatomic) AVCaptureVideoDataOutput* output;

- (void) startup;
- (void) shutdown;
- (AVCaptureVideoPreviewLayer*) getPreviewLayer;
- (NSDictionary*)captureSettings;

- (void)switchCamera;

@end
