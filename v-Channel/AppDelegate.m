//
//  AppDelegate.m
//  v-Channel
//
//  Created by Sergey Seitov on 15.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "AppDelegate.h"
#import <Parse/Parse.h>
#import <ParseFacebookUtils/PFFacebookUtils.h>
#import "ContactsController.h"

NSString* const PushCommandNotification = @"PushCommandNotification";

@interface AppDelegate () <UISplitViewControllerDelegate>

@property (atomic) BOOL disconnectedOnNetworkError;
@property (weak, nonatomic) ContactsController *contactsController;

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
    [Parse setApplicationId:@"OEMz45lHZDfdEN9SMWjCPF3AQ49QSzWVikdtazFK"
                  clientKey:@"uw7xs5HqWHmVJMMyCj1Ub8PKCfi486CwOH2nzy5z"];
    [PFFacebookUtils initializeFacebook];
    
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
    _contactsController = (ContactsController*)master.topViewController;
    
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
    [PFPush handlePush:userInfo];
/*    _incommingUser = [[Storage sharedInstance] contactForUser:[userInfo objectForKey:@"user"]];
    if (_incommingUser) {
        if (application.applicationState == UIApplicationStateActive) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PushCommandNotification
                                                                object:_incommingUser
                                                              userInfo:@{ @"command" : [userInfo objectForKey:@"command"]}];
            _incommingUser = nil;
            _pushCommand = nil;
        } else {
            _pushCommand = [userInfo objectForKey:@"command"];
            [PFPush handlePush:userInfo];
        }
    }*/
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
/*
    if (_incommingUser && _pushCommand) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PushCommandNotification
                                                            object:_incommingUser
                                                          userInfo:@{ @"command" : _pushCommand}];
    }
    _incommingUser = nil;
    _pushCommand = nil;*/
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    return [FBAppCall handleOpenURL:url sourceApplication:sourceApplication withSession:[PFFacebookUtils session]];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [FBAppCall handleDidBecomeActiveWithSession:[PFFacebookUtils session]];
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    if (currentInstallation.badge != 0) {
        currentInstallation.badge = 0;
        [currentInstallation saveEventually];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [[PFFacebookUtils session] close];
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

+ (void)pushCommand:(enum PushCommand)command toUser:(NSString*)user
{
    // Build a query to match user
    PFQuery *query = [PFUser query];
    [query whereKey:@"userId" equalTo:user];
    NSString *message = [NSString stringWithFormat:@"Incomming call from %@", [PFUser currentUser].username];
    NSDictionary *data = @{@"alert" : message,
                           @"badge" : @"Increment",
                           @"sound": @"default",
                           @"user" : [PFUser currentUser].username,
                           @"command" : [NSNumber numberWithInt:command]};
    PFPush *push = [[PFPush alloc] init];
    [push setQuery:query];
    [push setData:data];
    [push sendPushInBackground];
}

@end
