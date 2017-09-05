Cordova Plugin for OpenTok iOS
===

This is a fork of IjzerenHein/cordova-plugin-opentok plugin with these added functionalities:

- Bug corrections on IOS (The _publisher variable was being initialzied on a thread which was giving null exception sometimes).
- Bug correction on Android (UpdateViews would initialize publisher if it was called before the method "publish", thus breaking variables on the javascript end).
- Changed order of views so the web view is in front of the video views, thus making you able to render html content on top of the videos. Make sure to have the background of the cordova webview transparent. You can disable it by setting the boolean isVideoOnBackGround to false both on Android and Ios.
- Face tracking functionalities for Android and IOS (using opentok views).
- Added Reconnecting and Reconnected events.