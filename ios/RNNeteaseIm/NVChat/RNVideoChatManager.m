//
//  RNVideoChatManager.m
//  RNNimAvchat
//
//  Created by zpd106.
//  Copyright © 2018. All rights reserved.
//

#import "RNVideoChatManager.h"
//#import "RNVideoChatView.h"
#import "NIMModel.h"
#import "VideoChatView.h"


@interface RNVideoChatManager ()<NIMSystemNotificationManagerDelegate,NIMNetCallManagerDelegate>

//@property (nonatomic) RNVideoChatView  *vcv;

@end


@implementation RNVideoChatManager

RCT_EXPORT_MODULE()

RCT_EXPORT_VIEW_PROPERTY(width, NSInteger);
RCT_EXPORT_VIEW_PROPERTY(height, NSInteger);

@synthesize bridge = _bridge;

- (UIView *)view
{
//    _vcv = [[RNVideoChatView alloc] initWithFrame: CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    return nil;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [[NIMSDK sharedSDK].systemNotificationManager removeDelegate:self];
}

- (instancetype)init{
    if (self = [super init]) {
        [[NIMSDK sharedSDK].systemNotificationManager addDelegate:self];
        [[NIMAVChatSDK sharedSDK].netCallManager addDelegate:self];
    }
//    VideoChatView *controller = [[VideoChatView alloc] init];
//    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
//    [keyWindow addSubview:controller];
    //_vcv = [[RNVideoChatView alloc] initWithFrame: CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    [self setSendState];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeVideoChatViewNotification:) name:@"VideoChatViewNotification" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(clickObserveNotification:) name:@"ObservePushNotification" object:nil];
    
    return self;
}

#pragma mark -NIMNetCallManagerDelegate
-(void)onReceive:(UInt64)callID from:(NSString *)caller type:(NIMNetCallMediaType)type message:(NSString *)extendMessage{
    NSLog(@"onReceive:%@", caller);
    if ([NIMAVChatSDK sharedSDK].netCallManager.currentCallID > 0)
    {
        [[NIMAVChatSDK sharedSDK].netCallManager control:callID type:NIMNetCallControlTypeBusyLine];
        return;
    };
    VideoChatView *chatView = [[VideoChatView alloc] init];
    chatView.callInfo.callID = callID;
    chatView.callInfo.caller = caller;
    UIWindow *keyWindow = [[[UIApplication sharedApplication] windows] lastObject ];
    [keyWindow addSubview:chatView];
    [chatView playSenderRing];
}
// dict字典转json字符串
- (NSString *)jsonStringWithDictionary:(NSDictionary *)dict
{
    if (dict && 0 != dict.count)
    {
        NSError *error = nil;
        // NSJSONWritingOptions 是"NSJSONWritingPrettyPrinted"的话有换位符\n；是"0"的话没有换位符\n。
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return jsonString;
    }
    
    return nil;
}

- (void)observeVideoChatViewNotification:(NSNotification*)noti{
    NSDictionary *dic = noti.object;
    if ([dic[@"type"] isEqualToString:Resize]) {
        [_bridge.eventDispatcher sendDeviceEventWithName:@"onVideoResize" body:nil];
    }else if ([dic[@"type"] isEqualToString:Start]){
        [_bridge.eventDispatcher sendDeviceEventWithName:@"onVideoStart" body:nil];
    }else if ([dic[@"type"] isEqualToString:End]){
        [_bridge.eventDispatcher sendDeviceEventWithName:@"onVideoEnd" body:nil];
    }
    else{
        
    }
}

- (void)clickObserveNotification:(NSNotification *)noti{
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    NSDictionary *dict = noti.object;
    NSMutableDictionary *notiDict = [NSMutableDictionary dictionaryWithDictionary:[dict objectForKey:@"dict"]];
    NSString *strDict = [notiDict objectForKey:@"data"];
    if(strDict){
        NSDictionary *dataDict = [self dictChangeFromJson:strDict];
        [notiDict setObject: dataDict forKey:@"data"];
    }
    if (notiDict){
        NSInteger notiType = [[notiDict objectForKey:@"type"] integerValue];
        // 视频通话
        if(notiType == 21) {
            if ([[dict objectForKey:@"type"] isEqualToString:@"background"]) {
                // 后台台视频通话 通知js
                NIMModel *model = [NIMModel initShareMD];
                NSDictionary *dd = [self doNotiDict:notiDict];
                model.videoReceive = dd;
            }
        }
    }
    if ([notiDict[@"nim"] isEqualToString:@"1"] && !notiDict[@"type"]) {
        if ([[dict objectForKey:@"type"] isEqualToString:@"launch"]) {
            [_bridge.eventDispatcher sendDeviceEventWithName:@"observeLaunchPushEvent" body:nil];
        }else{
            [_bridge.eventDispatcher sendDeviceEventWithName:@"observeBackgroundPushEvent" body:nil];
        }
    }
}

#pragma mark - NIMSystemNotificationManagerDelegate
- (void)onReceiveCustomSystemNotification:(NIMCustomSystemNotification *)notification{//接收自定义通知
    NSDictionary *notiDict = [self dictChangeFromJson:notification.content];
    if (notiDict){
        NSInteger notiType = [[notiDict objectForKey:@"type"] integerValue];
        // 视频通话
        if(notiType == 21) {
            UIApplicationState state = [UIApplication sharedApplication].applicationState;
            if(state == UIApplicationStateActive){
                // 前台视频通话 通知js
                NIMModel *model = [NIMModel initShareMD];
                NSDictionary *dd = [self doNotiDict:notiDict];
                model.videoReceive = dd;
            }
        }
    }
}

// 处理通知js数据
- (NSDictionary *)doNotiDict:(NSDictionary *)notiDict{
    NSMutableDictionary *param = [NSMutableDictionary dictionaryWithDictionary:notiDict];
    NSMutableDictionary *mutaDict = [NSMutableDictionary dictionaryWithDictionary:[notiDict objectForKey:@"data"]];
    if (mutaDict) {
        NSDictionary *dicDict = [mutaDict objectForKey:@"dict"];
        NSString *strType = [mutaDict objectForKey:@"sessionType"];
        NSString *strSessionId = [mutaDict objectForKey:@"sessionId"];
        NSString *strSessionName = @"";
        if ([strType isEqualToString:@"0"]) {//点对点
            NIMUser *user = [[NIMSDK sharedSDK].userManager userInfo:strSessionId];
            if ([user.alias length]) {
                strSessionName = user.alias;
            }else{
                NIMUserInfo *userInfo = user.userInfo;
                strSessionName = userInfo.nickName;
            }
        }else{//群主
            NIMTeam *team = [[[NIMSDK sharedSDK] teamManager]teamById:strSessionId];
            strSessionName = team.teamName;
        }
        if (!strSessionName) {
            strSessionName = @"";
        }
        [mutaDict setValue:strSessionName forKey:@"sessionName"];
        [param setValue:mutaDict forKey:@"sessionBody"];
    
        NSDictionary *dd = @{@"status": @YES, @"callid": [dicDict objectForKey:@"callid"], @"from": [dicDict objectForKey:@"caller"],   @"body": param};
        return dd;
    } else {
        return nil;
    }
}

// json字符串转dict字典
- (NSDictionary *)dictChangeFromJson:(NSString *)strJson{
    NSData* data = [strJson dataUsingEncoding:NSUTF8StringEncoding];
    __autoreleasing NSError* error = nil;
    id result = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (error != nil) return nil;
    return result;
}

//手动登录
RCT_EXPORT_METHOD(login:(nonnull NSString *)account token:(nonnull NSString *)token
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject){
    [[NIMSDK sharedSDK].loginManager login:account token:token completion:^(NSError *error) {
        if (!error) {
            resolve(account);
        }else{
            NSString *strEorr = @"登录失败";
            reject(@"-1",strEorr, nil);
        }
    }];
}

//注销用户
RCT_EXPORT_METHOD(logout){
    [[[NIMSDK sharedSDK] loginManager] logout:^(NSError *error){}];
}

//拨号
RCT_EXPORT_METHOD(call:(nonnull  NSString *)callee){
    //[_vcv call:callee];
}

//接听/拒绝
RCT_EXPORT_METHOD(accept:(BOOL )type callid:(NSString *)callID from:(NSString *)caller){
    //[_vcv accept:type callid:callID from:caller];
}

//关闭
RCT_EXPORT_METHOD(hangup){
    //[_vcv hangup];
    [[NSNotificationCenter defaultCenter] postNotificationName:VideoChatHangup object:nil];
}


-(void)setSendState{
    NIMModel *mod = [NIMModel initShareMD];
    mod.avChatBlock = ^(NSInteger index, id param) {
        switch (index) {
            case 21:
                //拨打通知
                [_bridge.eventDispatcher sendDeviceEventWithName:@"onVideoCall" body:param];
                break;
            case 22:
                //来电通知
                [_bridge.eventDispatcher sendDeviceEventWithName:@"onVideoReceive" body:param];
                break;
            case 23:
                //接听通知
                [_bridge.eventDispatcher sendDeviceEventWithName:@"onVideoAccept" body:param];
                break;
            case 24:
                //挂断通知
                [_bridge.eventDispatcher sendDeviceEventWithName:@"onVideoHangup" body:param];
                break;
            default:
                break;
        }
        
    };
}

@end

