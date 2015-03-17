//
//  AppDelegate.m
//  v-Channel
//
//  Created by Sergey Seitov on 15.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "AppDelegate.h"
#import <Parse/Parse.h>
#import "Storage.h"
#import "PNImports.h"
#import "ContactsController.h"

@interface AppDelegate () <UISplitViewControllerDelegate, PNDelegate>

@property (atomic) BOOL disconnectedOnNetworkError;
@property (weak, nonatomic) ContactsController *contactsController;
@property (strong, nonatomic) Contact* incommingUser;

@end

@implementation AppDelegate

+ (BOOL)isPad
{
    return ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
}

+ (AppDelegate*)sharedInstance
{
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[Storage sharedInstance] saveContext];

    [PubNub setDelegate:self];
    
    PNConfiguration *myConfig = [PNConfiguration configurationForOrigin:@"pubsub.pubnub.com"
                                                             publishKey:@"pub-c-70195c96-4cf2-441c-8674-2d1e9d8eefaf"
                                                           subscribeKey:@"sub-c-5ef2db96-cbad-11e4-91c8-02ee2ddab7fe"
                                                              secretKey:@"sec-c-YzMwNDNhNjQtNDI2My00ZjJjLTliODgtMTc3N2I2Y2NlMGJi"];
    [PubNub setConfiguration:myConfig];
    [PubNub connect];
    
    [Parse setApplicationId:@"OEMz45lHZDfdEN9SMWjCPF3AQ49QSzWVikdtazFK"
                  clientKey:@"uw7xs5HqWHmVJMMyCj1Ub8PKCfi486CwOH2nzy5z"];
    
    // Register for Push Notitications
    UIUserNotificationType userNotificationTypes = (UIUserNotificationTypeAlert |
                                                    UIUserNotificationTypeBadge |
                                                    UIUserNotificationTypeSound);
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes
                                                                             categories:nil];
    
    [application registerUserNotificationSettings:settings];
    [application registerForRemoteNotifications];

    _splitViewController = (UISplitViewController *)self.window.rootViewController;
    _splitViewController.presentsWithGesture = NO;
    _splitViewController.delegate = self;
    
    UINavigationController *master = _splitViewController.viewControllers[0];
    _contactsController = master.topViewController;
    
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    // Store the deviceToken in the current installation and save it to Parse.
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:deviceToken];
    [currentInstallation saveInBackground];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    _incommingUser = [[Storage sharedInstance] contactForUser:[userInfo objectForKey:@"user"]];
    if (application.applicationState == UIApplicationStateActive) {
        if (_incommingUser) {
            if ([_contactsController.activeCall.peer.userId isEqual:_incommingUser.userId]) {
                [_contactsController.activeCall accept];
            } else {
                [_contactsController performSegueWithIdentifier:@"Call" sender:_incommingUser];
            }
        }
    } else {
        [PFPush handlePush:userInfo];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    if (currentInstallation.badge != 0) {
        currentInstallation.badge = 0;
        [currentInstallation saveEventually];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [PubNub disconnect];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Split view
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)splitViewController:(UISplitViewController*)svc shouldHideViewController:(UIViewController *)vc inOrientation:(UIInterfaceOrientation)orientation
{
    return NO;
}

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController
{
    return YES;
}

- (BOOL)splitViewController:(UISplitViewController *)splitViewController
   showDetailViewController:(UIViewController *)vc
                     sender:(id)sender
{
    if (splitViewController.collapsed) {
        UIViewController *secondViewController =  nil;
        if([vc isKindOfClass:[UINavigationController class]]) {
            UINavigationController *secondNavigationController = (UINavigationController*)vc;
            secondViewController = [secondNavigationController topViewController];
        } else {
            secondViewController = vc;
        }
        UINavigationController* master = (UINavigationController*)splitViewController.viewControllers[0];
        [master pushViewController:secondViewController animated:YES];
        return YES;
    }
    return NO;
}

#pragma mark - Push notifications

- (void)pushMessageToUser:(NSString*)user
{
    // Build a query to match user
    PFQuery *query = [PFUser query];
    [query whereKey:@"userId" equalTo:user];
    NSString *message = [NSString stringWithFormat:@"Incomming call from %@", [Storage getLogin]];
    NSDictionary *data = @{@"alert" : message,
                           @"badge" : @"Increment",
                           @"sound": @"default",
                           @"user" : [Storage getLogin]};
    PFPush *push = [[PFPush alloc] init];
    [push setQuery:query];
    [push setData:data];
    [push sendPushInBackground];
}

#pragma mark - PubNub delegate

- (void)pubnubClient:(PubNub *)client willConnectToOrigin:(NSString *)origin
{
    NSString *message = [NSString stringWithFormat:@"PubNub client is about to connect to PubNub origin at: %@", origin];
    if (self.disconnectedOnNetworkError) {
        
        message = [NSString stringWithFormat:@"PubNub client trying to restore connection to PubNub origin at: %@", origin];
    }
    
    NSLog(@"%@", message);
}

- (void)pubnubClient:(PubNub *)client didConnectToOrigin:(NSString *)origin
{
    NSLog(@"DELEGATE: Connected to  origin: %@", origin);
}

- (void)pubnubClient:(PubNub *)client connectionDidFailWithError:(PNError *)error
{
    NSLog(@"#1 PubNub client was unable to connect because of error: %@", error);
    self.disconnectedOnNetworkError = error.code == kPNClientConnectionFailedOnInternetFailureError;
}

- (void)pubnubClient:(PubNub *)client didReceiveMessage:(PNMessage *)message
{
}

@end
