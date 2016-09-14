//
//  PPYPushEngine.h
//  PPYLiveKit
//
//  Created by Jimmy on 16/8/22.
//  Copyright © 2016年 高国栋. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "PPYVideoConfiguration.h"
#import "PPYAudioConfiguration.h"

typedef NS_ENUM(NSUInteger, PPYPushEngineStreamStatus){
    PPYConnectionState_Connecting,
    PPYConnectionState_Connected,
    PPYConnectionStatus_Started,
    PPYConnectionStatus_Ended,
};

typedef NS_ENUM (int,PPYPushEngineErrorType)  {
    PPYPushEngineError_Unknow,
    PPYPushEngineError_ConnectFailed,
    PPYPushEngineError_TransferFailed,
    PPYPushEngineError_FatalError,
};

typedef NS_ENUM(int,PPYPushEngineStreamInfoType){
    PPYPushEngineInfo_BufferingBytes,
    PPYPushEngineInfo_RealBirate,
    PPYPushEngineInfo_RealFPS,
};

@protocol  PPYPushEngineDelegate <NSObject>
-(void)didStreamStateChanged:(PPYPushEngineStreamStatus)status;
-(void)didStreamErrorOccured:(PPYPushEngineErrorType)error;
-(void)didStreamInfoThrowOut:(PPYPushEngineStreamInfoType)type infoValue:(int)value;
@end

@interface PPYPushEngine : NSObject

@property (nonatomic, weak) id<PPYPushEngineDelegate> delegate;

#pragma --Capture Interface--
@property (nonatomic, assign, getter=isRunning) BOOL running;
@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;
@property (nonatomic, strong) UIView *preview;

@property (assign, nonatomic,getter=isMirror)   BOOL mirror; //defalut is NO;

@property (assign, nonatomic, readonly) BOOL hasTorch;
@property (assign, nonatomic,getter=isTorch)    BOOL torch;  //default is NO;

@property (assign, nonatomic, readonly) BOOL hasFocus;
@property (assign, nonatomic,getter=isAutoFocus) BOOL autoFocus; //if no focus func, ignored!

@property (assign, nonatomic,getter=isBeautify) BOOL beautify;  //defalut is YES;
@property (nonatomic, assign) CGFloat beautyLevel;   //default is 0.5, range 0~1;
@property (nonatomic, assign) CGFloat brightLevel;   //default is 0.5, range 0~1;
@property (nonatomic, assign) CGFloat toneLevel;     //default is 0.5, range 0~1;

@property (nonatomic, assign, getter=isMute) BOOL mute; //default is NO;

-(void)doFocusOnPoint:(CGPoint)aPoint onView:(UIView*)view needDisplayLocation:(BOOL)isNeeded;
#pragma -- Interface--

#pragma --Push Interface--
-(void)start;
-(void)stop;
-(void)teardown;

#pragma --Inialize--
-(instancetype)initWithAudioConfiguration:(PPYAudioConfiguration *)audioConfig
                    andVideoConfiguration:(PPYVideoConfiguration *)videoConfig
                          pushRTMPAddress:(NSString *)rtmpAddr;
@end
