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

@property (strong, nonatomic) PFUser* currentUser;
@property (strong, nonatomic) NSMutableArray *friends;

@end

@implementation ContactsController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _friends = [NSMutableArray new];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePushCommand:) name:PushCommandNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    self.navigationItem.rightBarButtonItem.enabled = ([PFUser currentUser] != nil);
}

- (void)viewDidAppear:(BOOL)animated
{
    _currentUser = [PFUser currentUser];
    if (!_currentUser) {
        // Set permissions required from the facebook user account
        NSArray *permissionsArray = @[ @"user_about_me", @"user_relationships"];        
        // Login PFUser using Facebook
        [PFFacebookUtils logInWithPermissions:permissionsArray block:^(PFUser *user, NSError *error) {
            [MBProgressHUD hideHUDForView:self.view animated:YES]; // Hide loading indicator
            
            if (!user) {
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
                [FBRequestConnection startForMeWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                    if (!error) {
                        // Store the current user's Facebook ID on the user
                        [[PFUser currentUser] setObject:[result objectForKey:@"id"]
                                                 forKey:@"fbId"];
                        [[PFUser currentUser] saveInBackground];
                        [self updateFriendList];
                    }
                }];
                self.navigationItem.rightBarButtonItem.enabled = YES;
                [PFInstallation currentInstallation][@"userId"] = user.username;
                _currentUser = user;
                [_currentUser save];
            }
        }];
        
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }
}

- (void)updateFriendList
{
    // Issue a Facebook Graph API request to get your user's friend list
    [FBRequestConnection startForMyFriendsWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if (!error) {
            // result will contain an array with your user's friends in the "data" key
            NSArray *friendObjects = [result objectForKey:@"data"];
            NSMutableArray *friendIds = [NSMutableArray arrayWithCapacity:friendObjects.count];
            // Create a list of friends' Facebook IDs
            for (NSDictionary *friendObject in friendObjects) {
                [friendIds addObject:[friendObject objectForKey:@"id"]];
            }
            
            // Construct a PFUser query that will find friends whose facebook ids
            // are contained in the current user's friend list.
            PFQuery *friendQuery = [PFUser query];
            [friendQuery whereKey:@"fbId" containedIn:friendIds];
            
            // findObjects will return a list of PFUsers that are friends
            // with the current user
            NSArray *friendUsers = [friendQuery findObjects];
            [_friends removeAllObjects];
            [_friends addObjectsFromArray:friendUsers];
            [self.tableView reloadData];
        }
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _friends.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Contact" forIndexPath:indexPath];
    PFUser *contact = [_friends objectAtIndex:indexPath.row];

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
/*
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Contact *contact = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [[Storage sharedInstance] deleteContact:contact];
    }
}
*/
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
            _activeCall.peer = [_friends objectAtIndex:indexPath.row];
            _activeCall.incommingCall = NO;
        } else {
            _activeCall.peer = sender;
            _activeCall.incommingCall = YES;
        }
    }
}

- (void)callControllerDidFinish
{
    if ([AppDelegate isPad]) {
        [self.activeCall.navigationController popViewControllerAnimated:YES];
    } else {
        [self.activeCall.navigationController popToRootViewControllerAnimated:YES];
    }
    [AppDelegate pushCommand:FinishCall toUser:_activeCall.peer[@"userId"]];
    self.activeCall = nil;
}

- (void)handlePushCommand:(NSNotification*)notify
{
    PFUser* user = notify.object;
    enum PushCommand command = [[notify.userInfo objectForKey:@"command"] intValue];
    switch (command) {
        case Call:
            if (_activeCall && [_activeCall.peer[@"userId"] isEqual:user[@"userId"]]) {
                [_activeCall setIncommingCall];
            } else {
                [self performSegueWithIdentifier:@"Call" sender:user];
            }
            break;
        case AcceptCall:
            if (_activeCall && [_activeCall.peer[@"userId"] isEqual:user[@"userId"]]) {
                [_activeCall accept];
            }
            break;
        case RejectCall:
            if (_activeCall && [_activeCall.peer[@"userId"] isEqual:user[@"userId"]]) {
                [_activeCall reject];
            }
            break;
        case FinishCall:
            if (_activeCall && [_activeCall.peer[@"userId"] isEqual:user[@"userId"]]) {
                [self callControllerDidFinish];
            }
            break;
        default:
            break;
    }
}

@end
