//
//  AppDelegate.m
//  UKSoundRecorder
//
//  Created by Uli Kusterer on 14.07.07.
//  Copyright 2007 M. Uli Kusterer. All rights reserved.
//

#import "AppDelegate.h"


@implementation AppDelegate

-(void)	awakeFromNib
{
	[recorder takeOutputFilePathFrom: pathField];
	[recorder setDelegate: self];
}

-(void)	soundFileRecorderWasStarted: (UKSoundFileRecorder*)sender
{
	[statusField setStringValue: @"Recording..."];
}

-(void)	soundFileRecorder: (UKSoundFileRecorder*)sender reachedDuration: (NSTimeInterval)timeInSeconds
{
	[statusField setStringValue: [NSString stringWithFormat: @"%ld Seconds...", lroundf(timeInSeconds)]];
}

-(void)	soundFileRecorderWasStopped: (UKSoundFileRecorder*)sender
{
	[statusField setStringValue: @"Ready."];
}

@end
