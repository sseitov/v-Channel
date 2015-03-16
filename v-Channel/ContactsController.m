//
//  ContactsController.m
//  v-Channel
//
//  Created by Sergey Seitov on 15.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ContactsController.h"

@interface ContactsController ()

@end

@implementation ContactsController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Contact" forIndexPath:indexPath];
    cell.textLabel.text = @"Call";
    return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Call"]) {
        UITableViewCell* cell = sender;
        NSIndexPath* indexPath = [self.tableView indexPathForCell:cell];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
//        UINavigationController *vc = [segue destinationViewController];
//        ChatController *chat = (ChatController*)vc.topViewController;
//        chat.user = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    } else if ([[segue identifier] isEqualToString:@"AddUser"]) {
//        UINavigationController *vc = [segue destinationViewController];
//        AddUserController* next = (AddUserController*)vc.topViewController;
//        next.delegate = self;
//        if ([AppDelegate isPad]) {
//            next.preferredContentSize = CGSizeMake(320, 120);
//        }
    }
}

@end
