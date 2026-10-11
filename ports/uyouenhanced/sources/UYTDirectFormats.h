#import <Foundation/Foundation.h>
FOUNDATION_EXPORT BOOL UYTValidVideoID(id value);
FOUNDATION_EXPORT NSString *UYTVideoIDFromInput(NSString *input);
FOUNDATION_EXPORT NSDictionary *UYTDirectFormats(NSDictionary *response, NSString *requestedID);

FOUNDATION_EXPORT NSMutableURLRequest *UYTPlayerRequest(NSString *videoID);
FOUNDATION_EXPORT NSDictionary *UYTPreviewFormat(NSDictionary *response, NSString *videoID);
FOUNDATION_EXPORT NSString *UYTVideoIDFromThumbnailData(NSData *data);
