package com.tokbox.cordova;

import java.lang.Math;

import java.util.ArrayList;

import android.content.Context;

import android.graphics.PointF;

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
			ByteArrayOutputStream out = new ByteArrayOutputStream();
			YuvImage yuvImage = new YuvImage(data, ImageFormat.NV21, width, height, null);
			yuvImage.compressToJpeg(new Rect(0, 0, width, height), 100, out);
			byte[] imageBytes = out.toByteArray();
			Bitmap image = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.length);
			
			FaceDetector fdetector = new FaceDetector.Builder(cordova.getActivity().getApplicationContext())
				.setTrackingEnabled(false)
							.setLandmarkType(FaceDetector.ALL_LANDMARKS)
							.build();

		   if(fdetector.isOperational())
		   {

				Frame frame = new Frame.Builder().setBitmap(image).build();

				SparseArray<Face> faces = fdetector.detect(frame);
				fdetector.release();
			  
				if( faces.size() > 0 )
				{
				  Face face = faces.get(0);

				  PointF left_eye = face.getLandmarks().get(Landmark.LEFT_EYE).getPosition();
				  PointF right_eye = face.getLandmarks().get(Landmark.RIGHT_EYE).getPosition();

				  PointF diff = new PointF(left_eye.x - right_eye.x, left_eye.y - right_eye.y);
				  
				  double rotation = -Math.atan2(diff.y, Math.abs(diff.x)) * 180.0 / Math.PI;

				  double distance = Math.sqrt( diff.x*diff.x + diff.y*diff.y )/((double)v.getWidth()) * 100.0;
				  
				  PointF midPoint = new PointF ( 
								  (float) ( ((left_eye.x + right_eye.x)/2.0)/(v.getWidth())  * 100.0 ),
								  (float) ( ((left_eye.y + right_eye.y)/2.0)/(v.getHeight()) * 100.0 )
								);
				  
				  JSONObject resultdict = new JSONObject();
				  
				  resultdict.put("eyesDistance", distance);
				  resultdict.put("midPointX", midPoint.x);
				  resultdict.put("midPointY", midPoint.y);
				  resultdict.put("rotation", rotation);
				  resultdict.put("streamId", sid);

				  callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, resultdict));
				}
				else
				{
				  JSONObject resultdict = new JSONObject();
				  
				  resultdict.put("streamId", sid);
				  resultdict.put("error", "NO FACE DETECTED");
				  callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, resultdict));
				}
			}
			else
			{
			  JSONObject resultdict = new JSONObject();
			  
			  resultdict.put("streamId", sid);
			  resultdict.put("error", "FACE DETECTOR NOT OPERATIONAL");
			  callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, resultdict)); 
			}

						
			mShouldRecognizeFaceOnNextFrame = false;
		}
    }
} 