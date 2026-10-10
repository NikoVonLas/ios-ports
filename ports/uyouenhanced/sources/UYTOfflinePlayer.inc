@interface UYTOfflinePlayer : AVPlayerViewController
@property(nonatomic,strong) id sponsorObserver;
@property(nonatomic,copy) NSArray *sponsorSegments;
@property(nonatomic,copy) NSString *sponsorVideoID;
@property(nonatomic) BOOL sponsorSeekPending;
- (void)configureSponsorForVideo:(NSString *)videoID;
@end
@implementation UYTOfflinePlayer
- (void)configureSponsorForVideo:(NSString *)videoID {
    self.sponsorVideoID=videoID;
    __weak UYTOfflinePlayer *weakSelf=self;
    UYTFetchSponsorSegments(videoID, ^(NSArray *segments){ if ([weakSelf.sponsorVideoID isEqual:videoID]) weakSelf.sponsorSegments=segments; });
    self.sponsorObserver=[self.player addPeriodicTimeObserverForInterval:CMTimeMake(1,4) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        UYTOfflinePlayer *controller=weakSelf;
        if (!controller || !UYTSponsorEnabled() || controller.player.rate<=0 || controller.sponsorSeekPending) return;
        double end=UYTSponsorSkipEnd(controller.sponsorSegments,CMTimeGetSeconds(time),CMTimeGetSeconds(controller.player.currentItem.duration));
        if (end>=0) {
            controller.sponsorSeekPending=YES;
            [controller.player seekToTime:CMTimeMakeWithSeconds(end,600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished){ dispatch_async(dispatch_get_main_queue(), ^{ weakSelf.sponsorSeekPending=NO; }); }];
        }
    }];
}
- (void)dealloc { if (self.sponsorObserver) [self.player removeTimeObserver:self.sponsorObserver]; }
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; [self.player pause]; }
@end
