//
//  UKAudioStreamBasicDescription.h
//  UKSoundFileRecorder
//
//  Created by Uli Kusterer on 14.07.07.
//  Copyright 2007 M. Uli Kusterer. All rights reserved.
//

/*
	More Cocoa-friendly NSDictionary wrapper around CoreAudio's
	AudioStreamBasicDescription.
*/

// -----------------------------------------------------------------------------
//	Headers:
// -----------------------------------------------------------------------------

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>


// -----------------------------------------------------------------------------
//	Dictionary Keys:
// -----------------------------------------------------------------------------

// Keys for an Audio Stream Description NSDictionary. These correspond to the
//	fields in a CoreAudio AudioStreamBasicDescription, which are noted in
//	brackets behind each key.

#define UKAudioStreamSampleRate						@"UKAudioStreamSampleRate"			// NSNumber containing a double (mSampleRate).
#define UKAudioStreamFormat							@"UKAudioStreamFormat"				// NSString containing one of the formats below (mFormatID).
#define UKAudioStreamFormatFlags					@"UKAudioStreamFormatFlags"			// NSNumber containing an unsigned int holding abitfield with format-specific flags (mFormatFlags).
#define UKAudioStreamBytesPerPacket					@"UKAudioStreamBytesPerPacket"		// NSNumber containing an unsigned int (mBytesPerPacket).
#define UKAudioStreamFramesPerPacket				@"UKAudioStreamFramesPerPacket"		// NSNumber containing an unsigned int (mFramesPerPacket).
#define UKAudioStreamBytesPerFrame					@"UKAudioStreamBytesPerFrame"		// NSNumber containing an unsigned int (mBytesPerFrame).
#define UKAudioStreamChannelsPerFrame				@"UKAudioStreamChannelsPerFrame"	// NSNumber containing an unsigned int (mChannelsPerFrame).
#define UKAudioStreamBitsPerChannel					@"UKAudioStreamBitsPerChannel"		// NSNumber containing an unsigned int (mBitsPerChannel).


// -----------------------------------------------------------------------------
//	Conversion functions:
// -----------------------------------------------------------------------------

// Convert between CoreAudio and Cocoa types:

void			UKAudioStreamDescriptionFromDictionary( NSDictionary* dict, AudioStreamBasicDescription* outDesc );
NSDictionary*	UKDictionaryFromAudioStreamDescription( const AudioStreamBasicDescription* desc );

NSString*		UKStringFromAudioStreamFormatID( UInt32 streamFmt );
UInt32			UKAudioStreamFormatIDFromString( NSString* streamFmt );


// -----------------------------------------------------------------------------
//	UKAudioStreamFormat format values:
// -----------------------------------------------------------------------------

// Some pre-converted stream formats:
//
//	These are supposed to match the ones in CoreAudioTypes.h. If there's any
//	missing, add them and send me the changed source. You can also use
//	UKStringFromAudioStreamFormatID() and UKAudioStreamFormatIDFromString() to
//	convert between the QT and CA types at runtime.

#define UKAudioStreamFormatLinearPCM				@"lpcm"
#define UKAudioStreamFormatAC3                    	@"ac-3"
#define UKAudioStreamFormat60958AC3               	@"cac3"
#define UKAudioStreamFormatAppleIMA4              	@"ima4"
#define UKAudioStreamFormatMPEG4AAC               	@"aac "
#define UKAudioStreamFormatMPEG4CELP              	@"celp"
#define UKAudioStreamFormatMPEG4HVXC              	@"hvxc"
#define UKAudioStreamFormatMPEG4TwinVQ            	@"twvq"
#define UKAudioStreamFormatMACE3                  	@"MAC3"
#define UKAudioStreamFormatMACE6                  	@"MAC6"
#define UKAudioStreamFormatULaw                   	@"ulaw"
#define UKAudioStreamFormatALaw                   	@"alaw"
#define UKAudioStreamFormatQDesign                	@"QDMC"
#define UKAudioStreamFormatQDesign2               	@"QDM2"
#define UKAudioStreamFormatQUALCOMM               	@"Qclp"
#define UKAudioStreamFormatMPEGLayer1             	@".mp1"
#define UKAudioStreamFormatMPEGLayer2             	@".mp2"
#define UKAudioStreamFormatMPEGLayer3             	@".mp3"
#define UKAudioStreamFormatDVAudio                	@"dvca"
#define UKAudioStreamFormatVariableDurationDVAudio	@"vdva"
#define UKAudioStreamFormatTimeCode               	@"time"
#define UKAudioStreamFormatMIDIStream             	@"midi"
#define UKAudioStreamFormatParameterValueStream   	@"apvs"
#define UKAudioStreamFormatAppleLossless          	@"alac"

//	If you want to invent your own meta-formats, use strings longer than
//	4 characters, and use your prefix to prevent them from colliding with
//	any NSxxx or UKxxx things that may come in the future.
