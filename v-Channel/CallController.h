//
//  CallController.h
//  v-Channel
//
//  Created by Sergey Seitov on 16.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Storage.h"

@protocol CallControllerDelegate <NSObject>

- (void)callControllerDidFinish;

@end

@interface CallController : UIViewController

@property (weak, nonatomic) id<CallControllerDelegate> delegate;

@property (strong, nonatomic) Contact *peer;
@property (nonatomic) BOOL incommingCall;

- (void)accept;
- (void)reject;
- (void)setIncommingCall;

@end
