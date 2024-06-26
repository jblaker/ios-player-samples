//
//  BCOVVideoPlayer.m
//  FlutterPlayer
//
//  Copyright © 2024 Brightcove, Inc. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <BrightcovePlayerSDK/BrightcovePlayerSDK.h>

#import "AppDelegate.h"

#import "BCOVVideoPlayer.h"


// Customize these values with your own account information
// Add your Brightcove account and video information here.
static NSString * const kAccountId = @"5434391461001";
static NSString * const kPolicyKey = @"BCpkADawqM0T8lW3nMChuAbrcunBBHmh4YkNl5e6ZrKQwPiK_Y83RAOF4DP5tyBF_ONBVgrEjqW6fbV0nKRuHvjRU3E8jdT9WMTOXfJODoPML6NUDCYTwTHxtNlr5YdyGYaCPLhMUZ3Xu61L";
static NSString * const kVideoId = @"6140448705001";


@interface BCOVVideoPlayer () <BCOVPlaybackControllerDelegate>

@property (nonatomic, strong) AVPlayerViewController *avpvc;
@property (nonatomic, strong) BCOVPlaybackService *playbackService;
@property (nonatomic, strong) id<BCOVPlaybackController> playbackController;

@property (nonatomic, strong) FlutterMethodChannel *methodChannel;
@property (nonatomic, strong) FlutterEventChannel *eventChannel;
@property (nonatomic, strong) FlutterEventSink eventSink;

@end


@implementation BCOVVideoPlayer

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
{
    if (self = [super init])
    {
        self.playbackService = ({
            BCOVPlaybackServiceRequestFactory *factory = [[BCOVPlaybackServiceRequestFactory alloc]
                                                          initWithAccountId:kAccountId
                                                          policyKey:kPolicyKey];

            [[BCOVPlaybackService alloc] initWithRequestFactory:factory];
        });

        self.playbackController = ({
            BCOVPlayerSDKManager *sdkManager = BCOVPlayerSDKManager.sharedManager;

            BCOVFPSBrightcoveAuthProxy *authProxy = [[BCOVFPSBrightcoveAuthProxy alloc] initWithPublisherId:nil
                                                                                              applicationId:nil];

            id<BCOVPlaybackSessionProvider> fps = [sdkManager createFairPlaySessionProviderWithAuthorizationProxy:authProxy
                                                                                          upstreamSessionProvider:nil];

            id<BCOVPlaybackController> playbackController = [sdkManager
                                                             createPlaybackControllerWithSessionProvider:fps
                                                             viewStrategy:nil];
            playbackController.delegate = self;
            playbackController.autoAdvance = YES;
            playbackController.autoPlay = YES;

            playbackController;
        });

        self.avpvc = ({
            AVPlayerViewController *avpvc = [AVPlayerViewController new];
            avpvc.showsPlaybackControls = NO;
            avpvc;
        });

        // register for Flutter method channel
        self.methodChannel = ({
            FlutterEngine *flutterEngine = ((AppDelegate *)UIApplication.sharedApplication.delegate).flutterEngine;
            FlutterMethodChannel *methodChannel = [FlutterMethodChannel
                                                   methodChannelWithName:@"bcov.flutter/method_channel"
                                                   binaryMessenger:flutterEngine.binaryMessenger];
            __weak typeof(self) weakSelf = self;
            [methodChannel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call,
                                                  FlutterResult _Nonnull result) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [strongSelf handleMethodCall:call result:result];
            }];
            methodChannel;
        });

        // register for Flutter event channel
        self.eventChannel = ({
            FlutterEngine *flutterEngine = ((AppDelegate *)UIApplication.sharedApplication.delegate).flutterEngine;
            FlutterEventChannel *eventChannel = [FlutterEventChannel
                                                 eventChannelWithName:@"bcov.flutter/event_channel"
                                                 binaryMessenger:flutterEngine.binaryMessenger
                                                 codec:FlutterJSONMethodCodec.sharedInstance];
            [eventChannel setStreamHandler:self];
            eventChannel;
        });

        [self requestContentFromPlaybackService];
    }

    return self;
}

- (void)requestContentFromPlaybackService
{
    __weak typeof(self) weakSelf = self;

    NSDictionary *configuration = @{ kBCOVPlaybackServiceConfigurationKeyAssetID: kVideoId };
    [self.playbackService findVideoWithConfiguration:configuration
                                     queryParameters:nil
                                          completion:^(BCOVVideo *video,
                                                       NSDictionary *jsonResponse,
                                                       NSError *error) {

        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (video)
        {
#if TARGET_OS_SIMULATOR
            if (video.usesFairPlay)
            {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FairPlay Warning"
                                                                               message:@"FairPlay only works on actual iOS or tvOS devices.\n\nYou will not be able to view any FairPlay content in the iOS or tvOS simulator."
                                                                        preferredStyle:UIAlertControllerStyleAlert];

                [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                          style:UIAlertActionStyleDefault
                                                        handler:nil]];

                dispatch_async(dispatch_get_main_queue(), ^{
                    UIViewController *rootViewController = UIApplication.sharedApplication.delegate.window.rootViewController;
                    [rootViewController presentViewController:alert animated:YES completion:nil];
                });

                return;
            }
#endif

            [strongSelf.playbackController setVideos:@[ video ]];
        }
        else
        {
            NSLog(@"ViewController - Error retrieving video: %@", error.localizedDescription);
        }

    }];
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result
{
    if ([@"playPause" isEqualToString:call.method])
    {
        NSNumber *isPlaying = call.arguments;
        if (isPlaying.boolValue)
        {
            [self.playbackController pause];
        }
        else
        {
            [self.playbackController play];
        }
    }
    else if ([@"seek" isEqualToString:call.method])
    {
        NSNumber *seconds = call.arguments;
        CMTime seekTo = CMTimeMakeWithSeconds(seconds.intValue, 600);
        [self.playbackController seekToTime:seekTo completionHandler:nil];
    }
    else
    {
        result(FlutterMethodNotImplemented);
    }
}


#pragma mark - BCOVPlaybackControllerDelegate

- (void)playbackController:(id<BCOVPlaybackController>)controller
didAdvanceToPlaybackSession:(id<BCOVPlaybackSession>)session
{
    NSLog(@"ViewController - Advanced to new session.");

    self.avpvc.player = session.player;

    NSNumber *duration = session.video.properties[kBCOVVideoPropertyKeyDuration];
    self.eventSink(@{ @"name": @"didAdvanceToPlaybackSession",
                      @"duration": duration,
                      @"isAutoPlay": @(controller.isAutoPlay) });
}

- (void)playbackController:(id<BCOVPlaybackController>)controller
           playbackSession:(id<BCOVPlaybackSession>)session
  didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent
{
    if ([kBCOVPlaybackSessionLifecycleEventFail isEqualToString:lifecycleEvent.eventType])
    {
        NSError *error = lifecycleEvent.properties[@"error"];
        // Report any errors that may have occurred with playback.
        NSLog(@"ViewController - Playback error: %@", error.localizedDescription);
    }

    if ([kBCOVPlaybackSessionLifecycleEventEnd isEqualToString:lifecycleEvent.eventType])
    {
        self.eventSink(@{ @"name": @"eventEnd" });
    }
}

- (void)playbackController:(id<BCOVPlaybackController>)controller
           playbackSession:(id<BCOVPlaybackSession>)session
             didProgressTo:(NSTimeInterval)progress
{
    if (!isinf(progress))
    {
        self.eventSink(@{ @"name": @"didProgressTo",
                          @"progress": @(progress) });
    }
}


#pragma mark - FlutterPlatformView

- (nonnull UIView *)view
{
    return self.avpvc.view;
}


#pragma mark - FlutterStreamHandler

- (FlutterError *)onListenWithArguments:(id)arguments
                              eventSink:(FlutterEventSink)events
{
    self.eventSink = events;
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments
{
    self.eventSink = nil;
    return nil;
}

@end
