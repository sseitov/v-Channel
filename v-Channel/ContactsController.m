//
//  ContactsController.m
//  v-Channel
//
//  Created by Sergey Seitov on 15.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ContactsController.h"
#import <Parse/Parse.h>
#import <ParseFacebookUtils/PFFacebookUtils.h>

#import "MBProgressHUD.h"
#import "AppDelegate.h"

@interface ContactsController () <CallControllerDelegate>

@property (strong, nonatomic) NSMutableArray *channels;

@end

@implementation ContactsController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _channels = [NSMutableArray new];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePushCommand:) name:PushCommandNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    self.navigationItem.rightBarButtonItem.enabled = ([PFUser currentUser] != nil);
}

- (void)viewDidAppear:(BOOL)animated
{
    // Set permissions required from the facebook user account
    NSArray *permissionsArray = @[ @"user_about_me", @"email"];
    
    if (![PFUser currentUser]) {
        
        // Login PFUser using Facebook
        [PFFacebookUtils logInWithPermissions:permissionsArray block:^(PFUser *user, NSError *error)
        {
            if (!user) {
                [MBProgressHUD hideHUDForView:self.view animated:YES]; // Hide loading indicator
                NSString *errorMessage = nil;
                if (!error) {
                    errorMessage = @"The user cancelled the Facebook login.";
                } else {
                    errorMessage = [error localizedDescription];
                }
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Log In Error"
                                                                message:errorMessage
                                                               delegate:nil
                                                      cancelButtonTitle:nil
                                                      otherButtonTitles:@"Dismiss", nil];
                [alert show];
            } else {
                [FBRequestConnection startForMeWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error)
                {
                    [MBProgressHUD hideHUDForView:self.view animated:YES]; // Hide loading indicator
                    if (!error) {
                        NSLog(@"fb result: %@", result);

                        // Store the current user's Facebook ID on the user
                        [[PFUser currentUser] setObject:[result objectForKey:@"id"] forKey:@"fbId"];
                        [[PFUser currentUser] setObject:[result objectForKey:@"email"] forKey:@"email"];
                        [[PFUser currentUser] saveInBackground];
                        [PFInstallation currentInstallation][@"userId"] = [result objectForKey:@"email"];
                        [[PFInstallation currentInstallation] saveInBackground];
                        self.navigationItem.rightBarButtonItem.enabled = YES;
                    } else {
                        NSLog(@"facebook error");
                    }
                }];
            }
        }];
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    } else {
        [self uploadChannels];
    }
}

- (void)uploadChannels
{
    [_channels removeAllObjects];
    for (NSString* email in [PFUser currentUser][@"channels"]) {
        PFQuery *query = [PFUser query];
        [query whereKey:@"email" equalTo:email];
        [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError* error) {
            if (!error) {
                PFUser* channel =  [objects firstObject];
                if (channel) {
                    [_channels addObject:channel];
                    [self.tableView reloadData];
                }
            }
        }];
    }
}

- (void)saveChannels
{
    [PFUser currentUser][@"channels"] = [_channels valueForKey:@"email"];
    [[PFUser currentUser] saveInBackground];
}

- (PFUser*)findChannel:(NSString*)channel
{
    for (PFUser *user in _channels) {
        if ([user[@"email"] isEqual:channel]) {
            return user;
        }
    }
    return nil;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _channels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Contact" forIndexPath:indexPath];
    PFUser *contact = [_channels objectAtIndex:indexPath.row];

    UILabel* name = (UILabel*)[cell.contentView viewWithTag:2];
    name.text = contact[@"displayName"];
    UIImageView *photo = (UIImageView*)[cell.contentView viewWithTag:1];
    if (contact[@"photo"]) {
        photo.image = [UIImage imageWithData:contact[@"photo"]];
        photo.layer.cornerRadius = photo.frame.size.width/2;
        photo.clipsToBounds = YES;
    } else {
        photo.image = [UIImage imageNamed:@"person"];
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_channels removeObjectAtIndex:indexPath.row];
        [self saveChannels];
        [self.tableView reloadData];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Call"]) {
        UINavigationController *vc = [segue destinationViewController];
        _activeCall = (CallController*)vc.topViewController;
        _activeCall.delegate = self;
        
        if ([sender isKindOfClass:[UITableViewCell class]]) {
            UITableViewCell* cell = sender;
            NSIndexPath* indexPath = [self.tableView indexPathForCell:cell];
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            
            _activeCall.peer = [_channels objectAtIndex:indexPath.row];
            _activeCall.incommingCall = NO;
        } else {
            _activeCall.peer = sender;
            _activeCall.incommingCall = YES;
        }
    }
}

- (void)handlePushCommand:(NSNotification*)notify
{
    PFUser *user = [self findChannel:notify.object];
    if (user) {
        [self performSegueWithIdentifier:@"Call" sender:user];
    }
}

- (void)callControllerDidFinish
{
    _activeCall = nil;
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
