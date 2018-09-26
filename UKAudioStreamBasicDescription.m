//
//  UKAudioStreamBasicDescription.m
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

#if !__has_feature(objc_arc)
#error This file must be compiled with automated reference counting activated.
#endif

// -----------------------------------------------------------------------------
//	Headers:
// -----------------------------------------------------------------------------

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
	return [[NSString alloc] initWithBytes: &streamFmt length: 4 encoding: NSMacOSRomanStringEncoding];
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


NSString * UKStringFromAudioFormatFlags( AudioFormatFlags inFlags )
{
	NSMutableString * fmtStr = [NSMutableString new];
	
	if( inFlags & kAudioFormatFlagIsFloat )
		[fmtStr appendString: @"isFloat, "];
	if( inFlags & kAudioFormatFlagIsBigEndian )
		[fmtStr appendString: @"isBigEndian, "];
	if( inFlags & kAudioFormatFlagIsSignedInteger )
		[fmtStr appendString: @"isSignedInteger, "];
	if( inFlags & kAudioFormatFlagIsPacked )
		[fmtStr appendString: @"isPacked, "];
	if( inFlags & kAudioFormatFlagIsAlignedHigh )
		[fmtStr appendString: @"isAlignedHigh, "];
	if( inFlags & kAudioFormatFlagIsNonInterleaved )
		[fmtStr appendString: @"isNonInterleaved, "];
	if( inFlags & kAudioFormatFlagIsNonMixable )
		[fmtStr appendString: @"isNonMixable, "];
	if( fmtStr.length > 0 )
	{
		[fmtStr deleteCharactersInRange: NSMakeRange( fmtStr.length -2, 2)];
	}
	return fmtStr;
}

