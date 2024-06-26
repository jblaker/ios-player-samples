//
//  VideoPropertiesViewController.m
//  BasicDAIPlayer
//
//  Copyright © 2024 Brightcove, Inc. All rights reserved.
//

#import "VideoPropertiesViewController.h"


@implementation VideoPropertiesViewController

- (void)setupPlaybackController
{
    BCOVPlayerSDKManager *sdkManager = BCOVPlayerSDKManager.sharedManager;

    IMASettings *imaSettings = [IMASettings new];
    imaSettings.language = NSLocale.currentLocale.localeIdentifier;
    IMAAdsRenderingSettings *adsRenderingSettings = [IMAAdsRenderingSettings new];
    adsRenderingSettings.linkOpenerDelegate = self;
    adsRenderingSettings.linkOpenerPresentingController = self;

    BCOVDAIAdsRequestPolicy *adsRequestPolicy = [BCOVDAIAdsRequestPolicy videoPropertiesAdsRequestPolicy];

    // BCOVDAIPlaybackSessionDelegate defines -willCallIMAAdsLoaderRequestAdsWithRequest:
    // which allows us to modify the IMAStreamRequest object before it is used to load ads.
    NSDictionary *daiPlaybackSessionOptions = @{ kBCOVDAIOptionDAIPlaybackSessionDelegateKey: self };

    id<BCOVPlaybackSessionProvider> daiSessionProvider = [sdkManager createDAISessionProviderWithSettings:imaSettings
                                                                                     adsRenderingSettings:adsRenderingSettings
                                                                                         adsRequestPolicy:adsRequestPolicy
                                                                                              adContainer:self.playerView.contentOverlayView
                                                                                           viewController:self
                                                                                           companionSlots:nil
                                                                                  upstreamSessionProvider:self.fps
                                                                                                  options:daiPlaybackSessionOptions];

    id<BCOVPlaybackController> playbackController = [sdkManager createPlaybackControllerWithSessionProvider:daiSessionProvider
                                                                                               viewStrategy:nil];
    playbackController.delegate = self;
    playbackController.autoPlay = YES;
    playbackController.autoAdvance = YES;

    self.playerView.playbackController = playbackController;

    self.playbackController = playbackController;
}

- (BCOVVideo *)updateVideo:(BCOVVideo *)video
{
    BCOVVideo *updatedVideo = [video update:^(id<BCOVMutableVideo>  _Nonnull mutableVideo) {

        NSDictionary *adProperties = @{
            kBCOVDAIVideoPropertiesKeySourceId: kGoogleDAISourceId,
            kBCOVDAIVideoPropertiesKeyVideoId: kGoogleDAIVideoId
        };

        NSMutableDictionary *propertiesToUpdate = mutableVideo.properties.mutableCopy;
        [propertiesToUpdate addEntriesFromDictionary:adProperties];
        mutableVideo.properties = propertiesToUpdate;
    }];

    return updatedVideo;
}

@end
