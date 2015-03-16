//
//  Storage.h
//  v-Channel
//
//  Created by Sergey Seitov on 16.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "Contact.h"

@interface Storage : NSObject

+ (Storage*)sharedInstance;
- (NSManagedObjectContext*)managedObjectContext;

- (void)saveContext;
- (void)addContact:(NSString*)userId withNickName:(NSString*)nick photo:(NSData*)photo;
- (void)deleteContact:(Contact*)contact;

+ (NSString*)getLogin;
+ (NSString*)getPassword;

+ (void)saveLogin:(NSString*)login;
+ (void)savePassword:(NSString*)password;

@end
