//
//  OpentokPlugin.m
//
//  Copyright (c) 2012 TokBox. All rights reserved.
//  Please see the LICENSE included with this distribution for details.
//

#import "OpentokPlugin.h"

const bool isVideoOnBackground = true;


@implementation OpenTokPlugin{
    OTSession* _session;
    OTPublisher* _publisher;
    OTSubscriber* _subscriber;
    NSMutableDictionary *subscriberDictionary;
    NSMutableDictionary *connectionDictionary;
    NSMutableDictionary *streamDictionary;
    NSMutableDictionary *callbackList;
}

@synthesize exceptionId;

#pragma mark -
#pragma mark Cordova Methods
-(void) pluginInitialize
{
    callbackList = [[NSMutableDictionary alloc] init];
    
    if(isVideoOnBackground)
    {
        self.webView.superview.backgroundColor = [UIColor whiteColor]; //app background
        [self.webView.superview setOpaque:NO];
        
        self.webView.backgroundColor = [UIColor clearColor];
        [self.webView setOpaque:NO];
    }
}
- (void)addEvent:(CDVInvokedUrlCommand*)command{
    NSString* event = [command.arguments objectAtIndex:0];
    [callbackList setObject:command.callbackId forKey: event];
}


#pragma mark -
#pragma mark Cordova JS - iOS bindings
#pragma mark TB Methods
/*** TB Methods
 ****/
// Called by TB.addEventListener('exception', fun...)
-(void)exceptionHandler:(CDVInvokedUrlCommand*)command{
    self.exceptionId = command.callbackId;
}

// Called by TB.initsession()
-(void)initSession:(CDVInvokedUrlCommand*)command{
    NSLog(@"initSession...");
    
    // Get Parameters
    NSString* apiKey = [command.arguments objectAtIndex:0];
    NSString* sessionId = [command.arguments objectAtIndex:1];
    
    // Create Session
    _session = [[OTSession alloc] initWithApiKey: apiKey sessionId:sessionId delegate:self];
    NSLog(@"initSession done");
    
    // Initialize Dictionary, contains DOM info for every stream
    subscriberDictionary = [[NSMutableDictionary alloc] init];
    streamDictionary = [[NSMutableDictionary alloc] init];
    connectionDictionary = [[NSMutableDictionary alloc] init];
    
    // Return Result
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Called by TB.initPublisher()
- (void)initPublisher:(CDVInvokedUrlCommand *)command{
    NSLog(@"initPublisher...");
    // [self.commandDelegate runInBackground:^{
    BOOL bpubAudio = YES;
    BOOL bpubVideo = YES;
    
    // Get Parameters
    NSString* name = [command.arguments objectAtIndex:0];
    int top = [[command.arguments objectAtIndex:1] intValue];
    int left = [[command.arguments objectAtIndex:2] intValue];
    int width = [[command.arguments objectAtIndex:3] intValue];
    int height = [[command.arguments objectAtIndex:4] intValue];
    int zIndex = [[command.arguments objectAtIndex:5] intValue];
    int borderRadius = [[command.arguments objectAtIndex:8] intValue];
    
    NSString* publishAudio = [command.arguments objectAtIndex:6];
    if ([publishAudio isEqualToString:@"false"]) {
        bpubAudio = NO;
    }
    NSString* publishVideo = [command.arguments objectAtIndex:7];
    if ([publishVideo isEqualToString:@"false"]) {
        bpubVideo = NO;
    }
    
    // Publish and set View
    _publisher = [[OTPublisher alloc] initWithDelegate:self name:name];
    [_publisher setPublishAudio:bpubAudio];
    [_publisher setPublishVideo:bpubVideo];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^
     {
         if(isVideoOnBackground)
         {
             [self.webView.superview insertSubview:_publisher.view atIndex:0];
             self.webView.layer.zPosition = 999;
             
             [_publisher.view setFrame:CGRectMake(left, top, width, height)];
             _publisher.view.layer.zPosition = 1;
         }
         else
         {
             [self.webView.superview addSubview:_publisher.view];
             if (zIndex>0) {
                 _publisher.view.layer.zPosition = zIndex;
             }
         }
         
         NSString* cameraPosition = [command.arguments objectAtIndex:8];
         if ([cameraPosition isEqualToString:@"back"]) {
             _publisher.cameraPosition = AVCaptureDevicePositionBack;
         }
         _publisher.view.layer.cornerRadius = borderRadius;
         _publisher.view.clipsToBounds = borderRadius ? YES : NO;
         
         NSLog(@"initPublisher done");
         
         // Return to Javascript
         CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
         [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
     }];
    // }];
}
// Helper function to update Views
- (void)updateView:(CDVInvokedUrlCommand*)command{
    //NSString* callback = command.callbackId;
    NSString* sid = [command.arguments objectAtIndex:0];
    int top = [[command.arguments objectAtIndex:1] intValue];
    int left = [[command.arguments objectAtIndex:2] intValue];
    int width = [[command.arguments objectAtIndex:3] intValue];
    int height = [[command.arguments objectAtIndex:4] intValue];
    int zIndex = [[command.arguments objectAtIndex:5] intValue];
    int borderRadius = [[command.arguments objectAtIndex:8] intValue];
    
    //NSLog(@"updateView: %@, left: %d, top: %d, width: %d, height: %d, zIndex: %d", sid, left, top, width, height, zIndex);
    
    if ([sid isEqualToString:@"TBPublisher"]) {
        _publisher.view.frame = CGRectMake(left, top, width, height);
        _publisher.view.layer.zPosition = zIndex;
        _publisher.view.layer.cornerRadius = borderRadius;
        _publisher.view.clipsToBounds = borderRadius ? YES : NO;
    }
    else {
        
        // Pulls the subscriber object from dictionary to prepare it for update
        OTSubscriber* streamInfo = [subscriberDictionary objectForKey:sid];
        if (streamInfo) {
            // Reposition the video feeds!
            streamInfo.view.frame = CGRectMake(left, top, width, height);
            streamInfo.view.layer.zPosition = zIndex;
            streamInfo.view.layer.cornerRadius = borderRadius;
            streamInfo.view.clipsToBounds = borderRadius ? YES : NO;
        }
    }
    
    CDVPluginResult* callbackResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [callbackResult setKeepCallbackAsBool:YES];
    //[self.commandDelegate sendPluginResult:callbackResult toSuccessCallbackString:command.callbackId];
    [self.commandDelegate sendPluginResult:callbackResult callbackId:command.callbackId];
}

#pragma mark Publisher Methods
- (void)publishAudio:(CDVInvokedUrlCommand*)command{
    NSString* publishAudio = [command.arguments objectAtIndex:0];
    NSLog(@"iOS Altering Audio publishing state, %@", publishAudio);
    BOOL pubAudio = YES;
    if ([publishAudio isEqualToString:@"false"]) {
        pubAudio = NO;
    }
    [_publisher setPublishAudio:pubAudio];
}
- (void)publishVideo:(CDVInvokedUrlCommand*)command{
    NSString* publishVideo = [command.arguments objectAtIndex:0];
    NSLog(@"iOS Altering Video publishing state, %@", publishVideo);
    BOOL pubVideo = YES;
    if ([publishVideo isEqualToString:@"false"]) {
        pubVideo = NO;
    }
    [_publisher setPublishVideo:pubVideo];
}
- (void)setCameraPosition:(CDVInvokedUrlCommand*)command{
    NSString* publishCameraPosition = [command.arguments objectAtIndex:0];
    NSLog(@"iOS Altering Video camera position, %@", publishCameraPosition);
    
    if ([publishCameraPosition isEqualToString:@"back"]) {
        [_publisher setCameraPosition:AVCaptureDevicePositionBack];
    } else if ([publishCameraPosition isEqualToString:@"front"]) {
        [_publisher setCameraPosition:AVCaptureDevicePositionFront];
    }
}
- (void)destroyPublisher:(CDVInvokedUrlCommand *)command{
    NSLog(@"destroyPublisher");
    
    // Remove publisher view
    if (_publisher) {
        [_publisher.view removeFromSuperview];
    }
    
    [self.commandDelegate runInBackground:^{
        OTError *error;
        NSLog(@"Session.unpublish");
        [_session unpublish:_publisher error:nil];
        
        if (error) {
            NSLog(@"Session.unpublish failed: %@", [error localizedDescription]);
        }
        else {
            NSLog(@"Session.unpublish done");
        }
        
        CDVPluginResult* pluginResult = error ?
        [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"%@ DESTROY PUBLISHER", [error localizedDescription]]] :
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}


#pragma mark Session Methods
- (void)connect:(CDVInvokedUrlCommand *)command{
    NSLog(@"Session.connect");
    [self.commandDelegate runInBackground:^{
        OTError *error;
        
        // Get Parameters
        NSString* tbToken = [command.arguments objectAtIndex:0];
        [_session connectWithToken:tbToken error:&error];
        
        if (error) {
            NSLog(@"Session.connect failed: %@", [error localizedDescription]);
        }
        else {
            NSLog(@"Session.connect done");
        }
        
        CDVPluginResult* pluginResult = error ?
        [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"%@ CONNECT", [error localizedDescription]]] :
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

// Called by session.disconnect()
- (void)disconnect:(CDVInvokedUrlCommand*)command{
    NSLog(@"Session.disconnect...");
    [self.commandDelegate runInBackground:^{
        OTError *error;
        [_session disconnect:&error];
        
        if (error) {
            NSLog(@"Session.disconnect failed: %@", [error localizedDescription]);
        }
        else {
            NSLog(@"Session.disconnect done");
        }
        
        CDVPluginResult* pluginResult = error ?
        [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"%@ DISCONNECT", [error localizedDescription]]] :
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

// Called by session.publish(top, left)
- (void)publish:(CDVInvokedUrlCommand*)command{
    NSLog(@"Session.publish...");
    [self.commandDelegate runInBackground:^{
        OTError *error;
        
        [_session publish:_publisher error:&error];
        
        if (error) {
            NSLog(@"Session.publish failed: %@", [error localizedDescription]);
        }
        else {
            NSLog(@"Session.publish done");
        }
        
        
        CDVPluginResult* pluginResult = error ?
        [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"%@ PUBLISH %@", [error localizedDescription], _publisher == nil ? @"PUBLISHER NIL" : @"PUBLISHER NOT NIL"]] :
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

// Called by session.unpublish(...)
- (void)unpublish:(CDVInvokedUrlCommand*)command{
    NSLog(@"Session.unpublish...");
    [self.commandDelegate runInBackground:^{
        OTError *error;
        [_session unpublish:_publisher error:nil];
        
        if (error) {
            NSLog(@"Session.unpublish failed: %@", [error localizedDescription]);
        }
        else {
            NSLog(@"Session.unpublish done");
        }
        
        CDVPluginResult* pluginResult = error ?
        [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"%@ UNPUBLISH", [error localizedDescription]]] :
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

// Called by session.subscribe(streamId, top, left)
- (void)subscribe:(CDVInvokedUrlCommand*)command{
    NSLog(@"Session.subscribe...");
    
    // Get Parameters
    NSString* sid = [command.arguments objectAtIndex:0];
    
    int top = [[command.arguments objectAtIndex:1] intValue];
    int left = [[command.arguments objectAtIndex:2] intValue];
    int width = [[command.arguments objectAtIndex:3] intValue];
    int height = [[command.arguments objectAtIndex:4] intValue];
    int zIndex = [[command.arguments objectAtIndex:5] intValue];
    int borderRadius = [[command.arguments objectAtIndex:8] intValue];
    
    // Acquire Stream, then create a subscriber object and put it into dictionary
    OTStream* myStream = [streamDictionary objectForKey:sid];
    OTSubscriber* sub = [[OTSubscriber alloc] initWithStream:myStream delegate:self];
    OTError *error;
    [_session subscribe:sub error:&error];
    
    if ([[command.arguments objectAtIndex:6] isEqualToString:@"false"]) {
        [sub setSubscribeToAudio: NO];
    }
    if ([[command.arguments objectAtIndex:7] isEqualToString:@"false"]) {
        [sub setSubscribeToVideo: NO];
    }
    [subscriberDictionary setObject:sub forKey:myStream.streamId];
    
    [sub.view setFrame:CGRectMake(left, top, width, height)];
    
    sub.view.layer.cornerRadius = borderRadius;
    sub.view.clipsToBounds = borderRadius ? YES : NO;
    
    if(isVideoOnBackground)
    {
        [self.webView.superview insertSubview:sub.view atIndex:0];
        self.webView.layer.zPosition = 999;
        sub.view.layer.zPosition = 1;
    }
    else
    {
        if (zIndex>0) {
            sub.view.layer.zPosition = zIndex;
        }
        [self.webView.superview addSubview:sub.view];
    }
    
    if (error) {
        NSLog(@"Session.subscribe failed: %@", [error localizedDescription]);
    }
    else {
        NSLog(@"Session.subscribe done");
    }
    
    CDVPluginResult* pluginResult = error ?
    [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"%@ SUBSCRIBE", [error localizedDescription]]] :
    [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Called by session.unsubscribe(streamId, top, left)
- (void)unsubscribe:(CDVInvokedUrlCommand*)command{
    NSLog(@"Session.unsubscribe...");
    
    //Get Parameters
    NSString* sid = [command.arguments objectAtIndex:0];
    
    OTSubscriber * subscriber = [subscriberDictionary objectForKey:sid];
    [subscriber.view removeFromSuperview];
    [subscriberDictionary removeObjectForKey:sid];
    
    [self.commandDelegate runInBackground:^{
        OTError *error;
        [_session unsubscribe:subscriber error:&error];
        
        if (error) {
            NSLog(@"Session.unsubscribe failed: %@", [error localizedDescription]);
        }
        else {
            NSLog(@"Session.unsubscribe done");
        }
        
        CDVPluginResult* pluginResult = error ?
        [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"%@ UNSUBSCRIBE", [error localizedDescription]]] :
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

// Called by session.unsubscribe(streamId, top, left)
- (void)signal:(CDVInvokedUrlCommand*)command{
    NSLog(@"iOS signaling to connectionId %@", [command.arguments objectAtIndex:2]);
    OTConnection* c = [connectionDictionary objectForKey: [command.arguments objectAtIndex:2]];
    NSLog(@"iOS signaling to connection %@", c);
    [_session signalWithType:[command.arguments objectAtIndex:0] string:[command.arguments objectAtIndex:1] connection:c error:nil];
}


#pragma mark -
#pragma mark Delegates
#pragma mark Subscriber Delegates
/*** Subscriber Methods
 ****/
- (void)subscriberDidConnectToStream:(OTSubscriberKit*)sub{
    NSLog(@"iOS Connected To Stream");
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    NSString* streamId = sub.stream.streamId;
    [eventData setObject:streamId forKey:@"streamId"];
    [self triggerJSEvent: @"sessionEvents" withType: @"subscribedToStream" withData: eventData];
    
}
- (void)subscriber:(OTSubscriber*)subscrib didFailWithError:(OTError*)error{
    NSLog(@"subscriber didFailWithError %@", error);
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    NSString* streamId = subscrib.stream.streamId;
    NSNumber* errorCode = [NSNumber numberWithInt:1600];
    [eventData setObject: errorCode forKey:@"errorCode"];
    [eventData setObject:streamId forKey:@"streamId"];
    [self triggerJSEvent: @"sessionEvents" withType: @"subscribedToStream" withData: eventData];
}


#pragma mark Session Delegates
- (void)sessionDidConnect:(OTSession*)session{
    NSLog(@"iOS Connected to Session");
    
    NSMutableDictionary* sessionDict = [[NSMutableDictionary alloc] init];
    
    // SessionConnectionStatus
    NSString* connectionStatus = @"";
    if (session.sessionConnectionStatus==OTSessionConnectionStatusConnected) {
        connectionStatus = @"OTSessionConnectionStatusConnected";
    }else if (session.sessionConnectionStatus==OTSessionConnectionStatusConnecting) {
        connectionStatus = @"OTSessionConnectionStatusConnecting";
    }else if (session.sessionConnectionStatus==OTSessionConnectionStatusDisconnecting) {
        connectionStatus = @"OTSessionConnectionStatusDisconnected";
    }else{
        connectionStatus = @"OTSessionConnectionStatusFailed";
    }
    [sessionDict setObject:connectionStatus forKey:@"sessionConnectionStatus"];
    
    // SessionId
    [sessionDict setObject:session.sessionId forKey:@"sessionId"];
    
    [connectionDictionary setObject: session.connection forKey: session.connection.connectionId];
    
    
    // After session is successfully connected, the connection property is available
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:@"status" forKey:@"connected"];
    NSMutableDictionary* connectionData = [self createDataFromConnection: session.connection];
    [eventData setObject: connectionData forKey: @"connection"];
    
    
    NSLog(@"object for session is %@", sessionDict);
    
    // After session dictionary is constructed, return the result!
    //    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:sessionDict];
    //    NSString* sessionConnectCallback = [callbackList objectForKey:@"sessSessionConnected"];
    //    [self.commandDelegate sendPluginResult:pluginResult callbackId:sessionConnectCallback];
    
    
    [self triggerJSEvent: @"sessionEvents" withType: @"sessionConnected" withData: eventData];
}


- (void)session:(OTSession *)session connectionCreated:(OTConnection *)connection
{
    [connectionDictionary setObject: connection forKey: connection.connectionId];
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* connectionData = [self createDataFromConnection: connection];
    [data setObject: connectionData forKey: @"connection"];
    [self triggerJSEvent: @"sessionEvents" withType: @"connectionCreated" withData: data];
}

- (void)session:(OTSession *)session connectionDestroyed:(OTConnection *)connection
{
    [connectionDictionary removeObjectForKey: connection.connectionId];
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* connectionData = [self createDataFromConnection: connection];
    [data setObject: connectionData forKey: @"connection"];
    [self triggerJSEvent: @"sessionEvents" withType: @"connectionDestroyed" withData: data];
}
- (void)session:(OTSession*)mySession streamCreated:(OTStream*)stream{
    NSLog(@"iOS Received Stream");
    [streamDictionary setObject:stream forKey:stream.streamId];
    [self triggerStreamCreated: stream withEventType: @"sessionEvents"];
}
- (void)session:(OTSession*)session streamDestroyed:(OTStream *)stream{
    NSLog(@"iOS Drop Stream");
    
    OTSubscriber * subscriber = [subscriberDictionary objectForKey:stream.streamId];
    if (subscriber) {
        NSLog(@"subscriber found, unsubscribing");
        [_session unsubscribe:subscriber error:nil];
        [subscriber.view removeFromSuperview];
        [subscriberDictionary removeObjectForKey:stream.streamId];
    }
    [self triggerStreamDestroyed: stream withEventType: @"sessionEvents"];
}
- (void)session:(OTSession*)session didFailWithError:(OTError*)error {
    NSLog(@"Error: Session did not Connect");
    NSLog(@"Error: %@", error);
    NSNumber* code = [NSNumber numberWithInteger:[error code]];
    NSMutableDictionary* err = [[NSMutableDictionary alloc] init];
    [err setObject:error.localizedDescription forKey:@"message"];
    [err setObject:code forKey:@"code"];
    
    if (self.exceptionId) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: err];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.exceptionId];
    }
}
- (void)sessionDidDisconnect:(OTSession*)session{
    NSString* alertMessage = [NSString stringWithFormat:@"Session disconnected: (%@)", session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
    
    // Setting up event object
    for ( id key in subscriberDictionary ) {
        OTSubscriber* aStream = [subscriberDictionary objectForKey:key];
        [aStream.view removeFromSuperview];
    }
    [subscriberDictionary removeAllObjects];
    if( _publisher ){
        [_publisher.view removeFromSuperview];
    }
    
    // Setting up event object
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:@"clientDisconnected" forKey:@"reason"];
    [self triggerJSEvent: @"sessionEvents" withType: @"sessionDisconnected" withData: eventData];
}
-(void) session:(OTSession *)session receivedSignalType:(NSString *)type fromConnection:(OTConnection *)connection withString:(NSString *)string{
    
    NSLog(@"iOS Session Received signal from Connection: %@ with id %@", connection, [connection connectionId]);
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    [data setObject: type forKey: @"type"];
    [data setObject: string forKey: @"data"];
    if (connection.connectionId) {
        [data setObject: connection.connectionId forKey: @"connectionId"];
        [self triggerJSEvent: @"sessionEvents" withType: @"signalReceived" withData: data];
    }
}


#pragma mark Publisher Delegates
- (void)publisher:(OTPublisherKit *)publisher streamCreated:(OTStream *)stream{
    [streamDictionary setObject:stream forKey:stream.streamId];
    [self triggerStreamCreated: stream withEventType: @"publisherEvents"];
}
- (void)publisher:(OTPublisherKit*)publisher streamDestroyed:(OTStream *)stream{
    [self triggerStreamDestroyed: stream withEventType: @"publisherEvents"];
}
- (void)publisher:(OTPublisher*)publisher didFailWithError:(NSError*) error {
    NSLog(@"iOS Publisher didFailWithError");
    NSMutableDictionary* err = [[NSMutableDictionary alloc] init];
    [err setObject:error.localizedDescription forKey:@"message"];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: err];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.exceptionId];
}

#pragma mark -
#pragma mark Helper Methods
- (void)triggerStreamCreated: (OTStream*) stream withEventType: (NSString*) eventType{
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* streamData = [self createDataFromStream: stream];
    [data setObject: streamData forKey: @"stream"];
    [self triggerJSEvent: eventType withType: @"streamCreated" withData: data];
}
- (void)triggerStreamDestroyed: (OTStream*) stream withEventType: (NSString*) eventType{
    [streamDictionary removeObjectForKey: stream.streamId];
    
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* streamData = [self createDataFromStream: stream];
    [data setObject: streamData forKey: @"stream"];
    [self triggerJSEvent: eventType withType: @"streamDestroyed" withData: data];
}
- (NSMutableDictionary*)createDataFromConnection:(OTConnection*)connection{
    NSLog(@"iOS creating data from stream: %@", connection);
    NSMutableDictionary* connectionData = [[NSMutableDictionary alloc] init];
    [connectionData setObject: connection.connectionId forKey: @"connectionId" ];
    [connectionData setObject: [NSString stringWithFormat:@"%.0f", [connection.creationTime timeIntervalSince1970]] forKey: @"creationTime" ];
    if (connection.data) {
        [connectionData setObject: connection.data forKey: @"data" ];
    }
    return connectionData;
}
- (NSMutableDictionary*)createDataFromStream:(OTStream*)stream{
    NSMutableDictionary* streamData = [[NSMutableDictionary alloc] init];
    [streamData setObject: stream.connection.connectionId forKey: @"connectionId" ];
    [streamData setObject: [NSString stringWithFormat:@"%.0f", [stream.creationTime timeIntervalSince1970]] forKey: @"creationTime" ];
    [streamData setObject: [NSNumber numberWithInt:-999] forKey: @"fps" ];
    [streamData setObject: [NSNumber numberWithBool: stream.hasAudio] forKey: @"hasAudio" ];
    [streamData setObject: [NSNumber numberWithBool: stream.hasVideo] forKey: @"hasVideo" ];
    [streamData setObject: stream.name forKey: @"name" ];
    [streamData setObject: stream.streamId forKey: @"streamId" ];
    return streamData;
}
- (void)triggerJSEvent:(NSString*)event withType:(NSString*)type withData:(NSMutableDictionary*) data{
    NSMutableDictionary* message = [[NSMutableDictionary alloc] init];
    [message setObject:type forKey:@"eventType"];
    [message setObject:data forKey:@"data"];
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [pluginResult setKeepCallbackAsBool:YES];
    
    NSString* callbackId = [callbackList objectForKey:event];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (UIImage *) screenShotImageWithView :(UIView *) view
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, [UIScreen mainScreen].scale);
    
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}


-(void)recognizeFace:(CDVInvokedUrlCommand*)command
{
    NSString* sid = [command.arguments objectAtIndex:0];
    bool isPublisher = [[command.arguments objectAtIndex:1] boolValue];
    
    UIView * targetView;
    
    if(isPublisher)
        targetView = _publisher.view;
    else
    {
        OTSubscriber * sub = [subscriberDictionary objectForKey: sid];
        targetView = sub.view;
    }
    
    if(targetView != nil )
    {
        CIContext *context = [CIContext context];
        
        NSDictionary *opts = @{ CIDetectorAccuracy : CIDetectorAccuracyHigh };
        
        CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                                  context:context
                                                  options:opts];
        
        UIImage * opentokframe = [self screenShotImageWithView: targetView];
        
        [self.commandDelegate runInBackground:^{
            
            CDVPluginResult* pluginResult;
            
            CIImage * finalimage = [[CIImage alloc] initWithCGImage: opentokframe.CGImage options:nil];
            //1 means landscape and not inverted
            NSDictionary * optsfeatures = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt:1] forKey: CIDetectorImageOrientation];
            
            NSArray * features = [detector featuresInImage:finalimage options:optsfeatures];
            
            float finalwidth = CGImageGetWidth(opentokframe.CGImage);
            float finalheight = CGImageGetHeight(opentokframe.CGImage);
            
            //NSLog(@"Final image width height %g %g", finalwidth, finalheight);
            
            if(features.count > 0)
            {
                CIFaceFeature * face = features[0];
                
                if (face.hasLeftEyePosition && face.hasRightEyePosition)
                {
					float invertedLeftY = finalheight -  face.leftEyePosition.y;
					float invertedRightY = finalheight -  face.rightEyePosition.y;
	
					float diffx =  face.leftEyePosition.x - face.rightEyePosition.x;
					float diffy = invertedLeftY - invertedRightY;

					float rotation = -atan2(diffy, fabsf(diffx)) * 180.0 / 3.1415926;

					float distance = sqrt( diffx*diffx + diffy*diffy )/finalwidth * 100.0;

					float midPointX = ((face.leftEyePosition.x + face.rightEyePosition.x)/2.0)/finalwidth * 100.0;
					float midPointY = ((invertedLeftY + invertedRightY)/2.0)/finalheight * 100.0;

                    NSMutableDictionary * featuresdict = [[NSMutableDictionary alloc] initWithCapacity:5];
					
					[featuresdict setObject: [NSNumber numberWithFloat:distance] forKey:@"eyesDistance"];
					[featuresdict setObject: [NSNumber numberWithFloat:midPointX] forKey:@"midPointX"];
					[featuresdict setObject: [NSNumber numberWithFloat:midPointY] forKey:@"midPointY"];
                    [featuresdict setObject: [NSNumber numberWithFloat:rotation] forKey:@"rotation"];
					[featuresdict setObject: sid forKey:@"streamId"];
                    
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: featuresdict];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
                else
                {
                    NSMutableDictionary * errorDict = [[NSMutableDictionary alloc] initWithCapacity:2];
                    [errorDict setObject: sid forKey:@"streamId"];
                    [errorDict setObject: [NSString stringWithFormat:@"DIDNT FIND EYES"] forKey:@"error"];
                    
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorDict];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
            }
            else
            {
                NSMutableDictionary * errorDict = [[NSMutableDictionary alloc] initWithCapacity:2];
                [errorDict setObject: sid forKey:@"streamId"];
                [errorDict setObject: [NSString stringWithFormat:@"NO FACE DETECTED"] forKey:@"error"];
                
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary: errorDict];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
            
        }];
    }
    else
    {
        
        NSMutableDictionary * errorDict = [[NSMutableDictionary alloc] initWithCapacity:2];
        [errorDict setObject: sid forKey:@"streamId"];
        [errorDict setObject: [NSString stringWithFormat:@"UIVIEW FOR STREAMID NOT FOUND"] forKey:@"error"];
        
        CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:errorDict];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

/***** Notes
 
 
 NSString *stringObtainedFromJavascript = [command.arguments objectAtIndex:0];
 CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: stringObtainedFromJavascript];
 
 if(YES){
 [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackID]];
 }else{
 //Call  the Failure Javascript function
 [self.commandDelegate [pluginResult toErrorCallbackString:self.callbackID]];
 }
 
 ******/


@end

