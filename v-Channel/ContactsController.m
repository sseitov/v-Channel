//
//  ContactsController.m
//  v-Channel
//
//  Created by Sergey Seitov on 15.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ContactsController.h"
#import <Parse/Parse.h>
#import "Storage.h"
#import "MBProgressHUD.h"
#import "AppDelegate.h"

@interface ContactsController () <NSFetchedResultsControllerDelegate, CallControllerDelegate>

@property (strong, nonatomic) PFUser* currentUser;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

@end

@implementation ContactsController

- (void)viewDidLoad
{
    [super viewDidLoad];
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
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [PFUser logInWithUsernameInBackground:[Storage getLogin] password:[Storage getPassword]
                                        block:^(PFUser *user, NSError *error) {
                                            [MBProgressHUD hideHUDForView:self.view animated:YES];
                                            if (user) {
                                                self.navigationItem.rightBarButtonItem.enabled = YES;
                                                _currentUser = user;
                                                [_currentUser save];
                                            } else {
                                                [self performSegueWithIdentifier:@"Profile" sender:self];
                                            }
                                        }];
    }
}

#pragma mark - NSFetchedResultsController

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController == nil)
    {
        NSManagedObjectContext *moc = [[Storage sharedInstance] managedObjectContext];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        fetchRequest.entity = [NSEntityDescription entityForName:@"Contact" inManagedObjectContext:moc];
        fetchRequest.sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"userId" ascending:YES]];
        fetchRequest.predicate = nil;
        fetchRequest.fetchBatchSize = 50;
        
        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                        managedObjectContext:moc
                                                                          sectionNameKeyPath:nil
                                                                                   cacheName:nil];
        _fetchedResultsController.delegate = self;
        
        NSError *error = nil;
        if (![_fetchedResultsController performFetch:&error])
        {
            NSLog(@"Error performing fetch: %@", error);
        }
        
    }
    
    return _fetchedResultsController;
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray *sections = [self.fetchedResultsController sections];
    if (section < sections.count)
    {
        id <NSFetchedResultsSectionInfo> sectionInfo = sections[section];
        return sectionInfo.numberOfObjects;
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Contact" forIndexPath:indexPath];
    Contact *contact = [self.fetchedResultsController objectAtIndexPath:indexPath];

    UILabel* name = (UILabel*)[cell.contentView viewWithTag:2];
    if (contact.displayName) {
        name.text = contact.displayName;
    } else {
        name.text = contact.userId;
    }
    UIImageView *photo = (UIImageView*)[cell.contentView viewWithTag:1];
    if (contact.photo) {
        photo.image = [UIImage imageWithData:contact.photo];
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
        Contact *contact = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [[Storage sharedInstance] deleteContact:contact];
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
            _activeCall.peer = [[self fetchedResultsController] objectAtIndexPath:indexPath];
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
    [AppDelegate pushCommand:FinishCall toUser:_activeCall.peer.userId];
    self.activeCall = nil;
}

- (void)handlePushCommand:(NSNotification*)notify
{
    Contact* user = notify.object;
    enum PushCommand command = [[notify.userInfo objectForKey:@"command"] intValue];
    switch (command) {
        case Call:
            if (_activeCall && [_activeCall.peer.userId isEqual:user.userId]) {
                [_activeCall setIncommingCall];
            } else {
                [self performSegueWithIdentifier:@"Call" sender:user];
            }
            break;
        case AcceptCall:
            if (_activeCall && [_activeCall.peer.userId isEqual:user.userId]) {
                [_activeCall accept];
            }
            break;
        case RejectCall:
            if (_activeCall && [_activeCall.peer.userId isEqual:user.userId]) {
                [_activeCall reject];
            }
            break;
        case FinishCall:
            if (_activeCall && [_activeCall.peer.userId isEqual:user.userId]) {
                NSLog(@"%@ finish call", user.userId);
                [self callControllerDidFinish];
            }
            break;
        default:
            break;
    }
}

@end
