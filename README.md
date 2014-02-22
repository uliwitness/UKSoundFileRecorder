UKSoundFileRecorder
-------------------

This is a class that uses CoreAudio to record sound from a sound input
and writes it to a file or hand the audio samples to a delegate.


License
-------

	Copyright 2007-2014 by Uli Kusterer.
	
	This software is provided 'as-is', without any express or implied
	warranty. In no event will the authors be held liable for any damages
	arising from the use of this software.
	
	Permission is granted to anyone to use this software for any purpose,
	including commercial applications, and to alter it and redistribute it
	freely, subject to the following restrictions:
	
	   1. The origin of this software must not be misrepresented; you must not
	   claim that you wrote the original software. If you use this software
	   in a product, an acknowledgment in the product documentation would be
	   appreciated but is not required.
	
	   2. Altered source versions must be plainly marked as such, and must not be
	   misrepresented as being the original software.
	
	   3. This notice may not be removed or altered from any source
	   distribution.

REVISION HISTORY:

0.1		- Initial public release.
0.1.1	- Small fixes and clean-ups suggested by Nir Soffer: We now throw
		  when trying to change the sound format during recording. That way it's
		  more obvious that's an error than if we just stop recording. Also
		  added the necessary frameworks so the release build of the demo works.
0.2		- Support for audio device selection and other destinations than files.

