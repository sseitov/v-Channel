//
//  AppDelegate.h
//  v-Channel
//
//  Created by Sergey Seitov on 15.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>

enum PushCommand
{
    None,
    Call,
    AcceptCall,
    RejectCall,
    FinishCall
};

extern NSString* const PushCommandNotification;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (weak, nonatomic) UISplitViewController *splitViewController;

+ (BOOL)isPad;
+ (AppDelegate*)sharedInstance;
+ (void)pushCallCommandToUser:(NSString*)user;

@end

