UKSOUNDFILERECORDER
-------------------

This is a class that uses CoreAudio to record sound from a sound input
and writes it to a file or hand the audio samples to a delegate.


LICENSE:

(c) 2007 by M. Uli Kusterer. You may redistribute, modify, use in
commercial products free of charge, however distributing modified copies
requires that you clearly mark them as having been modified by you, while
maintaining the original markings and copyrights. I don't like getting bug
reports about code I wasn't involved in.

I'd also appreciate if you gave credit in your app's about screen or a similar
place. A simple "Thanks to M. Uli Kusterer" is quite sufficient.
Also, I rarely turn down any postcards, gifts, complementary copies of
applications etc.

REVISION HISTORY:

0.1		- Initial public release.
0.1.1	- Small fixes and clean-ups suggested by Nir Soffer: We now throw
		  when trying to change the sound format during recording. That way it's
		  more obvious that's an error than if we just stop recording. Also
		  added the necessary frameworks so the release build of the demo works.

CONTACT:
Get the newest version at http://www.zathras.de
E-Mail me at:
witness (at) zathras (dot) de
kusterer (at) gmail (dot) com
