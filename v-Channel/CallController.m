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
#import "VideoController.h"

@interface CallController ()

@property (weak, nonatomic) IBOutlet UIImageView *photo;
@property (weak, nonatomic) IBOutlet UIImageView *animation;
@property (weak, nonatomic) IBOutlet UIButton *acceptButton;
@property (weak, nonatomic) IBOutlet UIButton *rejectButton;
@property (weak, nonatomic) IBOutlet UIButton *callButton;

- (IBAction)call:(UIButton*)sender;
- (IBAction)acceptIncomming:(UIButton *)sender;
- (IBAction)rejectIncomming:(UIButton *)sender;

@property (nonatomic) BOOL doCall;
@property (strong, nonatomic) AVAudioPlayer *ringtone;

@end

@implementation CallController

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (_peer[@"displayName"]) {
        self.title = _peer[@"displayName"];
    } else {
        self.title = _peer.username;
    }
    if (_peer[@"photo"]) {
        _photo.image = [UIImage imageWithData:_peer[@"photo"]];
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
    _animation.image = [UIImage imageNamed:@"tmp-0.gif"];
    _animation.animationImages = gifs;
    _animation.animationDuration = 2.0f;
    _animation.animationRepeatCount = 0;
    
    [self prepareButton:_acceptButton];
    [self prepareButton:_rejectButton];
    [self prepareButton:_callButton];
}

- (void)prepareButton:(UIButton*)button
{
    button.layer.borderWidth = 1.0;
    button.layer.masksToBounds = YES;
    button.layer.cornerRadius = 7.0;
    button.layer.borderColor = button.backgroundColor.CGColor;
}

- (void)done
{
    [self.delegate callControllerDidFinish];
}

- (void)viewWillAppear:(BOOL)animated
{
    _acceptButton.hidden = YES;
    _rejectButton.hidden = YES;
    _callButton.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [self updateGUI];
}

- (void)updateGUI
{
    if (_incommingCall) {
        _ringtone = [[AVAudioPlayer alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"ringtone"
                                                                                         withExtension:@"wav"] error:nil];
        _ringtone.numberOfLoops = -1;
        if ([_ringtone prepareToPlay]) {
            [_ringtone play];
        }
        [_animation startAnimating];
        _acceptButton.hidden = NO;
        _rejectButton.hidden = NO;
        _callButton.hidden = YES;
    } else {
        _acceptButton.hidden = YES;
        _rejectButton.hidden = YES;
        _callButton.hidden = NO;
    }
}

- (void)setIncommingCall
{
    _incommingCall = YES;
    [self updateGUI];
}

- (void)accept
{
    [_ringtone stop];
    [_animation stopAnimating];
    _doCall = NO;
    [self performSegueWithIdentifier:@"Video" sender:self];
}

- (void)reject
{
    [_ringtone stop];
    _ringtone = [[AVAudioPlayer alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"busy"
                                                                                     withExtension:@"wav"] error:nil];
    _ringtone.numberOfLoops = 0;
    if ([_ringtone prepareToPlay]) {
        [_ringtone play];
    }
    [_animation stopAnimating];
    _doCall = NO;
    [self updateGUI];
}

- (IBAction)call:(UIButton*)sender
{
    if (_doCall) {
        [AppDelegate pushCommand:FinishCall toUser:_peer[@"userId"]];
        [_ringtone stop];
        [sender setTitle:@"Call" forState:UIControlStateNormal];
        sender.backgroundColor = [UIColor colorWithRed:42./255. green:128./255. blue:83./255. alpha:1.];
        [_animation stopAnimating];
    } else {
        [AppDelegate pushCommand:Call toUser:_peer[@"userId"]];
        _ringtone = [[AVAudioPlayer alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"calling" withExtension:@"wav"] error:nil];
        _ringtone.numberOfLoops = -1;
        if ([_ringtone prepareToPlay]) {
            [_ringtone play];
        }
        [sender setTitle:@"End Call" forState:UIControlStateNormal];
        sender.backgroundColor = [UIColor colorWithRed:1. green:102./255. blue:102./255. alpha:1.];
        [_animation startAnimating];
    }
    _doCall = !_doCall;
}

- (IBAction)acceptIncomming:(UIButton *)sender
{
    [AppDelegate pushCommand:AcceptCall toUser:_peer[@"userId"]];
    [_ringtone stop];
    [_animation stopAnimating];
    _doCall = NO;
    _incommingCall = NO;
    [self performSegueWithIdentifier:@"Video" sender:self];
}

- (IBAction)rejectIncomming:(UIButton *)sender
{
    [AppDelegate pushCommand:RejectCall toUser:_peer[@"userId"]];
    [_ringtone stop];
    [_animation stopAnimating];
    _incommingCall = NO;
    _doCall = NO;
    [self updateGUI];
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Video"]) {
        VideoController *vc = [segue destinationViewController];
        vc.peer = self.peer;
        vc.delegate = self.delegate;
    }
}

@end
