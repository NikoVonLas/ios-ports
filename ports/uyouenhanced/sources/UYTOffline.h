#import <UIKit/UIKit.h>
FOUNDATION_EXPORT BOOL UYTOfferOffline(NSURL *url, NSString *videoID, NSString *title, UIViewController *presenter);
FOUNDATION_EXPORT void UYTInstallOfflineButton(UIViewController *controller);

FOUNDATION_EXPORT void UYTDownloadFromMenu(NSString *videoID, UIViewController *presenter);
FOUNDATION_EXPORT BOOL UYTHandleDownloadSheet(id controller, id command, id context);

FOUNDATION_EXPORT void UYTOpenLibrary(UIViewController *presenter);

void UYTUpdateSavedTabsInView(UIView *view);
