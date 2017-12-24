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
	[self rebuildDevicesMenu];
	[recorder takeOutputFilePathFrom: pathField];
	[recorder setDelegate: self];
	[recorder setInputDeviceUID: [UKSoundFileRecorder availableInputDevices].firstObject[UKSoundFileRecorderDeviceUID]];
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(rebuildDevicesMenu) name: UKSoundFileRecorderAvailableInputDevicesChangedNotification object: recorder];
}


-(void) rebuildDevicesMenu
{
	NSString * selectedDeviceUID = recorder.inputDeviceUID;
	NSMenu * devicesMenu = [devicePopUp menu];
	[devicesMenu removeAllItems];
	
	for( NSDictionary<NSString*,NSString*> * deviceEntry in [UKSoundFileRecorder availableInputDevices] )
	{
		NSMenuItem * newItem = [[NSMenuItem alloc] initWithTitle: deviceEntry[UKSoundFileRecorderDeviceName] action: NULL keyEquivalent: @""];
		NSString * currentDeviceUID = deviceEntry[UKSoundFileRecorderDeviceUID];
		newItem.representedObject = currentDeviceUID;
		[devicesMenu addItem: newItem];
		if( [selectedDeviceUID isEqualToString: currentDeviceUID] )
			[devicePopUp selectItem: newItem];
	}
}


-(IBAction) devicePopUpSelectionChanged: (id)sender
{
	NSMenuItem * selectedItem = devicePopUp.selectedItem;
	NSString * deviceUID = selectedItem.representedObject;
	[recorder setInputDeviceUID: deviceUID];
}


-(void)	soundFileRecorderWasStarted: (UKSoundFileRecorder*)sender
{
	[statusField setStringValue: [NSString stringWithFormat: @"Recording from %@...", recorder.inputDeviceName]];
}

-(void)	soundFileRecorder: (UKSoundFileRecorder*)sender reachedDuration: (NSTimeInterval)timeInSeconds
{
	[statusField setStringValue: [NSString stringWithFormat: @"%ld Seconds...", lroundf(timeInSeconds)]];
}

-(void)	soundFileRecorder: (UKSoundFileRecorder*)sender hasAmplitude: (float)level
{
	[levelField setStringValue: [NSString stringWithFormat: @"%f", level]];
}

-(void)	soundFileRecorderWasStopped: (UKSoundFileRecorder*)sender
{
	[statusField setStringValue: @"Ready."];
}

@end
