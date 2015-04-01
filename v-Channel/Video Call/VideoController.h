//
//  VideoController.h
//  iNear
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "Common.h"

@protocol VideoControllerDelegate <NSObject>

- (void)sendVideoCommand:(enum Command)command withData:(NSData*)data;
- (void)didFinish;

@end

@interface VideoController : UIViewController

@property (weak, nonatomic) id<VideoControllerDelegate> delegate;

- (void)receiveVideoCommand:(enum Command)command withData:(NSData*)data;
- (void)shutdown;

@end
