//
//  AddContactController.m
//  v-Channel
//
//  Created by Sergey Seitov on 16.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "AddContactController.h"
#import <Parse/Parse.h>
#import "Storage.h"

@interface AddContactController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *photo;
@property (weak, nonatomic) IBOutlet UITextField *user;
@property (weak, nonatomic) IBOutlet UILabel *nick;
@property (weak, nonatomic) IBOutlet UIButton *addFriendButton;

@property (strong, nonatomic) PFUser *friend;

- (IBAction)addFriend:(UIButton *)sender;

@end

@implementation AddContactController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Add friend";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
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

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    PFQuery *query = [PFUser query];
    [query whereKey:@"username" equalTo:textField.text];
    _friend = (PFUser *)[query getFirstObject];
    if (_friend) {
        _nick.text = _friend[@"displayName"];
        NSData* photoData = _friend[@"photo"];
        if (photoData) {
            _photo.image = [UIImage imageWithData:photoData];
            _photo.layer.cornerRadius = _photo.frame.size.width/2;
            _photo.clipsToBounds = YES;
        }
        _addFriendButton.enabled = YES;
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"User not found"
                                                        message:nil
                                                       delegate:nil
                                              cancelButtonTitle:@"Ok"
                                              otherButtonTitles:nil, nil];
        [alert show];
        _addFriendButton.enabled = NO;
    }
    return YES;
}

- (IBAction)addFriend:(UIButton *)sender
{
    [[Storage sharedInstance] addContact:_friend.username withNickName:_friend[@"displayName"] photo:_friend[@"photo"]];
    [self done];
}

@end
