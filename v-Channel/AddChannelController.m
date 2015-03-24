//
//  AddChannelController.m
//  v-Channel
//
//  Created by Sergey Seitov on 24.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "AddChannelController.h"
#import <Parse/Parse.h>

@interface AddChannelController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *photo;
@property (weak, nonatomic) IBOutlet UILabel *nick;
@property (weak, nonatomic) IBOutlet UITextField *user;
@property (weak, nonatomic) IBOutlet UIButton *addFriendButton;

- (IBAction)addFriend:(UIButton *)sender;

@end

@implementation AddChannelController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Find friend";
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(done)];
    _addFriendButton.layer.borderWidth = 1.0;
    _addFriendButton.layer.masksToBounds = YES;
    _addFriendButton.layer.cornerRadius = 7.0;
    _addFriendButton.layer.borderColor = _addFriendButton.backgroundColor.CGColor;
    
    _addFriendButton.enabled = NO;
   
}

- (void)done
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [_user becomeFirstResponder];
}

- (void)errorFind
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"User not found"
                                                    message:nil
                                                   delegate:nil
                                          cancelButtonTitle:@"Ok"
                                          otherButtonTitles:nil, nil];
    [alert show];
    _addFriendButton.enabled = NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    PFQuery *query = [PFUser query];
    [query whereKey:@"email" equalTo:textField.text];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError* error) {
        if (!error) {
            PFUser* friend =  [objects firstObject];
            if (friend) {
                _nick.text = friend[@"displayName"];
                NSData* photoData = friend[@"photo"];
                if (photoData) {
                    _photo.image = [UIImage imageWithData:photoData];
                    _photo.layer.cornerRadius = _photo.frame.size.width/2;
                    _photo.clipsToBounds = YES;
                }
                _addFriendButton.enabled = YES;
            } else {
                [self errorFind];
            }
        } else {
            [self errorFind];
        }
    }];
    
    return YES;
}

- (IBAction)addFriend:(UIButton *)sender
{
    NSArray* userChannels = [PFUser currentUser][@"channels"];
    NSMutableSet *channels = [NSMutableSet setWithArray:userChannels];
    [channels addObject:_user.text];
    [PFUser currentUser][@"channels"] = [channels allObjects];
    [[PFUser currentUser] saveInBackground];
    [self done];
}

@end
