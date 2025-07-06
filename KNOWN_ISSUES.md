# Known Issues and Limitations

## Overview

This document outlines known issues, limitations, and areas for improvement in the AudioPal application. These items are tracked for future development and user awareness.

1. The widget doesn't really work. I got excited since i haven't had much opportunity to make widgets before.
So I spent a while learning about them, it appears on screen  but I can't figure out how to sync it to the
main app.

2. Voice-over quality for playback of each message is terrible. It's an archaic robot voice using swift packages
only. it really should be connected to a better service.

3. Audio storage can be a problem if a user selects high quality audio and never deletes them. In the future
I would regularly prompt them to backup their audio on a third party service

4. A major issue is that I did not use swiftdata to handle storage. I have used it before and I know the current
json method will not work for any meaningful amount of data. I did not use my time wisely because I got enamored
with the widget.