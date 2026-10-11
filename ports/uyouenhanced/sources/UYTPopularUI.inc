#import "UYTPublicFeed.h"

@interface UYTPopularVC : UIViewController <UICollectionViewDataSource,UICollectionViewDelegateFlowLayout>
@property(nonatomic,strong) UICollectionView *grid;
@property(nonatomic,strong) NSArray<NSArray<NSDictionary *> *> *feeds;
@property(nonatomic,strong) NSArray<UIButton *> *filters;
@property(nonatomic,strong) NSArray<NSNumber *> *visibleSections;
@property(nonatomic,strong) NSURLSession *feedSession;
@property(nonatomic,strong) NSMutableSet *coverRequests;
@property(nonatomic,strong) NSCache *covers;
@property(nonatomic,strong) UIRefreshControl *refreshControl;
@property(nonatomic,strong) NSDate *updated;
@property(nonatomic) NSInteger selectedFilter;
@property(nonatomic) NSInteger pending;
@property(nonatomic) CGFloat lastWidth;
@end
static NSArray *UYTPopularTitles(void) { return @[@"Топ клипов",@"Топ композиций",@"Игры"]; }
static NSArray *UYTPopularURLs(void) {
    // Official YouTube Music Global Charts playlists, also linked by /feed/music.
    return @[@"https://www.youtube.com/playlist?list=PL4fGSI1pDJn5kI81J1fYWK5eZRl1zJ5kM&hl=ru",
             @"https://www.youtube.com/playlist?list=PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i&hl=ru",
             @"https://www.youtube.com/gaming?hl=ru"];
}
@implementation UYTPopularVC
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor=UYTLibraryBackground(); self.view.tintColor=UIColor.whiteColor;
    if (@available(iOS 13.0,*)) self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    self.feeds=@[@[],@[],@[]]; self.coverRequests=[NSMutableSet set]; self.covers=[NSCache new]; self.covers.countLimit=40; self.covers.totalCostLimit=24*1024*1024;
    NSURLSessionConfiguration *configuration=NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.HTTPShouldSetCookies=NO; configuration.HTTPCookieStorage=nil; configuration.URLCredentialStorage=nil;
    configuration.requestCachePolicy=NSURLRequestReloadIgnoringLocalCacheData;
    self.feedSession=[NSURLSession sessionWithConfiguration:configuration];
    NSMutableArray *buttons=[NSMutableArray array];
    for (NSString *title in @[@"Все",@"Клипы",@"Композиции",@"Игры"]) {
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; button.tag=buttons.count;
        [button setTitle:title forState:UIControlStateNormal]; button.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium]; button.layer.cornerRadius=8; button.contentEdgeInsets=UIEdgeInsetsMake(0,12,0,12);
        [button setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal]; [button addTarget:self action:@selector(selectFeed:) forControlEvents:UIControlEventTouchUpInside]; [buttons addObject:button];
    }
    self.filters=buttons;
    UIStackView *chips=[[UIStackView alloc] initWithArrangedSubviews:buttons]; chips.spacing=8; chips.translatesAutoresizingMaskIntoConstraints=NO;
    UIScrollView *scroll=[UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints=NO; scroll.showsHorizontalScrollIndicator=NO; [scroll addSubview:chips]; [self.view addSubview:scroll];
    UICollectionViewFlowLayout *layout=[UICollectionViewFlowLayout new]; layout.minimumInteritemSpacing=16; layout.minimumLineSpacing=20;
    self.grid=[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout]; self.grid.translatesAutoresizingMaskIntoConstraints=NO; self.grid.backgroundColor=UYTLibraryBackground(); self.grid.alwaysBounceVertical=YES; self.grid.dataSource=self; self.grid.delegate=self;
    [self.grid registerClass:UYTVideoCell.class forCellWithReuseIdentifier:@"popular"];
    [self.grid registerClass:UICollectionReusableView.class forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"heading"];
    self.refreshControl=[UIRefreshControl new]; self.refreshControl.tintColor=UIColor.whiteColor; [self.refreshControl addTarget:self action:@selector(reloadFeeds) forControlEvents:UIControlEventValueChanged]; self.grid.refreshControl=self.refreshControl;
    [self.view addSubview:self.grid];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:4], [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16], [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16], [scroll.heightAnchor constraintEqualToConstant:44],
        [chips.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor], [chips.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor], [chips.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:4], [chips.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-4], [scroll.contentLayoutGuide.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor],
        [self.grid.topAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:4], [self.grid.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16], [self.grid.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16], [self.grid.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [self updateVisibleFeeds]; [self reloadFeeds];
}
- (void)dealloc { [self.feedSession invalidateAndCancel]; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; if (self.updated && -self.updated.timeIntervalSinceNow>1800) [self reloadFeeds]; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; if (fabs(self.lastWidth-self.grid.bounds.size.width)>1) { self.lastWidth=self.grid.bounds.size.width; [self.grid.collectionViewLayout invalidateLayout]; } }
- (void)selectFeed:(UIButton *)button { self.selectedFilter=button.tag; [self updateVisibleFeeds]; }
- (void)updateVisibleFeeds {
    NSMutableArray *sections=[NSMutableArray array];
    for (NSUInteger i=0;i<self.feeds.count;i++) if (self.feeds[i].count && (!self.selectedFilter || self.selectedFilter==(NSInteger)i+1)) [sections addObject:@(i)];
    self.visibleSections=sections;
    for (UIButton *button in self.filters) {
        BOOL selected=button.tag==self.selectedFilter; button.selected=selected; button.backgroundColor=selected?UIColor.whiteColor:UYTLibrarySurface();
        [button setTitleColor:selected?UYTLibraryBackground():UIColor.whiteColor forState:UIControlStateNormal]; [button setTitleColor:UYTLibraryBackground() forState:UIControlStateSelected]; button.accessibilityTraits=UIAccessibilityTraitButton|(selected?UIAccessibilityTraitSelected:0);
    }
    if (!sections.count) {
        UIButton *empty=[UIButton buttonWithType:UIButtonTypeSystem]; empty.titleLabel.numberOfLines=0; empty.titleLabel.textAlignment=NSTextAlignmentCenter;
        [empty setTitle:self.pending?@"Загружаем подборки…":@"Не удалось загрузить подборку\nНажмите, чтобы повторить" forState:UIControlStateNormal]; [empty setTitleColor:UYTLibrarySecondaryText() forState:UIControlStateNormal]; [empty addTarget:self action:@selector(reloadFeeds) forControlEvents:UIControlEventTouchUpInside]; self.grid.backgroundView=empty;
    } else self.grid.backgroundView=nil;
    [self.grid reloadData];
}
- (void)reloadFeeds {
    if (self.pending) return; self.pending=UYTPopularURLs().count; [self updateVisibleFeeds];
    __weak UYTPopularVC *weakSelf=self;
    [UYTPopularURLs() enumerateObjectsUsingBlock:^(NSString *url,NSUInteger index,BOOL *stop){
        NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]]; request.timeoutInterval=25; request.HTTPShouldHandleCookies=NO;
        [request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/17.0 Safari/605.1.15" forHTTPHeaderField:@"User-Agent"];
        [[self.feedSession dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
            NSArray *videos=(!error && [(NSHTTPURLResponse *)response statusCode]==200)?UYTPublicVideos(UYTYouTubeInitialData(data)):@[];
            dispatch_async(dispatch_get_main_queue(), ^{
                UYTPopularVC *strongSelf=weakSelf; if (!strongSelf) return;
                NSMutableArray *feeds=[strongSelf.feeds mutableCopy]; if (videos.count) feeds[index]=videos; strongSelf.feeds=feeds;
                strongSelf.pending--; if (!strongSelf.pending) { strongSelf.updated=NSDate.date; [strongSelf.refreshControl endRefreshing]; }
                [strongSelf updateVisibleFeeds];
                NSLog(@"[UYTNative] Public feed category=%lu videos=%lu http=%ld error=%@:%ld",(unsigned long)index,(unsigned long)videos.count,(long)[(NSHTTPURLResponse *)response statusCode],error.domain,(long)error.code);
            });
        }] resume];
    }];
}
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)view { return self.visibleSections.count; }
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section { return self.feeds[self.visibleSections[section].unsignedIntegerValue].count; }
- (NSDictionary *)itemAt:(NSIndexPath *)index { return self.feeds[self.visibleSections[index.section].unsignedIntegerValue][index.item]; }
- (CGSize)collectionView:(UICollectionView *)view layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)index {
    CGFloat width=view.bounds.size.width; NSInteger columns=width>=900?3:width>=560?2:1; CGFloat cellWidth=floor((width-16*(columns-1))/columns); return CGSizeMake(cellWidth,cellWidth*9/16+64);
}
- (CGSize)collectionView:(UICollectionView *)view layout:(UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section { return CGSizeMake(view.bounds.size.width,48); }
- (UICollectionReusableView *)collectionView:(UICollectionView *)view viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)index {
    UICollectionReusableView *header=[view dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"heading" forIndexPath:index]; UILabel *label=(UILabel *)[header viewWithTag:1];
    if (!label) { label=[UILabel new]; label.tag=1; label.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight; label.font=[UIFont systemFontOfSize:20 weight:UIFontWeightBold]; label.textColor=UIColor.whiteColor; [header addSubview:label]; }
    label.frame=header.bounds; label.text=UYTPopularTitles()[self.visibleSections[index.section].unsignedIntegerValue]; return header;
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)index {
    UYTVideoCell *cell=[view dequeueReusableCellWithReuseIdentifier:@"popular" forIndexPath:index]; NSDictionary *item=[self itemAt:index]; NSString *videoID=item[@"videoID"];
    cell.representedID=videoID; cell.nameLabel.text=item[@"title"]; cell.statusLabel.hidden=YES; cell.progress.hidden=YES; cell.durationLabel.text=item[@"durationText"]; cell.durationLabel.hidden=![item[@"durationText"] length];
    UIImage *image=[self.covers objectForKey:videoID]; cell.cover.image=image?:UYTIcon(@"play.rectangle"); cell.cover.contentMode=image?UIViewContentModeScaleAspectFill:UIViewContentModeCenter;
    __weak UYTPopularVC *weakSelf=self;
    cell.more.actions=@[[UYTLibraryAction actionWithTitle:@"Скачать" image:nil identifier:nil handler:^(UYTLibraryAction *action){ UYTDownloadFromMenu(videoID,weakSelf); }]];
    if (!image && ![self.coverRequests containsObject:videoID]) {
        [self.coverRequests addObject:videoID];
        UYTFetchCover(videoID,0,^(UIImage *cover,NSData *data){ dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.coverRequests removeObject:videoID]; if (!cover) return; [weakSelf.covers setObject:cover forKey:videoID cost:UYTCoverCost(cover)];
            for (UYTVideoCell *visible in weakSelf.grid.visibleCells) if ([visible.representedID isEqual:videoID]) { visible.cover.image=cover; visible.cover.contentMode=UIViewContentModeScaleAspectFill; }
        }); });
    }
    return cell;
}
- (void)collectionView:(UICollectionView *)view didSelectItemAtIndexPath:(NSIndexPath *)index {
    UYTOpenPopularVideo([self itemAt:index][@"videoID"],self);
}
@end
UIViewController *UYTMakePopularController(void) { return [UYTPopularVC new]; }
