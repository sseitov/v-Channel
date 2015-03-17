//
//  ContactsController.h
//  v-Channel
//
//  Created by Sergey Seitov on 15.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CallController.h"

@interface ContactsController : UITableViewController

@property (assign, nonatomic) CallController *activeCall;

@end
