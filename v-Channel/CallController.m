//
//  CallController.m
//  v-Channel
//
//  Created by Sergey Seitov on 16.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "CallController.h"
#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import "Storage.h"
#import "VideoController.h"

@interface CallController ()

@property (weak, nonatomic) IBOutlet UIImageView *photo;
@property (weak, nonatomic) IBOutlet UIImageView *animation;

- (IBAction)call:(UIBarButtonItem*)sender;

@property (nonatomic) BOOL doCall;
@property (strong, nonatomic) AVAudioPlayer *ringtone;

@end

@implementation CallController

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (_peer.displayName) {
        self.title = _peer.displayName;
    } else {
        self.title = _peer.userId;
    }
    if (_peer.photo) {
        _photo.image = [UIImage imageWithData:_peer.photo];
        _photo.layer.cornerRadius = _photo.frame.size.width/2;
        _photo.clipsToBounds = YES;
    }

    if (![AppDelegate isPad]) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                              target:self
                                                                                              action:@selector(done)];
    }
    NSMutableArray *gifs = [NSMutableArray array];
    for (int i=0; i<24; i++) {
        NSString* name = [NSString stringWithFormat:@"tmp-%d.gif", i];
        [gifs addObject:[UIImage imageNamed:name]];
    }
    _animation.animationImages = gifs;
    _animation.animationDuration = 2.0f;
    _animation.animationRepeatCount = 0;
}

- (void)done
{
    [self.delegate callControllerDidFinish];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (!_fromMe) {
        _ringtone = [[AVAudioPlayer alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"ringtone" withExtension:@"wav"] error:nil];
        _ringtone.numberOfLoops = -1;
        if ([_ringtone prepareToPlay]) {
            [_ringtone play];
        }
        [_animation startAnimating];
    }
}

- (void)accept
{
    if (_fromMe) {
        [_ringtone stop];
        [self performSegueWithIdentifier:@"Video" sender:self];
    }
}

- (IBAction)call:(UIBarButtonItem*)sender
{
    if (_doCall) {
        [_ringtone stop];
        sender.image = [UIImage imageNamed:@"call"];
        [_animation stopAnimating];
        _doCall = NO;
    } else {
        if (_fromMe) {
            [[AppDelegate sharedInstance] pushMessageToUser:_peer.userId];
            _ringtone = [[AVAudioPlayer alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"calling" withExtension:@"wav"] error:nil];
            _ringtone.numberOfLoops = -1;
            if ([_ringtone prepareToPlay]) {
                [_ringtone play];
            }
            
            sender.image = [UIImage imageNamed:@"end-call"];
            [_animation startAnimating];
            _doCall = YES;
        } else {
            [_ringtone stop];
            [[AppDelegate sharedInstance] pushMessageToUser:_peer.userId];
            [self performSegueWithIdentifier:@"Video" sender:self];
            _doCall = NO;
        }
    }
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Video"]) {
        VideoController *vc = [segue destinationViewController];
        vc.peer = self.peer;
        vc.delegate = self.delegate;
        _fromMe = YES;
        [_animation stopAnimating];
    }
}

@end
