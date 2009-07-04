//
//  UKAudioStreamBasicDescription.m
//  UKSoundFileRecorder
//
//  Created by Uli Kusterer on 14.07.07.
//  Copyright 2007 M. Uli Kusterer. All rights reserved.
//

#import "UKAudioStreamBasicDescription.h"


void			UKAudioStreamDescriptionFromDictionary( NSDictionary* dict, AudioStreamBasicDescription* outDesc )
{
	memset( outDesc, 0, sizeof(AudioStreamBasicDescription) );	// Anything not there gets set to 0.
	
	NSNumber*	num = [dict objectForKey: UKAudioStreamSampleRate];
	if( num )
		outDesc->mSampleRate = [num doubleValue];
	
	NSString* str = [dict objectForKey: UKAudioStreamFormat];
	if( str )
		outDesc->mFormatID = UKAudioStreamFormatIDFromString(str);
	
	num = [dict objectForKey: UKAudioStreamFormatFlags];
	if( num )
		outDesc->mFormatFlags = [num unsignedIntValue];
	
	num = [dict objectForKey: UKAudioStreamBytesPerPacket];
	if( num )
		outDesc->mBytesPerPacket = [num unsignedIntValue];
	
	num = [dict objectForKey: UKAudioStreamFramesPerPacket];
	if( num )
		outDesc->mFramesPerPacket = [num unsignedIntValue];
	
	num = [dict objectForKey: UKAudioStreamBytesPerFrame];
	if( num )
		outDesc->mBytesPerFrame = [num unsignedIntValue];
	
	num = [dict objectForKey: UKAudioStreamChannelsPerFrame];
	if( num )
		outDesc->mChannelsPerFrame = [num unsignedIntValue];
	
	num = [dict objectForKey: UKAudioStreamBitsPerChannel];
	if( num )
		outDesc->mBitsPerChannel = [num unsignedIntValue];
}


NSDictionary*	UKDictionaryFromAudioStreamDescription( const AudioStreamBasicDescription* desc )
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
									[NSNumber numberWithDouble: desc->mSampleRate], UKAudioStreamSampleRate,
									UKStringFromAudioStreamFormatID( desc->mFormatID ), UKAudioStreamFormat,
									[NSNumber numberWithUnsignedInt: desc->mFormatFlags], UKAudioStreamFormatFlags,
									[NSNumber numberWithUnsignedInt: desc->mBytesPerPacket], UKAudioStreamBytesPerPacket,
									[NSNumber numberWithUnsignedInt: desc->mFramesPerPacket], UKAudioStreamFramesPerPacket,
									[NSNumber numberWithUnsignedInt: desc->mBytesPerFrame], UKAudioStreamBytesPerFrame,
									[NSNumber numberWithUnsignedInt: desc->mChannelsPerFrame], UKAudioStreamChannelsPerFrame,
									[NSNumber numberWithUnsignedInt: desc->mBitsPerChannel], UKAudioStreamBitsPerChannel,
									nil
								];
}

NSString*		UKStringFromAudioStreamFormatID( UInt32 streamFmt )
{
	streamFmt = EndianU32_BtoN(streamFmt);
	return [[[NSString alloc] initWithBytes: &streamFmt length: 4 encoding: NSMacOSRomanStringEncoding] autorelease];
}


UInt32			UKAudioStreamFormatIDFromString( NSString* streamFmt )
{
	UInt32		buffer = 0;
	
	if( [streamFmt length] != 4 )
		return 0;
	
	if( CFStringGetBytes( (CFStringRef)streamFmt, CFRangeMake(0,4), kCFStringEncodingMacRoman, 0, false, (UInt8*) &buffer, 4, NULL ) != 4 )
		return 0;	// Must be exactly 4 characters long.
	
	return EndianU32_NtoB(buffer);
}
