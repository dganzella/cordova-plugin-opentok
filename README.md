Cordova Plugin for OpenTok iOS
===

This is a fork of IjzerenHein/cordova-plugin-opentok plugin with these added functionalities:

- Bug corrections on IOS (The _publisher variable was being initialzied on a thread which was giving null exception sometimes).
- Changed order of views so the web view is in front of the video views, thus making you able to render html content on top of the videos. Make sure to have the backgroun of the cordova webview transparent.
- Face tracking functionalities for Android and IOS (using opentok views).
- Added Reconnecting and Reconnected events.