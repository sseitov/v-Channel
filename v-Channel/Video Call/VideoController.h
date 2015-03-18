//
//  VideoController.h
//  iNear
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Storage.h"
#import "CallController.h"

@interface VideoController : UIViewController

@property (weak, nonatomic) id<CallControllerDelegate> delegate;
@property (strong, nonatomic) Contact *peer;

@end
