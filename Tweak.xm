#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <libactivator/libactivator.h>

#import "Private.h"


//////////////////////////////
//////////////////////////////
//////////////////////////////
//////                ////////
//////      CODE      ////////
//////                ////////
//////////////////////////////
//////////////////////////////
//////////////////////////////

@interface WiPiListener : NSObject <LAListener>
@property (nonatomic, retain) UIView *hud;
@property (nonatomic, retain) UIWindow *alertWindow;
@property (readonly) UIWindow *oldWindow;
-(void)hideHUD;
@end


static BOOL shouldShowPicker = NO;


/*
* iOS 6 & 7 specific
*/

%group Wifi67
%hook WFWiFiManager

-(BOOL)_shouldShowPicker
{
	BOOL ret = %orig;
	if (shouldShowPicker){
		shouldShowPicker = NO;
		[(WiPiListener *)[[LAActivator sharedInstance] listenerForName:@"com.bensge.wipi"] hideHUD];
		return YES;
	}
	return ret;
}

%end
%end

/*
* iOS 8+ specific
*/

%group Wifi8
%hook WFWiFiManager

-(BOOL)_shouldShowPicker:(BOOL)yoloRiteYa
{
	BOOL ret = %orig;
	if (shouldShowPicker)
	{
		[(WiPiListener *)[[LAActivator sharedInstance] listenerForName:@"com.bensge.wipi"] hideHUD];
		return YES;
	}
	return ret;
}

%end
%hook WFWiFiAlertItem

- (void)dimiss:(int)arg1
{
	shouldShowPicker = NO;
	%orig;
}
/*- (void)_finishBTScanning
{
	%log;
	NSMutableArray *_networks = [self valueForKey:@"_networks"];
	if (_networks.count > 0)
	{
		NSLog(@"CALLING ORIGGG");
		%orig;
	}
}*/

%end
%end

/*
* General stuff
*/

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

- (void)scan
{
	[[objc_getClass("WFWiFiManager") sharedInstance] setValue:[NSNumber numberWithInt:-130] forKey:@"_rssiThreshold"];
	%orig;
}
%end
/*
static BOOL hookBluetoothSearching = NO;

%hook WFWiFiAlertItem
- (id)init
{
	hookBluetoothSearching = YES;
	id ret = %orig;
	hookBluetoothSearching = NO;
	return ret;
}
%end

%hook BluetoothManager

- (BOOL)isServiceSupported:(int)service
{
	%log;
	if (hookBluetoothSearching && service == 0x1000)
		return NO;
	return %orig;
}
%end
*/
/*
%hook WFWiFiAlertItem

- (void)startBTScan:(BOOL)scan
{
	[self _finishBTScanning];
}

%end
*/
/*
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
*/

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
		UIGestureRecognizer *reco = (UIGestureRecognizer *)objc_getAssociatedObject(self,&wipiHoldGestureRecognizer);
		[self removeGestureRecognizer:reco];
		[reco release];
		objc_setAssociatedObject(self,&wipiHoldGestureRecognizer,nil,OBJC_ASSOCIATION_ASSIGN);
	}

	%orig;
}



-(void)dealloc
{
	if (objc_getAssociatedObject(self,&wipiHoldGestureRecognizer) != nil)
	{
		UIGestureRecognizer *reco = (UIGestureRecognizer *)objc_getAssociatedObject(self,&wipiHoldGestureRecognizer);
		[self removeGestureRecognizer:reco];
		[reco release];
		objc_setAssociatedObject(self,&wipiHoldGestureRecognizer,nil,OBJC_ASSOCIATION_ASSIGN);
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
	//Specific hooks
	if ([objc_getClass("WFWiFiManager") instancesRespondToSelector:@selector(_shouldShowPicker)])
	{
		%init(Wifi67);
	}
	else if ([objc_getClass("WFWiFiManager") instancesRespondToSelector:@selector(_shouldShowPicker:)])
	{
		%init(Wifi8);
	}

	//FlipSwitch hooks
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

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	if (event)
		[event setHandled:YES];

	if (_hud)
		[(UIProgressHUD *)_hud hide];


	SBWiFiManager *wifi = (SBWiFiManager *)[objc_getClass("SBWiFiManager") sharedInstance];
  	if (![wifi wiFiEnabled])
  		[wifi setWiFiEnabled:YES];

	shouldShowPicker = YES;

	[(WFWiFiManager *)[objc_getClass("WFWiFiManager") sharedInstance] scan];

	_alertWindow = [[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds] retain];
	_alertWindow.backgroundColor = [UIColor clearColor];
	_alertWindow.userInteractionEnabled = NO;
	_alertWindow.windowLevel = UIWindowLevelAlert;
	_alertWindow.hidden = NO;

	UIProgressHUD *hud = (UIProgressHUD *)[[objc_getClass("UIProgressHUD") alloc] initWithWindow:_alertWindow];
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
		[hud release];
		listener.hud = nil;

		UIWindow *alertWindow = [listener alertWindow];
		[alertWindow setHidden:YES];
		[alertWindow release];
		listener.alertWindow = nil;
	});
}

+ (void)load
{
	@autoreleasepool 
	{
		// Register our listener
		[[LAActivator sharedInstance] registerListener:[self new] forName:@"com.bensge.wipi"];
	}
}

@end