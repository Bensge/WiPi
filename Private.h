@interface UIProgressHUD : UIView
- (void)dealloc;
- (void)show:(BOOL)arg1;
- (id)initWithWindow:(id)arg1;
- (void)done;
- (void)showInView:(id)arg1;
- (void)setShowsText:(BOOL)arg1;
- (id)_progressIndicator;
- (void)hide;
- (void)setFontSize:(int)arg1;
- (void)setText:(NSString *)arg1;
- (void)layoutSubviews;
- (void)drawRect:(CGRect)arg1;
- (id)initWithFrame:(CGRect)arg1;
@end

@interface WFWiFiManager : NSObject
+ (void)awakeFromBundle;
+ (WFWiFiManager *)sharedInstance;
- (BOOL)joining;
- (void)scan;
- (void)_scanFailed;
@end

@interface UIWindow ()
+ (UIWindow *)keyWindow;
@end


@interface SBWiFiManager : NSObject
+ (SBWiFiManager *)sharedInstance;
- (BOOL)wiFiEnabled;
- (void)setWiFiEnabled:(BOOL)e;
@end

//FlipSwitch WiFi toggle
@interface WifiSwitch : NSObject
@end

@interface FSSwitchPanel : NSObject
+ (FSSwitchPanel *)sharedPanel;
- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier;
// Queries whether a switch supports an alternate action. This is often triggered by a hold gesture
- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier;
// Apply the alternate action of a particular switch
@end

@interface SBControlCenterButton : UIButton /*not exactly, but works for now*/ {
	NSString *_identifier;
	NSNumber *_sortKey;
}
@property(copy, nonatomic) NSString *identifier;
@property(copy, nonatomic) NSNumber *sortKey;
- (void)dealloc;
@end

@interface SBHUDView : NSObject
- (id)initWithHUDViewLevel:(int)lvl;
@end