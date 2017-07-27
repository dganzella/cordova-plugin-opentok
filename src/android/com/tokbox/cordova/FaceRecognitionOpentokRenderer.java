package com.tokbox.cordova;

import android.content.Context;

import android.graphics.PointF

import com.google.android.gms.vision.Frame;
import com.google.android.gms.vision.face.Face;
import com.google.android.gms.vision.face.FaceDetector;
import com.google.android.gms.vision.face.Landmark;

import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.opentok.android.Connection;
import com.opentok.android.OpentokError;
import com.opentok.android.Publisher;
import com.opentok.android.PublisherKit;
import com.opentok.android.Session;
import com.opentok.android.Stream;
import com.opentok.android.Stream.StreamVideoType;
import com.opentok.android.Subscriber;
import com.opentok.android.SubscriberKit;
import com.opentok.android.BaseVideoRenderer;

public class FaceRecognitionOpentokRenderer extends BaseVideoRenderer
{
	private Boolean mShouldRecognizeFaceOnNextFrame = false;
	private CallbackContext mCallbackContext;
	private String mStreamId;
	private Context mAppContext;
	
	 public void setToRecognizeFace(CallbackContext callbackContext, String streamId, Context appContext){
        mShouldRecognizeFaceOnNextFrame = true;
		mCallbackContext = callbackContext;
		mStreamId = streamId;
		mAppContext = appContext;
    }
	
	@Override
    public void onFrame(BaseVideoRenderer.Frame frame)
	{
        if(mShouldRecognizeFaceOnNextFrame)
		{
		  FaceDetector fdetector = new FaceDetector.Builder().build(mAppContext);

		  ArrayList<Face> faces = fdetector.detect(opentokFrame);
		  fdetector.release();
		  
		  FaceDetector.Face face = faces[0];
		  
		  if( face.confidence() >= .3)
		  {
			JSONObject resultdict = new JSONObject();
			
			PointF midpoint = new PointF();
			face.getMidPoint(midpoint);
			
			resultdict.put("eyesDistance", face.eyesDistance()/frame.width());
			resultdict.put("midPointX", midpoint.x/frame.width());
			resultdict.put("midPointY", midpoint.y/frame.height());
			resultdict.put("rotation", face.pose(EULER_Z));

			mCallbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, resultdict));
		  }
		  else
		  {
			JSONObject resultdict = new JSONObject();
			
			resultdict.put("streamId", mStreamId);
			resultdict.put("error", "NO FACE DETECTED");
			mCallbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, resultdict));
		  }

           mShouldRecognizeFaceOnNextFrame = false;
        }
    }
} 