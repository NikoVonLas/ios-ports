#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSArray<NSArray<NSNumber *> *> *UYTParseSponsorSegments(id json);
FOUNDATION_EXPORT double UYTSponsorSkipEnd(NSArray *segments, double time, double duration);
FOUNDATION_EXPORT NSArray<NSArray<NSNumber *> *> *UYTSponsorMarkerRanges(NSArray *segments, double duration);
FOUNDATION_EXPORT BOOL UYTSponsorEnabled(void);
FOUNDATION_EXPORT void UYTFetchSponsorSegments(NSString *videoID, void (^completion)(NSArray *segments));
