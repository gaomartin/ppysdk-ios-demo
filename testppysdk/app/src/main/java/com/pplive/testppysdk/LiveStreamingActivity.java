package com.pplive.testppysdk;

import android.Manifest;
import android.app.Activity;
import android.app.Application;
import android.app.Dialog;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.net.ConnectivityManager;
import android.os.Bundle;
import android.os.Debug;
import android.os.Handler;
import android.os.Message;
import android.pplive.media.player.MediaInfo;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.support.v7.app.AppCompatActivity;
import android.text.TextUtils;
import android.util.Log;
import android.view.GestureDetector;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.pplive.ppysdk.PPYStatusListener;
import com.pplive.ppysdk.PPYStream;
import com.pplive.ppysdk.PPYStreamerConfig;
import com.pplive.ppysdk.PPYSurfaceView;
import com.pplive.ppysdk.VIDEO_RESOLUTION_TYPE;

public class LiveStreamingActivity extends Activity {


    /**
     * 关闭按钮
     */
    private Button mCloseButton;

    /**
     * 美颜控制按钮
     */
    private Button mBeautyButton;

    /**
     * 帧率、码流切换按钮
     */
    private Button mFPSButton;

    /**
     * 闪光灯按钮
     */
    private Button mFlashButton;

    /**
     * 音量按钮
     */
    private Button mMuteButton;

    /**
     * 切换摄像头
     */
    private Button mToggleButton;
    private Button mToggleMirrorButton;
    /**
     * 推流操作按钮
     */
    private Button mDataTipButton;

    TextView mDataTipTextview;

//    /**
//     * 参数调节视图
//     */
//    private FilterConfigView mConfigView;

//    /**
//     * 页面状态
//     */
//    private boolean mActived = false;

    //-----------------------------------------------------

    // 美颜状态
    private Boolean mBeautyEnabled = false;

    // 静音状态
    private Boolean mMuted = false;

    // 闪光灯状态
    private Boolean mFlashEnabled = false;

    private Boolean mShowDataTip = true;

    private Boolean mFrontCameraMirror = false;

    private TextView mMsgTextview;
    // 美颜处理

    //------------------------------------------------------
//
//    // 要支持多款滤镜，直接添加到数组即可
//    private String[] videoFilters = new String[]{"VideoFair", "VideoWarmSunshine"};
//
//    private int mVideoFilterIndex = 0;
//
//    private GestureDetector mGestureDetector;
//

    String mLiveId;
    String mRtmpUrl;
    PPYSurfaceView mCameraView;
    boolean mIsStreamingStart = false;

    int mType = 1;
    Handler mHandle = new Handler();

    Runnable mHideMsgRunable = new Runnable() {
        @Override
        public void run() {
            Log.d(ConstInfo.TAG, "excute mHideMsgRunable");
            mMsgTextview.setVisibility(View.GONE);
        }
    };

    Runnable mStartRunable = new Runnable() {
        @Override
        public void run() {
            Log.d(ConstInfo.TAG, "excute mStartRunable");
            PPYRestApi.stream_start(mLiveId, new PPYRestApi.StringResultCallack() {
                @Override
                public void result(int errorcode, String data) {
                    if (errorcode != 0)
                    {
                        Log.d(ConstInfo.TAG, "try stream_start agaim");
                        mHandle.postDelayed(mStartRunable, 1000);
                    }
                }
            });
        }
    };

    Runnable mUpdateDataTipRunable = new Runnable() {
        @Override
        public void run() {
            Log.d(ConstInfo.TAG, "excute mUpdateDataTipRunable");
            if (PPYStream.getInstance().IsStreaming())
            {
                int videobitrate = PPYStream.getInstance().getVideoBitrate();
                int fps = PPYStream.getInstance().getVideoFrameRate();
                int vdeio_w = PPYStream.getInstance().getVideoWdith();
                int video_h = PPYStream.getInstance().getVideoHeight();
                String str = String.format(getString(R.string.data_tip), videobitrate, (int)fps, vdeio_w, video_h);
                mDataTipTextview.setText(str);
            }
            mHandle.postDelayed(mUpdateDataTipRunable, 1000);
        }
    };
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(R.layout.live_streaming_activity);

        initView();

        mLiveId = getIntent().getStringExtra("liveid");
        mRtmpUrl = getIntent().getStringExtra("rtmpurl");
        mType = getIntent().getIntExtra("type", 0);
        mCameraView = (PPYSurfaceView)findViewById(R.id.lsq_cameraView);

        AppSettingMode.setSetting(this, "last_liveid", mLiveId);
        AppSettingMode.setSetting(this, "last_liveurl", mRtmpUrl);
        AppSettingMode.setIntSetting(this, "last_type", mType);


        TextView textView = (TextView)findViewById(R.id.liveid);
        textView.setText(getString(R.string.liveid_tip, mLiveId));

        mDataTipTextview = (TextView)findViewById(R.id.msg_tip);

        if (NetworkUtils.isNetworkAvailable(getApplicationContext()))
        {
            if (NetworkUtils.isMobileNetwork(getApplicationContext()))
            {
                ConstInfo.showDialog(LiveStreamingActivity.this, "您当前使用的是移动数据，确定开播吗？", "", "取消", "确定", new AlertDialogResultCallack() {
                    @Override
                    public void cannel() {
                        finish();
                    }

                    @Override
                    public void ok() {
                        StartStream();
                        PPYStream.getInstance().OnResume();
                    }
                });
            }
            else
                StartStream();
        }
        else
        {
            mMsgTextview.setText(getString(R.string.no_network));
            mMsgTextview.setVisibility(View.VISIBLE);
            mHandle.removeCallbacks(mHideMsgRunable);
            StartStream();
        }

        registerBaseBoradcastReceiver(true);
    }

    PPYStatusListener mPPStatusListener = new PPYStatusListener() {
        @Override
        public void onStateChanged(final int i, Object o) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    Log.d(ConstInfo.TAG, "onStateChanged i=" +i);
                    if (i == PPYStatusListener.PPY_SDK_INIT_SUCC)
                    {
                        Log.d(ConstInfo.TAG, "camera init success, start stream");
                        PPYStream.getInstance().StartStream();
                    }
                    else if (i == PPY_STREAM_STOP_EXPECTION)
                    {
                        //Toast.makeText(getApplication(), "网络异常，正在尝试重新连接", Toast.LENGTH_SHORT).show();
                        mMsgTextview.setText("当前网络环境异常，正在重新连接");
                        mMsgTextview.setVisibility(View.VISIBLE);
                        mHandle.postDelayed(mHideMsgRunable, 3000);
                    }
                    else if (i == PPY_STREAM_CONNECTED)
                    {
                        //Toast.makeText(getApplication(), "网络恢复，推流成功", Toast.LENGTH_SHORT).show();
                        mMsgTextview.setText("推流成功");
                        mMsgTextview.setVisibility(View.VISIBLE);
                        mHandle.postDelayed(mHideMsgRunable, 3000);
                    }
                    else if (i == PPY_STREAM_RECONNECT_TIME)
                    {
                        mMsgTextview.setText(getString(R.string.no_network));
                        mMsgTextview.setVisibility(View.VISIBLE);
                        mHandle.removeCallbacks(mHideMsgRunable);
                    }
                }
            });

        }
    };

    private void StopStream()
    {
        if (!mIsStreamingStart)
            return;
        mIsStreamingStart = false;
        Log.d(ConstInfo.TAG, "StopStream");
        PPYStream.getInstance().StopStream();

        PPYStream.getInstance().setPPYStatusListener(null);
        mHandle.removeCallbacks(mUpdateDataTipRunable);
        mHandle.removeCallbacks(mStartRunable);

    }

    private static final int MY_PERMISSIONS_REQUEST_CAMERA = 1;
    public void StartStream()
    {
        if (mIsStreamingStart)
            return;
        mIsStreamingStart = true;
        if (ContextCompat.checkSelfPermission(this,
                Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED)
        {
            ActivityCompat.requestPermissions(this,
                    new String[]{Manifest.permission_group.CAMERA, Manifest.permission_group.MICROPHONE, Manifest.permission_group.STORAGE},
                    MY_PERMISSIONS_REQUEST_CAMERA);
        } else
        {
            StartStreamImpl();
        }
    }

    public void StartStreamImpl()
    {
        Log.d(ConstInfo.TAG, "StartStreamImpl");
        PPYStreamerConfig config = new PPYStreamerConfig();
        config.setPublishurl(mRtmpUrl);
        if (mType == 0)
            config.setVideoResolution(VIDEO_RESOLUTION_TYPE.VIDEO_RESOLUTION_480P);
        else if (mType == 1)
            config.setVideoResolution(VIDEO_RESOLUTION_TYPE.VIDEO_RESOLUTION_540P);
        else if (mType == 2)
            config.setVideoResolution(VIDEO_RESOLUTION_TYPE.VIDEO_RESOLUTION_720P);
        else
            config.setVideoResolution(VIDEO_RESOLUTION_TYPE.VIDEO_RESOLUTION_480P);
        config.setFrameRate(25);
        PPYStream.getInstance().CreateStream(getApplicationContext(), config, mCameraView);

        mHandle.postDelayed(mStartRunable, 1000);
        mHandle.postDelayed(mUpdateDataTipRunable, 1000);

        PPYStream.getInstance().setPPYStatusListener(mPPStatusListener);

    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults)
    {
        if (requestCode == MY_PERMISSIONS_REQUEST_CAMERA)
        {
            if (grantResults[0] == PackageManager.PERMISSION_GRANTED)
            {
                StartStreamImpl();
            } else
            {
                // Permission Denied
                Toast.makeText(LiveStreamingActivity.this, "相机权限不够", Toast.LENGTH_SHORT).show();
            }
            return;
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }


    public void registerBaseBoradcastReceiver(boolean isregister) {
        if (isregister) {
            IntentFilter myIntentFilter = new IntentFilter();
            myIntentFilter.addAction(ConnectivityManager.CONNECTIVITY_ACTION);
            registerReceiver(mBaseBroadcastReceiver, myIntentFilter);
        } else {
            unregisterReceiver(mBaseBroadcastReceiver);
        }
    }

    private BroadcastReceiver mBaseBroadcastReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(final Context context, final Intent intent) {
            if (ConnectivityManager.CONNECTIVITY_ACTION.equals(intent.getAction())) {
                Log.d(ConstInfo.TAG, "connect change");
                if (!NetworkUtils.isNetworkAvailable(context)) {
                    StopStream();
                    mMsgTextview.setText(getString(R.string.no_network));
                    mMsgTextview.setVisibility(View.VISIBLE);
                    mHandle.removeCallbacks(mHideMsgRunable);
                }
                else if (!mIsStreamingStart)
                {
                    if (NetworkUtils.isMobileNetwork(getApplicationContext()))
                    {
                        ConstInfo.showDialog(LiveStreamingActivity.this, "您当前使用的是移动数据，确定开播吗？", "", "取消", "确定", new AlertDialogResultCallack() {
                            @Override
                            public void cannel() {
                                finish();
                            }

                            @Override
                            public void ok() {
                                StartStream();
                                PPYStream.getInstance().OnResume();
                            }
                        });
                    }
                    else
                        StartStream();
                }

            }
        }
    };

    @Override
    protected  void onStop()
    {
        super.onStop();
    }

    @Override
    protected void onResume()
    {
        super.onResume();
        Log.d(ConstInfo.TAG, "onResume");
        PPYStream.getInstance().OnResume();
    }

    @Override
    protected void onPause()
    {
        super.onPause();
        Log.d(ConstInfo.TAG, "onPause");
        PPYStream.getInstance().OnPause();
    }

    @Override
    protected void onDestroy()
    {
        super.onDestroy();
        Log.d(ConstInfo.TAG, "onDestroy");
        PPYStream.getInstance().OnDestroy();
    }

    //--------------------------------------------------  界面处理 ------------------------------------------------

    boolean mIsShowControlPanel = false;
    private void initView()
    {
        mMsgTextview = (TextView)findViewById(R.id.msg_live);
        mMsgTextview.setVisibility(View.GONE);

        mCloseButton = (Button)findViewById(R.id.lsq_closeButton);
        mCloseButton.setOnClickListener(mButtonClickListener);

        mBeautyButton = (Button)findViewById(R.id.lsq_beautyButton);
        mBeautyButton.setOnClickListener(mButtonClickListener);

        mFlashButton = (Button)findViewById(R.id.lsq_flashhightButton);
        mFlashButton.setOnClickListener(mButtonClickListener);

        mMuteButton = (Button)findViewById(R.id.lsq_muteButton);
        mMuteButton.setOnClickListener(mButtonClickListener);

        mToggleButton = (Button)findViewById(R.id.lsq_cameraroationButton);
        mToggleButton.setOnClickListener(mButtonClickListener);

        mDataTipButton = (Button)findViewById(R.id.button_data_tip);
        mDataTipButton.setOnClickListener(mButtonClickListener);

        mToggleMirrorButton = (Button)findViewById(R.id.button_mirror);
        mToggleMirrorButton.setOnClickListener(mButtonClickListener);

        final LinearLayout control_container = (LinearLayout)findViewById(R.id.control_container);
        control_container.setVisibility(mIsShowControlPanel?View.VISIBLE:View.GONE);
        Button upButton = (Button)findViewById(R.id.upButton);
        upButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                mIsShowControlPanel = !mIsShowControlPanel;
                control_container.setVisibility(mIsShowControlPanel?View.VISIBLE:View.GONE);
            }
        });

//        // 参数调节视图
//        getFilterConfigView();

        updateMuteButtonStatus();

        updateBeautyButtonStatus();

        updateFlashButtonStatus();
    }
//
//    private FilterConfigView getFilterConfigView()
//    {
//        if (mConfigView == null)
//        {
//            mConfigView = (FilterConfigView) findViewById(R.id.lsq_filter_config_view);
//            mConfigView.loadView();
//            // 默认隐藏
//            mConfigView.hiddenDefault();
//        }
//
//        return mConfigView;
//    }

    /** 按钮点击事件处理 */
    private View.OnClickListener mButtonClickListener = new View.OnClickListener()
    {
        public void onClick(View v)
        {
            if (v == mCloseButton)
            {
                ConstInfo.showDialog(LiveStreamingActivity.this, "确定要关闭直播吗？", "", "取消", "确定", new AlertDialogResultCallack() {
                    @Override
                    public void cannel() {

                    }

                    @Override
                    public void ok() {
                        StopStream();

                        PPYRestApi.stream_stop(mLiveId, null);
                        AppSettingMode.setSetting(LiveStreamingActivity.this, "last_liveid", "");
                        AppSettingMode.setSetting(LiveStreamingActivity.this, "last_liveurl", "");
                        AppSettingMode.setIntSetting(LiveStreamingActivity.this, "last_type", 0);

                        registerBaseBoradcastReceiver(false);
                        finish();
                    }
                });
            }
            else if (v == mBeautyButton)
            {
                mBeautyEnabled = !mBeautyEnabled;

                PPYStream.getInstance().EnableBeauty(mBeautyEnabled);

                updateBeautyButtonStatus();
            }
            else if (v == mFlashButton)
            {
                mFlashEnabled = !mFlashEnabled;

                PPYStream.getInstance().setFlashLightState(mFlashEnabled);
                // 闪光灯
                updateFlashButtonStatus();
            }
            else if (v == mMuteButton)
            {
                mMuted = !mMuted;
                PPYStream.getInstance().EnableAudio(!mMuted);
                updateMuteButtonStatus();
            }
            else if (v == mToggleButton)
            {
                PPYStream.getInstance().SwitchCamera();
            }
            else if (v == mDataTipButton)
            {
                mShowDataTip = !mShowDataTip;
                updateShowStatus(mShowDataTip);
            }
            else if (v == mToggleMirrorButton)
            {
                mFrontCameraMirror = !mFrontCameraMirror;
                //PPYStream.getInstance().EnableFrontCameraMirror(mFrontCameraMirror);
            }
        }
    };

    @Override
    public void onBackPressed()
    {
        ConstInfo.showDialog(LiveStreamingActivity.this, "确定要关闭直播吗？", "", "取消", "确定", new AlertDialogResultCallack() {
            @Override
            public void cannel() {

            }

            @Override
            public void ok() {
                StopStream();

                PPYRestApi.stream_stop(mLiveId, null);
                AppSettingMode.setSetting(LiveStreamingActivity.this, "last_liveid", "");
                AppSettingMode.setSetting(LiveStreamingActivity.this, "last_liveurl", "");
                AppSettingMode.setIntSetting(LiveStreamingActivity.this, "last_type", 0);

                registerBaseBoradcastReceiver(false);
                finish();
            }
        });

//        StopStream();
//
//        PPYRestApi.stream_stop(mLiveId, null);
//        AppSettingMode.setSetting(LiveStreamingActivity.this, "last_liveid", "");
//        AppSettingMode.setSetting(LiveStreamingActivity.this, "last_liveurl", "");
//        AppSettingMode.setIntSetting(LiveStreamingActivity.this, "last_type", 0);
//
//        registerBaseBoradcastReceiver(false);
//
//        super.onBackPressed();
    }

    private void updateMuteButtonStatus()
    {
        if (mMuteButton != null)
        {
            int imgID = mMuted ? R.drawable.audio_close : R.drawable.audio_open;

            mMuteButton.setBackgroundResource(imgID);
        }
    }

    private void updateFlashButtonStatus()
    {
        if (mFlashButton != null)
        {
            int imgID = mFlashEnabled ? R.drawable.flashlight_open : R.drawable.flashlight_close;

            mFlashButton.setBackgroundResource(imgID);
        }
    }

//    private void updateBeautyCode(String code)
//    {
//        changeVideoFilterCode(code);
//
////        int stringID = this.getResources().getIdentifier("lsq_filter_" + code, "string", this.getApplicationContext().getPackageName());
////
////        String msg = getResources().getString(stringID);
////        if (mActived)
////            TuSdk.messageHub().showToast(this, msg);
//    }
//
//    private void changeVideoFilterCode(String code)
//    {
//        PPYStream.getInstance().EnableBeauty(mBeautyEnabled);
//    }

    private void updateBeautyButtonStatus()
    {
        int imgID = mBeautyEnabled ? R.drawable.beatuy_open : R.drawable.beatuy_close;

        if (mBeautyButton != null)
            mBeautyButton.setBackgroundResource(imgID);
//
//        int  msgID = mBeautyEnabled ? R.string.beauty_on: R.string.beauty_off;
//
//        if (mActived) TuSdk.messageHub().showToast(this, msgID);
    }

    /**
     * 更新操作按钮
     *
     * @param isRunning 是否直播中
     */
    private void updateShowStatus(Boolean isRunning)
    {
        int imgID = isRunning ? R.drawable.data_tip_rtmp_open : R.drawable.data_tip_rtmp_close;

        mDataTipTextview.setVisibility(isRunning?View.VISIBLE:View.GONE);

        if (mDataTipButton != null)
            mDataTipButton.setBackgroundResource(imgID);
    }
}
