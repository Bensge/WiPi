#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <libactivator/libactivator.h>

static BOOL shouldShowPicker = NO;
/*
static void printQ(){
	NSLog(@"QUEUE: %@",[NSString stringWithUTF8String:dispatch_queue_get_label(dispatch_get_current_queue())]);
}

static void alert(NSString *s){
	[[[[UIAlertView alloc] initWithTitle:@"WiPi" message:s delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];
}
*/

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
+(void)awakeFromBundle;
+(WFWiFiManager *)sharedInstance;
-(BOOL)joining;
-(void)scan;
-(void)_scanFailed;
@end

@interface UIWindow ()
+(UIWindow *)keyWindow;
@end


@interface SBWiFiManager : NSObject
+(SBWiFiManager *)sharedInstance;
-(BOOL)wiFiEnabled;
-(void)setWiFiEnabled:(BOOL)e;
@end

//FlipSwitch WiFi toggle
@interface WifiSwitch : NSObject
@end

@interface FSSwitchPanel : NSObject
+(FSSwitchPanel *)sharedPanel;
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
-(id)initWithHUDViewLevel:(int)lvl;
@end




//////////////////////////////
//////////////////////////////
//////   CODE ////////////////
//////////////////////////////
//////////////////////////////
/*
@interface WiPiHooker : NSObject
+(void)hook;
@property (nonatomic, retain) NSArray *results;
@end
*/
@interface WiPiListener : NSObject <LAListener>
@property (nonatomic, retain) UIView *hud;
@property (nonatomic, retain) UIWindow *alertWindow;
@property (readonly) UIWindow *oldWindow;
-(void)hideHUD;
@end


%group Wifi
%hook WFWiFiManager
/*
-(void)_wifiScanComplete:(CFArrayRef)complete{
	NSLog(@"WIFISUCCESS");
	WifiResult *res = [[WifiResult alloc] init];
	res.results = [(NSArray *)complete copy];
	NSLog(@"RESULT: %@",res);
	%orig;
}*/

-(BOOL)_shouldShowPicker{
	BOOL ret = %orig;
	if (shouldShowPicker){
		shouldShowPicker = NO;
		[(WiPiListener *)[[LAActivator sharedInstance] listenerForName:@"com.bensge.wipi"] hideHUD];
		return YES;
	}
	return ret;
}

-(void)scan
{
	[[objc_getClass("WFWiFiManager") sharedInstance] setValue:[NSNumber numberWithInt:-130] forKey:@"_rssiThreshold"];
	%orig;
}
%end

%subclass WiPiLoadingHUDView : SBHUDView
-(id)init
{
	if ((self = (WiPiLoadingHUDView *)[(SBHUDView *)self initWithHUDViewLevel:0]))
	{
		[self setValue:@NO forKey:@"_showsProgress"];
		[self performSelector:@selector(setTitle:) withObject:@"Scanning..."];

		UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		activityIndicator.center = [(UIView *)self center];
		[self addSubview:activityIndicator];
		[activityIndicator startAnimating];
		[activityIndicator release];
	}
	return self;
}

- (BOOL)displaysLabel
{
	return YES;
}
%end

%end
/////


%group FlipSwitch
%hook FSSwitchMainPanel
-(BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)identifier
{
	if ([identifier isEqualToString:@"com.a3tweaks.switch.wifi"]){
		return YES;
	}
	return %orig;
}
-(void)applyAlternateActionForSwitchIdentifier:(NSString *)identifier
{
	if ([identifier isEqualToString:@"com.a3tweaks.switch.wifi"])
	{
		[[LAActivator sharedInstance] sendEvent:nil toListenerWithName:@"com.bensge.wipi"];
	}
	else {
		%orig;
	}
}
%end
%end

%group ControlCenter

%hook SBControlCenterButton

static char wipiHoldGestureRecognizer;

-(void)setIdentifier:(NSString *)identifier
{
	if ([identifier isEqualToString:@"wifi"] && objc_getAssociatedObject(self,&wipiHoldGestureRecognizer) == nil)
	{
		UILongPressGestureRecognizer *reco = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_wipi_longHoldAction:)];
		reco.minimumPressDuration = 0.9f;
		[self addGestureRecognizer:reco];
		objc_setAssociatedObject(self,&wipiHoldGestureRecognizer,reco,OBJC_ASSOCIATION_ASSIGN);
		[reco release];
	}
	else if (![identifier isEqualToString:@"wifi"] && objc_getAssociatedObject(self,&wipiHoldGestureRecognizer) != nil)
	{
		[self removeGestureRecognizer:(UIGestureRecognizer *)objc_getAssociatedObject(self,&wipiHoldGestureRecognizer)];
	}

	%orig;
}



-(void)dealloc
{
	if (objc_getAssociatedObject(self,&wipiHoldGestureRecognizer) != nil)
	{
		[self removeGestureRecognizer:(UIGestureRecognizer *)objc_getAssociatedObject(self,&wipiHoldGestureRecognizer)];
	}

	%orig;
}


%new
-(void)_wipi_longHoldAction:(UILongPressGestureRecognizer *)sender
{
	if (sender.state == UIGestureRecognizerStateBegan)
	{
		[[LAActivator sharedInstance] sendEvent:nil toListenerWithName:@"com.bensge.wipi"];
	}
}

%end
%end



/////
%group General
%hook SBPluginManager

- (void)loadAllLaunchPlugins
{
	%orig;

	%init(Wifi);
	if (objc_getClass("FSSwitchPanel"))
	{
		%init(FlipSwitch);
	}
}
%end
%end



%ctor
{
	%init(General);
	if (objc_getClass("SBControlCenterButton"))
	{
		%init(ControlCenter);
	}
}


@implementation WiPiListener
@synthesize hud = _hud, alertWindow = _alertWindow, oldWindow = _oldWindow;

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event{

	if (event) [event setHandled:YES];

	if (_hud) [(UIProgressHUD *)_hud hide];


	SBWiFiManager *wifi = (SBWiFiManager *)[objc_getClass("SBWiFiManager") sharedInstance];
  	if (![wifi wiFiEnabled])
  		[wifi setWiFiEnabled:YES];


	shouldShowPicker = YES;

	[(WFWiFiManager *)[objc_getClass("WFWiFiManager") sharedInstance] scan];

	_alertWindow = [[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds] retain];
	_alertWindow.backgroundColor = [UIColor clearColor];
	_alertWindow.userInteractionEnabled = NO;
	_alertWindow.windowLevel = UIWindowLevelAlert;
	[_alertWindow setHidden:NO];

	UIProgressHUD *hud = (UIProgressHUD *)[[[objc_getClass("UIProgressHUD") alloc] initWithWindow:_alertWindow] retain];
	[hud setText:@"Scanning..."];
	[hud showInView:_alertWindow];
	_hud = (UIView *)hud;
}

-(void)hideHUD
{
	dispatch_async(dispatch_get_main_queue(),^{
		WiPiListener *listener = (WiPiListener *)[[LAActivator sharedInstance] listenerForName:@"com.bensge.wipi"];
		UIProgressHUD *hud = (UIProgressHUD *)[listener hud];
		[hud hide];
		//[hud release];

		[listener setHud:nil];
		UIWindow *alertWindow = [listener alertWindow];
		[alertWindow setHidden:YES];
		[alertWindow release];
		[alertWindow release];
		listener.alertWindow = nil;
	});
}

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Register our listener
	[[LAActivator sharedInstance] registerListener:[self new] forName:@"com.bensge.wipi"];
	[pool release];
}

@end