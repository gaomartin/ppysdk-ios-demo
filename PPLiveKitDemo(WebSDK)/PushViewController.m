//
//  PushViewController.m
//  PPLiveKitDemo(WebSDK)
//
//  Created by Jimmy on 16/8/25.
//  Copyright © 2016年 高国栋. All rights reserved.
//
#import <PPYLiveKit/PPYLiveKit.h>
#import "PushViewController.h"
#import "HTTPManager.h"
#import "NotifyView.h"


typedef NS_ENUM(int, NetWorkState){
    NetWorkState_notReachable,
    NetWorkState_WWan,
    NetWorkState_Wifi,
};
@interface PushViewController () <PPYPushEngineDelegate>

@property (strong, nonatomic) PPYAudioConfiguration *audioConfig;
@property (strong, nonatomic) PPYVideoConfiguration *videoConfig;

@property (weak, nonatomic) IBOutlet UIButton *btnCamera;
@property (weak, nonatomic) IBOutlet UIButton *btnTorch;
@property (weak, nonatomic) IBOutlet UIButton *btnFocus;
@property (weak, nonatomic) IBOutlet UIButton *btnMirror;

@property (weak, nonatomic) IBOutlet UILabel *lblRoomID;
@property (weak, nonatomic) IBOutlet UIButton *btnMute;
@property (weak, nonatomic) IBOutlet UILabel *lblFPS;
@property (weak, nonatomic) IBOutlet UILabel *lblBitrate;
@property (weak, nonatomic) IBOutlet UILabel *lblResolution;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *contraitBtnCameraTraingToBtnMute;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *contraitBtnMirrorLeadingToBtnMute;

@property (weak, nonatomic) IBOutlet UIButton *btnData;

@property (assign, nonatomic) BOOL isPushing;
@property (assign, nonatomic) BOOL needReConnect;
@property (assign, nonatomic) BOOL isDoingReconnect;
@property (assign, nonatomic) int reconnectCount;
@property (assign, nonatomic) BOOL isNetworkDisconnect;
@property (assign, nonatomic) BOOL isDoExitByClick;

#pragma mark --UIElement--
@property (weak, nonatomic) IBOutlet UIButton *btnBeautySetting;
@property (weak, nonatomic) IBOutlet UIButton *btnMoreSetting;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *ConstraitYVerticalMoreView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *ConstraitYVerticalBeautyView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *ConstraintBtnBeautyBottomVertical;
@property (weak, nonatomic) IBOutlet UISwitch *switchBeauty;

@property (assign, nonatomic) BOOL isBeautyViewPresented;
@property (assign, nonatomic) BOOL isMoreViewPresented;
@property (assign, nonatomic) BOOL isDataShowed;

@end

@implementation PushViewController


#pragma mark --Life Cycle--
- (void)viewDidLoad {
    [super viewDidLoad];
    [self initData];
    [self InitUI];
}

-(void)viewWillAppear:(BOOL)animated{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showNetworkState:) name:kNotification_NetworkStateChanged object:nil];
    
    NSString *roomID = [HTTPManager shareInstance].roomID;
    self.lblRoomID.text = [NSString stringWithFormat:@"     房间号: %@   ", roomID];
    
    self.audioConfig = [PPYAudioConfiguration audioConfigurationWithAudioQuality:PPYAudioQuality_Default];
    PPYCaptureSessionPreset preset = [self configurationWithWidth:self.width andHeight:self.height];
    self.videoConfig = [PPYVideoConfiguration videoConfigurationWithPreset:preset andFPS:25 andBirate:800];
    self.pushEngine = [[PPYPushEngine alloc]initWithAudioConfiguration:self.audioConfig andVideoConfiguration:self.videoConfig pushRTMPAddress:self.rtmpAddress];
    self.pushEngine.preview = self.view;
    self.pushEngine.running = YES;
    self.pushEngine.delegate = self;
    [self updateUI];
    
    [self startDoLive];
}

-(void)viewWillDisappear:(BOOL)animated{
    [self.indicator stopAnimating];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotification_NetworkStateChanged object:nil];
}


#pragma mark --custom method--

-(void)initData{
    self.isDataShowed = YES;
}

-(void)InitUI{
    self.lblRoomID.textColor = [UIColor whiteColor];
    self.lblRoomID.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
    self.lblRoomID.layer.cornerRadius = 10;
    self.lblRoomID.layer.masksToBounds  = YES;
    [self.lblRoomID clipsToBounds];
    
    self.lblBitrate.textColor = [UIColor whiteColor];
    self.lblBitrate.layer.cornerRadius = 6;
    self.lblBitrate.layer.masksToBounds = YES;
    [self.lblBitrate clipsToBounds];
    
    self.lblFPS.textColor = [UIColor whiteColor];
    self.lblFPS.layer.cornerRadius = 6;
    self.lblFPS.layer.masksToBounds = YES;
    [self.lblFPS clipsToBounds];
    
    self.lblResolution.textColor = [UIColor whiteColor];
    self.lblResolution.text = [NSString stringWithFormat:@"分辨率：%dx%d",self.width,self.height];
    
    self.contraitBtnCameraTraingToBtnMute.constant = (self.btnMute.center.x -self.btnTorch.center.x)/2 - self.btnMute.frame.size.width;
    NSLog(@"self.contraitBtnCameraTraingToBtnMute.constant = %f",self.contraitBtnCameraTraingToBtnMute.constant );
    [self.btnCamera layoutIfNeeded];
    self.contraitBtnMirrorLeadingToBtnMute.constant = (self.btnData.center.x - self.btnMute.center.x)/2 - self.btnMute.frame.size.width;
    [self.btnMirror layoutIfNeeded];
}

-(void)updateUI{
    
    BOOL canSwitchCamera = ([AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1);
    self.btnCamera.userInteractionEnabled = canSwitchCamera;
    self.btnTorch.userInteractionEnabled = self.pushEngine.hasTorch;
    if(self.pushEngine.hasTorch){
        NSLog(@"self.isTorch = %d",self.pushEngine.isTorch);
        [self.btnTorch setBackgroundImage:[UIImage imageNamed:(self.pushEngine.isTorch ? @"闪光灯-启用" : @"闪光灯-禁用")] forState:UIControlStateNormal];
    }
    NSLog(@"self.mute = %d",self.pushEngine.isMute);
    [self.btnMute setBackgroundImage:[UIImage imageNamed:(self.pushEngine.isMute ? @"麦克风-禁用" : @"麦克风-启用")] forState:UIControlStateNormal];
    
    [self.btnData setBackgroundImage:[UIImage imageNamed:(self.isDataShowed ? @"数据分析-启用" : @"数据分析-禁用")] forState:UIControlStateNormal];
    NSLog(@"self.beauty = %d",self.pushEngine.isBeautify);
    
    NSLog(@"self.mirror = %d",self.pushEngine.isMirror);
}

-(void)startDoLive{
    if([HTTPManager shareInstance].currentNetworkStatus == AFNetworkReachabilityStatusReachableViaWWAN){
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"当前使用移动流量，是否继续直播？" message:nil preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *btnOK = [UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self doLive];
        }];
        UIAlertAction *btnCancel = [UIAlertAction actionWithTitle:@"退出" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self.delegate didPushViewControllerDismiss];
        }];
        [alert addAction:btnOK];
        [alert addAction:btnCancel];
        [self presentViewController:alert animated:YES completion:nil];
    }else{
        [self doLive];
    }
}

- (void)doLive{
    if(self.rtmpAddress == nil) return;
    NSLog(@"self.rtmpAddress = %@",self.rtmpAddress);
    
    [self.pushEngine start];
    
    if(![self.indicator isAnimating]){
        [self.indicator startAnimating];
    }
}

-(PPYCaptureSessionPreset)configurationWithWidth:(int)width andHeight:(int)height{
    if(width == 480 && height == 640)
        return PPYCaptureSessionPreset360x640;
    else if(width == 540 && height == 960)
        return PPYCaptureSessionPreset540x960;
    else if(width == 720 && height == 1280)
        return PPYCaptureSessionPreset720x1280;
    else{
        NSLog(@"can't find match preset, set 540 * 960 instead");
        return PPYCaptureSessionPreset540x960;
    }
}


-(void)showNetworkState:(NSNotification *)info{
    NSNumber *value = (NSNumber *)info.object;
    NSString *tip = nil;
    switch (value.integerValue) {
        case AFNetworkReachabilityStatusUnknown:
            [self throwError:50 info:@"网络断开,请检查网络"];
            break;
        case AFNetworkReachabilityStatusNotReachable:
            self.isNetworkDisconnect = YES;
            [self throwError:50 info:@"当前无网络连接"];
            break;
        case AFNetworkReachabilityStatusReachableViaWWAN:
        {
            self.isNetworkDisconnect = NO;
            tip = @"当前使用3G/4G网络";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"当前使用移动流量，是否继续直播？" message:nil preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *btnOK = [UIAlertAction actionWithTitle:@"继续直播" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                self.needReConnect = YES;
                [[NotifyView getInstance] dismissNotifyMessageInView:self.view];
                [[NotifyView getInstance] needShowNotifyMessage:tip inView:self.view forSeconds:3];
                [self doReconnectToServer];
            }];
            UIAlertAction *btnCancel = [UIAlertAction actionWithTitle:@"退出直播" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self.indicator stopAnimating];
                [self.delegate didPushViewControllerDismiss];
            }];
            [alert addAction:btnOK];
            [alert addAction:btnCancel];
            [self presentViewController:alert animated:YES completion:nil];
        }
            break;
        case AFNetworkReachabilityStatusReachableViaWiFi:
//            tip = @"当前使用Wi-Fi";
            self.isNetworkDisconnect = YES;
            self.needReConnect = YES;
            [[NotifyView getInstance] dismissNotifyMessageInView:self.view];
            [[NotifyView getInstance] needShowNotifyMessage:tip inView:self.view forSeconds:3];
            [[NotifyView getInstance] needShwoNotifyMessage:@"正在重连..." inView:self.view];
            [self doReconnectToServer];
            break;
    }
}

-(void)doReconnectToServer{
    __weak typeof (self) weakSelf = self;
    [[HTTPManager shareInstance] fetchStreamStatusSuccess:^(NSDictionary *dic) {
        if(dic != nil){
            if([[dic objectForKey:@"err"] isEqualToString:@"0"]){
                NSDictionary *data = (NSDictionary *)[dic objectForKey:@"data"];
                NSString *liveState = (NSString *)[data objectForKey:@"liveStatus"];
//                NSString *streamState = (NSString *)[data objectForKey:@"streamStatus"];
                
                if([liveState isEqualToString:@"living"] ||[liveState isEqualToString:@"broken"]){
                    [weakSelf.pushEngine start];
                    weakSelf.isDoingReconnect = YES;
                }else{
                    [weakSelf throwError:12 info:@"直播已结束"];
                }
            }else{
               [weakSelf throwError:12 info:@"直播已结束"];
            }
        }
    } failured:^(NSError *err) {
        if(err){
            [weakSelf throwError:0 info:@"网络连接断开，不可用"];
        }
    }];
}
-(void)reDoSyncStartStateToServer{
     __weak typeof(self) weakSelf = self;
     dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[HTTPManager shareInstance] syncPushStartStateToServerSuccess:^(NSDictionary *dic) {
            [weakSelf.indicator stopAnimating];
            if(dic != nil){
                if([[dic objectForKey:@"err"] isEqualToString:@"0"]){
                    [[NotifyView getInstance] needShowNotifyMessage:@"推流成功" inView:self.view forSeconds:3];
                }else{
                    NSString *errorInfo = (NSString *)[dic objectForKey:@"msg"];
                    NSString *errCode = (NSString *)[dic objectForKey:@"err"];
                    [weakSelf throwError:3 info:[NSString stringWithFormat:@"%@:%@",errCode,errorInfo]];
                }
            }
        } failured:^(NSError *err) {
            [weakSelf.indicator stopAnimating];
        }];
    });
}
-(void)stopSyncStateToService{
    __weak typeof(self) weakSelf = self;
    [[HTTPManager shareInstance] syncPushStopStateToServerSuccess:^(NSDictionary *dic) {
        if(dic != nil){
            if([[dic objectForKey:@"err"] isEqualToString:@"0"]){
//                [[NotifyView getInstance] needShowNotifyMessage:@"断流成功" inView:weakSelf.view forSeconds:3];
            }else{
                //                            NSString *errorInfo = (NSString *)[dic objectForKey:@"msg"];
                //                            NSString *errCode = (NSString *)[dic objectForKey:@"err"];
//                [[NotifyView getInstance] needShowNotifyMessage:@"同步断流失败" inView:weakSelf.view forSeconds:3];
            }
        }
        [self.delegate didPushViewControllerDismiss];
        
    } failured:^(NSError *err) {
//        [[NotifyView getInstance] needShowNotifyMessage:@"同步断流失败" inView:weakSelf.view forSeconds:3];
        [weakSelf.delegate didPushViewControllerDismiss];
    }];

}

-(void)throwError:(int)errorCode info:(NSString *)errorInfo{
    __weak typeof(self) weakSelf = self;

    if(errorCode == 3){  //sync start errorcode
        NSArray *componets = [errorInfo componentsSeparatedByString:@":"];
        NSLog(@"componets = %@",componets);
        if([componets[0] isEqualToString:@"1006"]){
            [weakSelf reDoSyncStartStateToServer];
        }
    }
    if(errorCode == 0){ //AFNetworking errorcode
        [[NotifyView getInstance] needShowNotifyMessage:@"网络连接断开，不可用" inView:self.view forSeconds:3];
    }
    
    if(errorCode == 12){
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:errorInfo message:nil preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *btnOK = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSLog(@"stop thread = %@",[NSThread currentThread]);
            [weakSelf.indicator stopAnimating];
            [weakSelf.delegate didPushViewControllerDismiss];
        }];
        
        [alert addAction:btnOK];
        [weakSelf presentViewController:alert animated:YES completion:nil];
    }
    [[NotifyView getInstance] dismissNotifyMessageInView:weakSelf.view];
    
    if(errorCode == 50){     //AFNetworking net status not reacheable;
        
        [[NotifyView getInstance] needShwoNotifyMessage:errorInfo inView:weakSelf.view];
        [weakSelf.pushEngine stop];
    }
    
   
}

#pragma mark --<PPYPushEngineDelegate>
-(void)didStreamStateChanged:(PPYPushEngineStreamStatus)status{
    switch (status) {
        case PPYConnectionState_Connecting:
            
            break;
        case PPYConnectionState_Connected:
            
            break;
        case PPYConnectionStatus_Started:
            if(!self.needReConnect){
                [[HTTPManager shareInstance] syncPushStartStateToServerSuccess:^(NSDictionary *dic) {
                    if(dic != nil){
                        if([[dic objectForKey:@"err"] isEqualToString:@"0"]){
                            [self.indicator stopAnimating];
                           [[NotifyView getInstance] needShowNotifyMessage:@"推流成功" inView:self.view forSeconds:3];
                        }else{
                            NSString *errorInfo = (NSString *)[dic objectForKey:@"msg"];
                            NSString *errCode = (NSString *)[dic objectForKey:@"err"];
                            [self throwError:3 info:[NSString stringWithFormat:@"%@:%@",errCode,errorInfo]];
                        }
                    }
                } failured:^(NSError *err) {
                    [self.indicator stopAnimating];
                    [self throwError:0 info:@"AFNetworking Error"];
                }];
            }
            if(self.isDoingReconnect){
                [self.indicator stopAnimating];
                [[NotifyView getInstance] dismissNotifyMessageInView:self.view];
                [[NotifyView getInstance] needShowNotifyMessage:@"重连成功" inView:self.view forSeconds:3];
                self.isDoingReconnect = NO;
                self.needReConnect = NO;
                self.reconnectCount = 0;
            }
            self.isPushing = YES;
            break;
        case PPYConnectionStatus_Ended:
            
            self.isPushing = NO;
            
            __weak __typeof(self) weakSelf = self;
            if(self.isDoExitByClick){
                self.isDoExitByClick = NO;
                [self stopSyncStateToService];
            }else{
                if(self.needReConnect){
                    
                    weakSelf.isDoingReconnect = YES;
                    weakSelf.needReConnect = NO;
                    
                    [weakSelf.indicator startAnimating];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [weakSelf.pushEngine start];
                    });
                    
                }else{
                    if([weakSelf.indicator isAnimating]){
                        [weakSelf.indicator stopAnimating];
                    }
                    if(weakSelf.isNetworkDisconnect == YES){
                        NSLog(@"network disconnect");
                    }else{
                        [self stopSyncStateToService];
                    }
                }
            }
            break;
    }
    NSLog(@"PPYPushEngineStreamStatus __%lu",(unsigned long)status);
}


-(void)didStreamErrorOccured:(PPYPushEngineErrorType)error{
    
    NSString *tip = nil;
    switch (error) {
        case PPYPushEngineError_Unknow:
//            tip = @"发生未知错误";
            break;
        case PPYPushEngineError_ConnectFailed:
            tip = @"当前网络环境异常，正在尝试重连...";
            self.needReConnect = YES;
            break;
        case PPYPushEngineError_TransferFailed:
            self.needReConnect = YES;
            tip = @"当前网络环境异常，正在尝试重连...";
            break;
        case PPYPushEngineError_FatalError:
//            tip = @"采集或编码失败";
            break;
            
    }
    if(self.needReConnect){
        self.reconnectCount ++;
        if(self.reconnectCount > 5){   //5times * 5s = 25s, 25s to reconnect;
            self.needReConnect = NO;
            self.reconnectCount = 0;
            [[NotifyView getInstance] needShowNotifyMessage:@"重连失败，请检查您的网络设置，网络恢复后将自动为您重连接..." inView:self.view forSeconds:3];
        }else{
            [self.indicator startAnimating];
        }
    }else{
        [[NotifyView getInstance] needShowNotifyMessage:tip inView:self.view forSeconds:3];
        [self.indicator stopAnimating];
    }
    
    NSLog(@"didStreamErrorOccured __%d",error);
    
}
-(void)didStreamInfoThrowOut:(PPYPushEngineStreamInfoType)type infoValue:(int)value{
    NSLog(@"current thread = %@",[NSThread currentThread]);
    switch (type) {
            
        case PPYPushEngineInfo_BufferingBytes:
//            [[NotifyView getInstance] needShowNotifyMessage:@"当前网络信号较差" inView:self.view forSeconds:3];
            break;
        case PPYPushEngineInfo_RealBirate:
            self.lblBitrate.text = [NSString stringWithFormat:@"码率：%dkbps",value];
            break;
        case PPYPushEngineInfo_RealFPS:
            self.lblFPS.text = [NSString stringWithFormat:@"帧率：%d帧/秒",value];
            break;
        case PPYPushEngineInfo_DowngradeBitrate:
            [[NotifyView getInstance] needShowNotifyMessage: @"当前网络环境差，正在为您切换码率..." inView:self.view forSeconds:3];
            break;
        case PPYPUshEngineInfo_UpgradeBitrate:
//            [[NotifyView getInstance] needShowNotifyMessage: @"当前网络环境较好，正在上调码率..." inView:self.view forSeconds:3];
            break;
    }
    NSLog(@"didStreamInfoThrowOut %d__%d",type,value);
}

#pragma mark --Actions--
- (IBAction)doExit:(id)sender {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确定要关闭直播吗？" message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *btnOK = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"stop thread = %@",[NSThread currentThread]);
        self.isDoExitByClick = YES;
        [self.indicator stopAnimating];
        if(self.isPushing){
            [self.pushEngine stop];
        }else{
            [self.delegate didPushViewControllerDismiss];
        }
    }];
    
    UIAlertAction *btnCancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:btnOK];
    [alert addAction:btnCancel];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)switchCamera:(id)sender {
    if(self.pushEngine.hasTorch){
        self.pushEngine.torch = NO;
    }
    if([AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1){
        AVCaptureDevicePosition current = self.pushEngine.cameraPosition;
        if(current == AVCaptureDevicePositionBack){
            self.pushEngine.cameraPosition = AVCaptureDevicePositionFront;
        }else if(current == AVCaptureDevicePositionFront){
            self.pushEngine.cameraPosition = AVCaptureDevicePositionBack;
        }
    }
    [self updateUI];
}

- (IBAction)doShowData:(id)sender {
    self.lblBitrate.hidden = !self.isDataShowed;
    self.lblFPS.hidden = !self.isDataShowed;
    self.lblResolution.hidden = !self.isDataShowed;
    [self updateUI];
    
    self.isDataShowed = !self.isDataShowed;
}

- (IBAction)doMirror:(id)sender {
    self.pushEngine.mirror = !self.pushEngine.mirror;
}
- (IBAction)doTorch:(id)sender {
    if(self.pushEngine.hasTorch){
        self.pushEngine.torch = !self.pushEngine.isTorch;
        [self updateUI];
    }
}
- (IBAction)doFocus:(id)sender {
    if(self.pushEngine.hasFocus){
        self.pushEngine.autoFocus = !self.pushEngine.isAutoFocus;
    }
}

- (IBAction)doMute:(id)sender {
    self.pushEngine.mute = !self.pushEngine.isMute;
    [self updateUI];
}

- (IBAction)doBeauty:(UISwitch *)sender {
    self.pushEngine.beautify = sender.isOn;
}
- (IBAction)beautifyLevel:(UISlider*)sender {
    self.pushEngine.beautyLevel = sender.value;
}
- (IBAction)brightnessLevel:(UISlider*)sender {
    self.pushEngine.brightLevel = sender.value;
}
- (IBAction)ToneLevel:(UISlider*)sender {
    self.pushEngine.toneLevel = sender.value;
}

- (IBAction)doBeautySetting:(id)sender {
    
    [UIView animateWithDuration:0.25 animations:^{
        CGFloat height = [UIScreen mainScreen].bounds.size.height;
        if(self.isBeautyViewPresented){
            self.ConstraitYVerticalBeautyView.constant = height;  //美颜设置界面隐藏；
            self.ConstraintBtnBeautyBottomVertical.constant = 8;
            
        }else{
            self.ConstraitYVerticalBeautyView.constant = height - 190; //美颜设置界面弹出；
            self.ConstraintBtnBeautyBottomVertical.constant = 190 + 8;
        }
        self.ConstraitYVerticalMoreView.constant = height;   //更多设置界面隐藏；
        self.isMoreViewPresented = NO;
        
        [self.view layoutIfNeeded];
        self.isBeautyViewPresented = !self.isBeautyViewPresented;
    }];
}
- (IBAction)doMoreSetting:(id)sender {
    
    [UIView animateWithDuration:0.25 animations:^{
        CGFloat height = [UIScreen mainScreen].bounds.size.height;
        if(self.isMoreViewPresented){
            self.ConstraitYVerticalMoreView.constant = height;   //更多设置界面隐藏；
            self.ConstraintBtnBeautyBottomVertical.constant = 8;
        }else{
            self.ConstraitYVerticalMoreView.constant = height - 74; //更多设置界面弹出；
            self.ConstraintBtnBeautyBottomVertical.constant = 74 + 8;
        }
        self.ConstraitYVerticalBeautyView.constant = height;  //美颜设置界面隐藏；
        self.isBeautyViewPresented = NO;
        
        [self.view layoutIfNeeded];
        self.isMoreViewPresented = !self.isMoreViewPresented;
    }];
}


#pragma mark --Override Method--
- (BOOL)prefersStatusBarHidde{
    [super prefersStatusBarHidden];
    return YES;
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [super touchesBegan:touches withEvent:event];
    
    [UIView animateWithDuration:0.25 animations:^{
        CGFloat height = [UIScreen mainScreen].bounds.size.height;
        if(self.isBeautyViewPresented){
            self.ConstraitYVerticalBeautyView.constant = height;  //美颜设置界面隐藏；
            self.ConstraintBtnBeautyBottomVertical.constant = 8;
            self.isBeautyViewPresented = NO;
            return;
        }else if(self.isMoreViewPresented){
            self.ConstraitYVerticalMoreView.constant = height;   //更多设置界面隐藏；
            self.ConstraintBtnBeautyBottomVertical.constant = 8;
            self.isMoreViewPresented = NO;
            return;
        }
    }];
    
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.view];
    [self.pushEngine doFocusOnPoint:location onView:self.view needDisplayLocation:YES];
}

@end
