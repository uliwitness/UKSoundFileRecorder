//
//  UKSoundFileRecorder.m
//  UKSoundFileRecorder
//
//  Created by Uli Kusterer on 14.07.07.
//  Copyright 2007 M. Uli Kusterer. All rights reserved.
//
//	This software is provided 'as-is', without any express or implied
//	warranty. In no event will the authors be held liable for any damages
//	arising from the use of this software.
//
//	Permission is granted to anyone to use this software for any purpose,
//	including commercial applications, and to alter it and redistribute it
//	freely, subject to the following restrictions:
//
//	   1. The origin of this software must not be misrepresented; you must not
//	   claim that you wrote the original software. If you use this software
//	   in a product, an acknowledgment in the product documentation would be
//	   appreciated but is not required.
//
//	   2. Altered source versions must be plainly marked as such, and must not be
//	   misrepresented as being the original software.
//
//	   3. This notice may not be removed or altered from any source
//	   distribution.
//

// -----------------------------------------------------------------------------
//	Headers:
// -----------------------------------------------------------------------------

#import "UKSoundFileRecorder.h"
#import <sys/param.h>	// for MAX().



NSString	*	UKSoundFileRecorderDeviceUID = @"UKSoundFileRecorderDeviceUID";
NSString	*	UKSoundFileRecorderDeviceName = @"UKSoundFileRecorderDeviceName";
NSString	*	UKSoundFileRecorderDeviceManufacturer = @"UKSoundFileRecorderDeviceManufacturer";

NSString	*	UKSoundFileRecorderAvailableInputDevicesChangedNotification = @"UKSoundFileRecorderAvailableInputDevicesChanged";


static BOOL		sDidSubscribeForDeviceChanges = NO;


static OSStatus AudioInputProc( void* inRefCon, AudioUnitRenderActionFlags* ioActionFlags, const AudioTimeStamp* inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList* ioData);
static OSStatus	UKSoundFileRecorderAudioDeviceListChanged( AudioObjectID objectID, UInt32 numberAddresses,
															const AudioObjectPropertyAddress addresses[], void* inClientData );


static int32_t	UKInt32FromOSStatus( OSStatus inErr )
{
	return (int32_t)inErr;
}


// -----------------------------------------------------------------------------
//	Private method prototypes:
// -----------------------------------------------------------------------------

@interface UKSoundFileRecorder (UKSoundFileRecorderPrivateMethods)

-(void)				cleanUp;
-(NSError*)			setupAudioFile;		// Returns error string, NIL on success.
-(NSError*)			configureAU;		// Returns error string, NIL on success.
-(AudioBufferList*)	allocateAudioBufferListWithNumChannels: (UInt32)numChannels size: (UInt32)size;
-(void)				destroyAudioBufferList: (AudioBufferList*)list;
-(void)				notifyDelegateOfTimeChangeAndAmplitude: (NSNumber*)currentAmps;

@end



@implementation UKSoundFileRecorder

// -----------------------------------------------------------------------------
//	defaultOutputFormat:
//		Returns a dictionary containing our default output format for the sound
//		data. This is what you get if you don't call setOutputFormat:.
// -----------------------------------------------------------------------------

+(NSDictionary*)	defaultOutputFormat
{
	static NSDictionary*	sDict = nil;
	if( !sDict )
	{
		sDict = [[NSDictionary alloc] initWithObjectsAndKeys:
												[NSNumber numberWithDouble: 44100.0], UKAudioStreamSampleRate,
												UKAudioStreamFormatMPEG4AAC, UKAudioStreamFormat,
												[NSNumber numberWithUnsignedInt: 1024], UKAudioStreamFramesPerPacket,
												[NSNumber numberWithUnsignedInt: 2], UKAudioStreamChannelsPerFrame,
												UKAudioOutputFileTypeM4A, UKAudioOutputFileType,
												@(kMPEG4Object_AAC_Main), UKAudioStreamFormatFlags,
												nil];
	}
	
	return sDict;
}


+(NSArray*)		availableInputDevices
{
	NSMutableArray	*	names = [NSMutableArray array];
	
	AudioObjectPropertyAddress propertyAddress = {
													kAudioHardwarePropertyDevices,
													kAudioObjectPropertyScopeGlobal,
													kAudioObjectPropertyElementMaster
												};
	
	UInt32 dataSize = 0;
	OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize);
	if(kAudioHardwareNoError != status)
		return nil;
	
	UInt32 deviceCount = (UInt32)(dataSize / sizeof(AudioDeviceID));
	
	AudioDeviceID *audioDevices = (AudioDeviceID *) malloc(dataSize);
	if(NULL == audioDevices)
		return nil;
	
	status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize, audioDevices);
	if(kAudioHardwareNoError != status)
	{
		free(audioDevices), audioDevices = NULL;
		return NULL;
	}
		
	// Iterate through all the devices and determine which are input-capable
	propertyAddress.mScope = kAudioDevicePropertyScopeInput;
	for( UInt32 i = 0; i < deviceCount; ++i )
	{
		// Query device UID
		CFStringRef deviceUID = NULL;
		dataSize = sizeof(deviceUID);
		propertyAddress.mSelector = kAudioDevicePropertyDeviceUID;
		status = AudioObjectGetPropertyData(audioDevices[i], &propertyAddress, 0, NULL, &dataSize, &deviceUID);
		if(kAudioHardwareNoError != status)
			continue;
		
		// Query device name
		CFStringRef deviceName = NULL;
		UInt32 dataSource = 0;
		UInt32 size = sizeof(dataSource);
		AudioObjectPropertyAddress	address = { kAudioDevicePropertyDataSource, kAudioDevicePropertyScopeInput, 0 };
		status = AudioObjectGetPropertyData( audioDevices[i], &address, 0, NULL, &size, &dataSource );
		if( status == noErr )
		{
			AudioValueTranslation theTranslation = { &dataSource, sizeof(dataSource), &deviceName, sizeof(deviceName) };
			UInt32 theSize = sizeof(theTranslation);
			address = (AudioObjectPropertyAddress){ kAudioDevicePropertyDataSourceNameForIDCFString, kAudioDevicePropertyScopeInput, 0 };
			status = AudioObjectGetPropertyData( audioDevices[i], &address, 0, NULL, &theSize, &theTranslation );
		}
		if( status != noErr )
		{
			dataSize = sizeof(deviceName);
			propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString;
			status = AudioObjectGetPropertyData(audioDevices[i], &propertyAddress, 0, NULL, &dataSize, &deviceName);
			if(kAudioHardwareNoError != status)
				continue;
		}
		
		[(id)deviceName autorelease];

		// Query device manufacturer
		CFStringRef deviceManufacturer = NULL;
		dataSize = sizeof(deviceManufacturer);
		propertyAddress.mSelector = kAudioDevicePropertyDeviceManufacturerCFString;
		status = AudioObjectGetPropertyData(audioDevices[i], &propertyAddress, 0, NULL, &dataSize, &deviceManufacturer);
		if(kAudioHardwareNoError != status)
			continue;
		
		// Determine if the device is an input device (it is an input device if it has input channels)
		dataSize = 0;
		propertyAddress.mSelector = kAudioDevicePropertyStreamConfiguration;
		status = AudioObjectGetPropertyDataSize(audioDevices[i], &propertyAddress, 0, NULL, &dataSize);
		if(kAudioHardwareNoError != status)
			continue;
		
		AudioBufferList *bufferList = (AudioBufferList *) malloc(dataSize);
		if(NULL == bufferList)
			break;
		
		status = AudioObjectGetPropertyData(audioDevices[i], &propertyAddress, 0, NULL, &dataSize, bufferList);
		if(kAudioHardwareNoError != status || 0 == bufferList->mNumberBuffers)
		{
			free(bufferList), bufferList = NULL;
			continue;
		}
		
		free(bufferList), bufferList = NULL;
		
		// Add a dictionary for this device to the array of input devices
		NSDictionary	*	deviceDictionary = [NSDictionary dictionaryWithObjectsAndKeys: (NSString*)deviceUID, UKSoundFileRecorderDeviceUID, (NSString*)deviceName, UKSoundFileRecorderDeviceName, (NSString*)deviceManufacturer, UKSoundFileRecorderDeviceManufacturer, nil];
		[names addObject: deviceDictionary];
	}
	
	free(audioDevices), audioDevices = NULL;
	
	if( !sDidSubscribeForDeviceChanges )
	{
		AudioObjectPropertyAddress address = {
												kAudioHardwarePropertyDevices,
												kAudioObjectPropertyScopeGlobal,
												kAudioObjectPropertyElementMaster
											 };
		status = AudioObjectAddPropertyListener(kAudioObjectSystemObject, &address, UKSoundFileRecorderAudioDeviceListChanged, NULL );
		if( status == noErr )
			sDidSubscribeForDeviceChanges = YES;
		else
			NSLog(@"Couldn't register for device list changes (%d).",status);
	}
	
	return names;
}


static OSStatus	UKSoundFileRecorderAudioDeviceListChanged( AudioObjectID objectID, UInt32 numberAddresses,
															const AudioObjectPropertyAddress addresses[], void* inClientData )
{
	[[NSNotificationCenter defaultCenter] postNotificationName: UKSoundFileRecorderAvailableInputDevicesChangedNotification object: nil];
	
	return noErr;
}


// -----------------------------------------------------------------------------
//	* DESIGNATED INITIALIZER:
// -----------------------------------------------------------------------------

-(id)	init
{
	self = [super init];
	if( self )
	{
		[self setOutputFormat: [[self class] defaultOutputFormat]];	// Apply a sensible default.
	}
	
	return self;
}

// -----------------------------------------------------------------------------
//	* CONVENIENCE INITIALIZER:
// -----------------------------------------------------------------------------

-(id)	initWithOutputFilePath: (NSString*)ofp
{
	self = [self init];	// SELF, not SUPER! We want the rest of the init to happen regularly.
	if( self )
	{
		[self setOutputFilePath: ofp];
	}
	
	return self;
}


// -----------------------------------------------------------------------------
//	* DESTRUCTOR:
// -----------------------------------------------------------------------------

-(void)	dealloc
{
	[NSRunLoop cancelPreviousPerformRequestsWithTarget: self];
	
	NS_DURING
		[self cleanUp];	// cleanUp calls stop, which may throw.
	NS_HANDLER
		NSLog(@"[UKSoundFileRecorder dealloc]: Ignoring exception during clean-up. %@ : %@",[localException name],[localException reason]);
	NS_ENDHANDLER
	[self destroyAudioBufferList: audioBuffer];
	
	[outputFilePath release];
	outputFilePath = nil;
	
	[actualOutputFormatDict release];
	actualOutputFormatDict = nil;
	[outputFormat release];
	outputFormat = nil;
	[inputDeviceUID release];
	inputDeviceUID = nil;
	
	[super dealloc];
}


// -----------------------------------------------------------------------------
//	Delegate accessors:
// -----------------------------------------------------------------------------

-(void)	setDelegate: (id<UKSoundFileRecorderDelegate>)dele
{
	delegate = dele;	// Don't retain delegate, it's very likely our owner. Wouldn't want a retain circle!
	delegateWantsTimeChanges = (delegate && [delegate respondsToSelector: @selector(soundFileRecorder:reachedDuration:)]);
	delegateWantsLevels = (delegate && [delegate respondsToSelector: @selector(soundFileRecorder:hasAmplitude:)]);
	delegateWantsRawFrames = (delegate && [delegate respondsToSelector: @selector(soundFileRecorder:receivedFrames:count:seconds:)]);
}


-(id<UKSoundFileRecorderDelegate>)	delegate
{
	return delegate;
}


// -----------------------------------------------------------------------------
//	AudioInputProc:
//		Callback function that is called by the audio unit on its high-priority
//		thread when we have sound input. Here's where we write out the data
//		to the file. Try not to do too much here.
// -----------------------------------------------------------------------------

static OSStatus AudioInputProc( void* inRefCon, AudioUnitRenderActionFlags* ioActionFlags, const AudioTimeStamp* inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList* ioData)
{
	NSAutoreleasePool	*	pool = [[NSAutoreleasePool alloc] init];
	UKSoundFileRecorder *	afr = (UKSoundFileRecorder*)inRefCon;
	OSStatus				err = noErr;

	// Render into audio buffer
	err = AudioUnitRender( afr->audioUnit, ioActionFlags, inTimeStamp,
							inBusNumber, inNumberFrames, afr->audioBuffer);
	if( err )
	{
		//fprintf( stderr, "AudioUnitRender() failed with error %d\n", UKInt32FromOSStatus(err) );
	}
	
	UInt64	nanos = AudioConvertHostTimeToNanos( inTimeStamp->mHostTime -afr->startHostTime );
	afr->currSeconds = ((double)nanos) * 0.000000001;
	
	err = noErr;
	
	@synchronized( afr )
	{
		if( afr->outputAudioFile )
		{
			// Write to file, ExtAudioFile auto-magicly handles conversion/encoding
			// NOTE: Async writes may not be flushed to disk until the file
			// reference is disposed using ExtAudioFileDispose
			err = ExtAudioFileWriteAsync( afr->outputAudioFile, inNumberFrames, afr->audioBuffer);
		}
	}
	
	if( err != noErr )
	{
		char	formatID[5] = { 0 };
		*(UInt32 *)formatID = CFSwapInt32HostToBig(err);
		formatID[4] = '\0';
		fprintf(stderr, "ExtAudioFileWrite FAILED! %d '%-4.4s'\n", UKInt32FromOSStatus(err), formatID);
		goto cleanUp;
	}
	
	if( afr->delegateWantsRawFrames )
		[afr->delegate soundFileRecorder: afr receivedFrames: afr->audioBuffer count: inNumberFrames seconds:afr->currSeconds];

	float	currentLevel = 0;
	if( afr->delegateWantsLevels && ioData != NULL )
	{
		for( UInt32 f = 0; f < inNumberFrames; f++ )
		{
			for( UInt32 b = 0; b < ioData->mNumberBuffers; b++ )
			{
				currentLevel += *((float*)((uint8_t*)ioData->mBuffers[b].mData + f * sizeof(float))) / ioData->mNumberBuffers / inNumberFrames;
			}
		}
	}
	
	if( afr->isRecording && (afr->delegateWantsTimeChanges || afr->delegateWantsLevels) )	// Don't waste time syncing to other threads if nobody is listening:
		[afr performSelectorOnMainThread: @selector(notifyDelegateOfTimeChangeAndAmplitude:) withObject: [NSNumber numberWithFloat: currentLevel] waitUntilDone: NO];
	
cleanUp:
	[pool release];
	
	return err;
}


// -----------------------------------------------------------------------------
//	outputFilePath Accessors:
//		The file at outputFilePath mustn't exist yet.
// -----------------------------------------------------------------------------

-(void)		setOutputFilePath: (NSString*)inOutputFilePath
{
	if( outputFilePath == nil || ![inOutputFilePath isEqualToString: outputFilePath] )
	{
		if( outputFilePath == nil )
			[self cleanUp];	// Make sure we recreate our objects for the new format.
		
		[self willChangeValueForKey: @"outputFilePath"];
		[outputFilePath release];
		outputFilePath = [inOutputFilePath copy];
		
		if( audioUnit && inOutputFilePath )
		{
			@synchronized( self )
			{
				// Dispose our audio file reference.
				// Also responsible for flushing async data to disk.
				if( outputAudioFile )
				{
					ExtAudioFileDispose( outputAudioFile );
					outputAudioFile = NULL;
					
					NSError	*	errObj = [self setupAudioFile];
					if( errObj )
						NSLog( @"%@", errObj );
				}
			}
		}
		[self didChangeValueForKey: @"outputFilePath"];
	}
}


-(NSString*)	outputFilePath
{
	return outputFilePath;
}


// Handy method for hooking up this object to a text field:
-(IBAction)		takeOutputFilePathFrom: (id)sender
{
	[self setOutputFilePath: [sender stringValue]];
}



// -----------------------------------------------------------------------------
//	outputFormat Accessors:
// -----------------------------------------------------------------------------

-(void)		setOutputFormat: (NSDictionary*)inASBD
{
	if( outputFormat != inASBD )
	{
		if( isRecording )
		{
			if( self.errorHandler )
			{
				self.errorHandler( [NSError errorWithDomain: NSOSStatusErrorDomain code: ULISoundFileRecorderCantChangeAudioFormatWhileRecordingError userInfo: @{ NSLocalizedFailureReasonErrorKey: @"Can't change output format when recording has already started." }] );
			}
			else
				[NSException raise: @"UKSoundFileRecorderBusyRecording" format: @"Can't change output format when recording has already started."];
		}
		
		NSDictionary *oldFormat = outputFormat;
		outputFormat = [inASBD copy];
		[oldFormat release];
		
		[self cleanUp];	// Make sure we recreate our objects for the new format.
	}
}


-(NSDictionary*)	outputFormat
{
	return outputFormat;
}


-(NSDictionary*)	actualOutputFormat
{
	if( !actualOutputFormatDict )
	{
		[actualOutputFormatDict release];
		actualOutputFormatDict = [UKDictionaryFromAudioStreamDescription( &actualOutputFormat ) retain];
	}
	return actualOutputFormatDict;
}


// -----------------------------------------------------------------------------
//	prepare:
//		Set up all the CoreAudio magic that makes this work.
// -----------------------------------------------------------------------------

-(void)		prepare
{
	NSError*	errObj = nil;
	
	errObj = [self configureAU];
	if( errObj == nil )
		errObj = [self setupAudioFile];
	
	if( errObj )
	{
		[self cleanUp];
		if( self.errorHandler )
		{
			self.errorHandler( errObj );
		}
		else
			[NSException raise: @"UKSoundFileRecorderCantPrepare" format: @"%@.", errObj.localizedFailureReason];
	}
}


// -----------------------------------------------------------------------------
//	isRecording accessor:
//		Returns YES if we are currently recording, NO otherwise.
// -----------------------------------------------------------------------------

-(BOOL)	isRecording
{
	return isRecording;
}


// -----------------------------------------------------------------------------
//	start:
//		Start recording sound, like, right now.
// -----------------------------------------------------------------------------

-(void)	start: (id)sender
{
	if( isRecording )
		return;
	
	if( !audioUnit )
		[self prepare];
	
	// Start pulling audio data:
	startHostTime = AudioGetCurrentHostTime();
	OSStatus err = AudioOutputUnitStart( audioUnit );
	if( err == noErr )
	{
		[self willChangeValueForKey: @"isRecording"];
		isRecording = YES;
		[self didChangeValueForKey: @"isRecording"];
		if( delegate && [delegate respondsToSelector: @selector(soundFileRecorderWasStarted:)] )
			[delegate soundFileRecorderWasStarted: self];
	}
	else if( self.errorHandler )
	{
		self.errorHandler( [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not start recording (ID=%d)", err] }] );
	}
	else
		[NSException raise: @"UKSoundFileRecorderCantStart" format: @"Could not start recording (ID=%d)", err];
}


// -----------------------------------------------------------------------------
//	stop:
//		Stop recording sound and flush the file to disk.
// -----------------------------------------------------------------------------

-(void)	stop: (id)sender
{
	if( isRecording )
	{
		if( audioUnit != NULL )
		{
			// Stop pulling audio data
			OSStatus err = AudioOutputUnitStop( audioUnit );
			if( err != noErr )
			{
				if( self.errorHandler )
				{
					self.errorHandler( [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not stop recording (ID=%d)", err] }] );
				}
				else
					[NSException raise: @"UKSoundFileRecorderCantStop" format: @"Could not stop recording (ID=%d)", err];
			}
		}
		
		[self willChangeValueForKey: @"isRecording"];
		isRecording = NO;
		[self didChangeValueForKey: @"isRecording"];
		if( delegate && [delegate respondsToSelector: @selector(soundFileRecorderWasStopped:)] )
			[delegate performSelectorOnMainThread: @selector(soundFileRecorderWasStopped:) withObject: self waitUntilDone: NO];
		
		[self cleanUp];	// Make sure file gets flushed to disk.
		[[NSWorkspace sharedWorkspace] noteFileSystemChanged: outputFilePath];	// Make sure Finder updates file size.
	}
}


-(void)	setInputDeviceUID: (NSString*)inDeviceUID
{
	OSStatus	err = noErr;
    AudioObjectPropertyAddress theAddress = { kAudioHardwarePropertyDefaultInputDevice,
                                              kAudioObjectPropertyScopeGlobal,
                                              kAudioObjectPropertyElementMaster };
	if( inDeviceUID == nil )
	{
		UInt32		theSize = sizeof(AudioDeviceID);
		err = AudioObjectGetPropertyData( kAudioObjectSystemObject, &theAddress, 0, NULL, &theSize, &inputDeviceID );
	}
	else
	{
		AudioValueTranslation	trans;
		trans.mInputData = (void*)&inDeviceUID;
		trans.mInputDataSize = sizeof(CFStringRef);
		trans.mOutputData = &inputDeviceID;
		trans.mOutputDataSize = sizeof(AudioDeviceID);
		UInt32		theSize = sizeof(AudioValueTranslation);
		theAddress = (AudioObjectPropertyAddress){ kAudioHardwarePropertyDeviceForUID, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster };
		err = AudioObjectGetPropertyData( kAudioObjectSystemObject, &theAddress, 0, NULL, &theSize, &trans );
	}
	
	if( err == noErr && inDeviceUID != inputDeviceUID )
	{
		[inputDeviceUID release];
		inputDeviceUID = [inDeviceUID retain];
	}
}


-(NSString*)	inputDeviceUID
{
	return inputDeviceUID;
}

@end


@implementation UKSoundFileRecorder (UKSoundFileRecorderPrivateMethods)


// -----------------------------------------------------------------------------
//	cleanUp:
//		Called in various places, but also in the destructor, to tear down our
//		CoreAudio stuff. This also causes the file to be written to disk.
//		This is essentially the opposite to -prepare.
// -----------------------------------------------------------------------------

-(void)	cleanUp
{
	// Stop pulling audio data.
	[self stop: self];
	
	// Dispose our audio file reference.
	// Also responsible for flushing async data to disk.
	if( outputAudioFile )
	{
		ExtAudioFileDispose( outputAudioFile );
		outputAudioFile = nil;
	}
	
	if( audioUnit )
	{
		AudioComponentInstanceDispose( audioUnit );
		audioUnit = NULL;
	}
}


// -----------------------------------------------------------------------------
//	setupAudioFile:
//		Init our ExtAudioFileRef object so it writes the correct kind of audio
//		to the correct file system location.
//		
//		Returns NIL on success, an error string on failure.
// -----------------------------------------------------------------------------

-(NSError*)	setupAudioFile
{
	OSStatus					err = noErr;
	AudioConverterRef			conv = NULL;
	AudioStreamBasicDescription	desiredOutputFormat;
	NSString*					fileFormatStr = [outputFormat objectForKey: UKAudioOutputFileType];
	AudioFileTypeID				fileFormat = fileFormatStr ? UKAudioStreamFormatIDFromString( fileFormatStr ) : kAudioFileM4AType;
	
	if( [[NSFileManager defaultManager] fileExistsAtPath: outputFilePath] )
	{
		NSError*	errObj = nil;
		if( ![[NSFileManager defaultManager] removeItemAtPath: outputFilePath error: &errObj] )
		{
			if( self.errorHandler )
				return errObj;
		}
	}
	
	UKAudioStreamDescriptionFromDictionary( outputFormat, &desiredOutputFormat );
	
	NSURL * outputFileURL = nil;
	if( outputFilePath )
	{
		outputFileURL = [NSURL fileURLWithPath: outputFilePath];
	}
	
	if( outputAudioFile != NULL )	// Have an audio file already? Get rid of that. IMPORTANT for setOutputFilePath:, which relies on this not calling cleanUp and stopping the player when it's just being used to start a new segment.
		[self cleanUp];
	
	if( outputFilePath )
	{
		// Create new MP4 file (kAudioFileM4AType)
		NSURL	*	theURL = outputFileURL.absoluteURL;
		err = ExtAudioFileCreateWithURL( (CFURLRef)theURL,
							fileFormat,
							&desiredOutputFormat,
							NULL,
                    		kAudioFileFlags_EraseFile,
							&outputAudioFile );
		if( err != noErr )
		{
			char formatID[5];
			*(UInt32 *)formatID = CFSwapInt32HostToBig(err);
			formatID[4] = '\0';
			return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not create the audio file (ID=%d/'%-4.4s')", err, formatID] }];
		}

		// Inform the file what format the data is we're going to give it, should be pcm
		// You must set this in order to encode or decode a non-PCM file data format.
		err = ExtAudioFileSetProperty( outputAudioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), &actualOutputFormat);
		if( err != noErr )
		{
			char formatID[5];
			*(UInt32 *)formatID = CFSwapInt32HostToBig(err);
			formatID[4] = '\0';
			return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not set up data format for output file (ID=%d/'%-4.4s')", err, formatID] }];
		}

		// If we're recording from a mono source, setup a simple channel map to split to stereo
		if( deviceFormat.mChannelsPerFrame == 1 && actualOutputFormat.mChannelsPerFrame == 2)
		{
			// Get the underlying AudioConverterRef
			UInt32 size = sizeof(AudioConverterRef);
			err = ExtAudioFileGetProperty( outputAudioFile, kExtAudioFileProperty_AudioConverter, &size, &conv );
			if( conv )
			{
				// This should be as large as the number of output channels,
				// each element specifies which input channel's data is routed to that output channel
				SInt32 channelMap[] = { 0, 0 };
				err = AudioConverterSetProperty( conv, kAudioConverterChannelMap, 2 * sizeof(SInt32), channelMap );
			}
		}

		// Initialize async writes thus preparing it for IO
		err = ExtAudioFileWriteAsync( outputAudioFile, 0, NULL );
		if( err != noErr )
		{
			char formatID[5];
			*(UInt32 *)formatID = CFSwapInt32HostToBig(err);
			formatID[4] = '\0';
			return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not initialize asynchronous writing (ID=%d/'%-4.4s')", err, formatID] }];
		}
	}

	return nil;
}


// -----------------------------------------------------------------------------
//	configureAU:
//		Create our Audio Unit that gives us data from the microphone.
//		
//		Returns NIL on success, an error string on failure.
// -----------------------------------------------------------------------------

-(NSError*)	configureAU
{
	AudioComponent				component = NULL;
	AudioComponentDescription	description;
	OSStatus					err = noErr;
	UInt32						param;
	AURenderCallbackStruct		callback;
	
	if( audioUnit )
	{
		AudioComponentInstanceDispose( audioUnit );
		audioUnit = NULL;
	}
	canDoMetering = NO;
	
	// Open the AudioOutputUnit
	// There are several different types of Audio Units.
	// Some audio units serve as Outputs, Mixers, or DSP
	// units. See AUComponent.h for listing
	description.componentType = kAudioUnitType_Output;
	description.componentSubType = kAudioUnitSubType_HALOutput;
	description.componentManufacturer = kAudioUnitManufacturer_Apple;
	description.componentFlags = 0;
	description.componentFlagsMask = 0;
	if(( component = AudioComponentFindNext( NULL, &description ) ))
	{
		err = AudioComponentInstanceNew( component, &audioUnit );
		if( err != noErr )
		{
			audioUnit = NULL;
			return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Couldn't open AudioUnit component (ID=%d)", err] }];
		}
	}

	// Configure the AudioOutputUnit
	// You must enable the Audio Unit (AUHAL) for input and output for the same  device.
	// When using AudioUnitSetProperty the 4th parameter in the method
	// refers to an AudioUnitElement.  When using an AudioOutputUnit
	// for input the element will be '1' and the output element will be '0'.	
	
	// Enable input on the AUHAL
	param = 1;
	err = AudioUnitSetProperty( audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &param, sizeof(UInt32) );
	if(err == noErr)
	{
		// Disable Output on the AUHAL
		param = 0;
		err = AudioUnitSetProperty( audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &param, sizeof(UInt32) );
		if( err != noErr )
		{
			[self cleanUp];
			return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Couldn't set EnableIO property on the audio unit (ID=%d)", err] }];
		}
	}

	// Select the default input device
	if( inputDeviceID == kAudioObjectUnknown )	// Couldn't find it? Fall back to default input:
	{
		[inputDeviceUID release];
		inputDeviceUID = nil;
		param = sizeof(AudioDeviceID);
		AudioObjectPropertyAddress theAddress = { kAudioHardwarePropertyDefaultInputDevice,
													kAudioObjectPropertyScopeGlobal,
													kAudioObjectPropertyElementMaster };
		err = AudioObjectGetPropertyData( kAudioObjectSystemObject, &theAddress, 0, NULL, &param, &inputDeviceID );
	}
	else
		err = noErr;
	if(err != noErr )
	{
		[self cleanUp];
		return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Couldn't get sound input device (ID=%d)", err] }];
	}
	
	// Set the current device to the selected input unit.
	err = AudioUnitSetProperty( audioUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &inputDeviceID, sizeof(AudioDeviceID) );
	if(err != noErr)
	{
		[self cleanUp];
		return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Failed to hook up input device to our AudioUnit (ID=%d)", err] }];
	}
	
	err = AudioUnitSetProperty( audioUnit, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Output, 1, &param, sizeof(UInt32) );
	canDoMetering = (err == noErr);

	// Setup render callback
	// This will be called when the AUHAL has input data
	callback.inputProc = AudioInputProc;
	callback.inputProcRefCon = self;
	err = AudioUnitSetProperty( audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callback, sizeof(AURenderCallbackStruct) );
	if(err != noErr)
	{
		[self cleanUp];
		return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not install render callback on our AudioUnit (ID=%d)", err] }];
	}
	

	{
		Float64 rate;
		param = sizeof(rate);
		
		AudioObjectPropertyAddress	address = { kAudioDevicePropertyNominalSampleRate,
												kAudioObjectPropertyScopeGlobal,
												kAudioObjectPropertyElementMaster };
		err = AudioObjectGetPropertyData( inputDeviceID, &address, 0, NULL, &param, &rate );
		if (err == noErr)
		{
			NSNumber*	num = [outputFormat objectForKey: UKAudioStreamSampleRate];
			if( num )
			{
				rate = [num doubleValue];
				
				err = AudioObjectSetPropertyData( inputDeviceID, &address, 0, NULL, sizeof(rate), &rate );
				if (err != noErr)
				{
					rate = rate < 32000 ? rate * 2 : rate / 2;
					
					err = AudioObjectSetPropertyData( inputDeviceID, &address, 0, NULL, sizeof(rate), &rate );				
				}
			}
		}
		if(err != noErr)
		{
			NSLog( @"Could not change the nominal sample rate of the input device (ID=%d)", err );
		}
	}

	// get hardware device format
	param = sizeof(AudioStreamBasicDescription);
	err = AudioUnitGetProperty( audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &deviceFormat, &param );
	if(err != noErr)
	{
		[self cleanUp];
		return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not install render callback on our AudioUnit (ID=%d)", err] }];
	}
	
	// Twiddle the format to our liking
	audioChannels = MAX( deviceFormat.mChannelsPerFrame, 2 );
	actualOutputFormat.mChannelsPerFrame = audioChannels;
	actualOutputFormat.mSampleRate = deviceFormat.mSampleRate;
	actualOutputFormat.mFormatID = kAudioFormatLinearPCM;
	actualOutputFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
	
	//NSLog( @"sampleRate %f", actualOutputFormat.mSampleRate );
	
	if( actualOutputFormat.mFormatID == kAudioFormatLinearPCM && audioChannels == 1 )
		actualOutputFormat.mFormatFlags &= ~kLinearPCMFormatFlagIsNonInterleaved;
#if __BIG_ENDIAN__
	actualOutputFormat.mFormatFlags |= kAudioFormatFlagIsBigEndian;
#endif
	actualOutputFormat.mBitsPerChannel = sizeof(Float32) * 8;
	actualOutputFormat.mBytesPerFrame = actualOutputFormat.mBitsPerChannel / 8;
	actualOutputFormat.mFramesPerPacket = 1;
	actualOutputFormat.mBytesPerPacket = actualOutputFormat.mBytesPerFrame;

	// Set the AudioOutputUnit output data format
	err = AudioUnitSetProperty( audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &actualOutputFormat, sizeof(AudioStreamBasicDescription));
	if(err != noErr)
	{
		[self cleanUp];
		return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not change the stream format of the output device (ID=%d)", err] }];
	}
	
	param = sizeof(AudioStreamBasicDescription);
	err = AudioUnitGetProperty( audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &actualOutputFormat, &param );
	// Make sure we remember correctly what format we actually got.
	if(err != noErr)
	{
		[self cleanUp];
		return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not retrieve the stream format of the output device (ID=%d)", err] }];
	}
	[actualOutputFormatDict release];	// Make sure next guy who asks for it gets a new lazily-allocated conversion.
	actualOutputFormatDict = nil;
	
	if( deviceFormat.mChannelsPerFrame == 1 && audioChannels == 2 )
	{
		SInt32 channelMap[] = { 0, 0 };
		err = AudioUnitSetProperty( audioUnit, kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 1, channelMap, 2 * sizeof(SInt32) );
		if( err != noErr )
		{
			[self cleanUp];
			return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Error %d setting channel map.", err ] }];
		}
	}

	// Get the number of frames in the IO buffer(s)
	param = sizeof(UInt32);
	err = AudioUnitGetProperty( audioUnit, kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Global, 0, &audioSamples, &param );
	if(err != noErr)
	{
		[self cleanUp];
		return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not determine audio sample size (ID=%d)", err] }];
	}
	
	// Initialize the AU
	err = AudioUnitInitialize( audioUnit );
	if(err != noErr)
	{
		[self cleanUp];
		return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not initialize the AudioUnit (ID=%d)", err] }];
	}
	
	// Allocate our audio buffers
	audioBuffer = [self allocateAudioBufferListWithNumChannels: actualOutputFormat.mChannelsPerFrame size: audioSamples * actualOutputFormat.mBytesPerFrame];
	if( audioBuffer == NULL )
	{
		[self cleanUp];
		return [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: @{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat: @"Could not allocate buffers for recording (ID=%d)", err] }];
	}
	
	return nil;
}

// -----------------------------------------------------------------------------
//	allocateAudioBufferListWithNumChannels:size:
//		Create our audio buffer list. A buffer list is the storage we use in
//		our AudioInputProc to get the sound data and hand it on to the sound
//		file writer.
// -----------------------------------------------------------------------------

-(AudioBufferList*)	allocateAudioBufferListWithNumChannels: (UInt32)numChannels size: (UInt32)size
{
	AudioBufferList*			list = NULL;
	UInt32						i = 0;
	
	list = (AudioBufferList*) calloc( 1, sizeof(AudioBufferList) + numChannels * sizeof(AudioBuffer) );
	if( list == NULL )
		return NULL;
	
	list->mNumberBuffers = numChannels;
	
	for( i = 0; i < numChannels; ++i )
	{
		list->mBuffers[i].mNumberChannels = 1;
		list->mBuffers[i].mDataByteSize = size;
		list->mBuffers[i].mData = malloc(size);
		if(list->mBuffers[i].mData == NULL)
		{
			[self destroyAudioBufferList: list];
			return NULL;
		}
	}
	
	return list;
}


// -----------------------------------------------------------------------------
//	destroyAudioBufferList:size:
//		Dispose of our audio buffer list. A buffer list is the storage we use in
//		our AudioInputProc to get the sound data and hand it on to the sound
//		file writer.
// -----------------------------------------------------------------------------

-(void)		destroyAudioBufferList: (AudioBufferList*)list
{
	UInt32						i = 0;
	
	if( list )
	{
		for( i = 0; i < list->mNumberBuffers; i++ )
		{
			if( list->mBuffers[i].mData )
				free( list->mBuffers[i].mData );
		}
		free( list );
	}
}

// Used by our AudioInputProc to easily call this delegate method from another thread:
-(void)	notifyDelegateOfTimeChangeAndAmplitude: (NSNumber*)currentAmps
{
	if( isRecording )	// In case we queued one up but were already finished by the time it got executed.
	{
		if( delegateWantsTimeChanges )
			[delegate soundFileRecorder: self reachedDuration: currSeconds];
		if( delegateWantsLevels )
			[delegate soundFileRecorder: self hasAmplitude: [currentAmps floatValue]];
	}
}

@end
