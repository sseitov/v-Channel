//
//  VideoController.h
//  iNear
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>

enum MediaType {
    Video,
    Audio
};

enum Command {
    Accept = 1,
    Reject,
    Start,
    Started,
    Stop,
    Data,
    Finish
};

@protocol VideoControllerDelegate <NSObject>

- (void)videoSendPacket:(NSDictionary*)packet;

@end

@interface VideoController : UIViewController

@property (weak, nonatomic) id<VideoControllerDelegate> delegate;

- (void)shutdown;
- (void)videoReceivePacket:(NSDictionary*)packet;

@end
