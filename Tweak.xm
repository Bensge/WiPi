#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <libactivator/libactivator.h>
#import <objc/runtime.h>

#import "Private.h"

static BOOL shouldShowPicker = NO;

/*
*  ----------
* | Listener |
*  ----------
*/

@interface WiPiListener : NSObject <LAListener>
- (void)hideHUD;
@property (nonatomic, retain) UIProgressHUD *hud;
@property (nonatomic, retain) UIWindow *alertWindow;
@property (readonly) UIWindow *oldWindow;
@end

@implementation WiPiListener

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	if (shouldShowPicker)
	{
		//WiPi already active
		return;
	}

	if (event)
	{
		[event setHandled:YES];
	}

	if (_hud)
	{
		[(UIProgressHUD *)_hud hide];
	}

	SBWiFiManager *wifi = (SBWiFiManager *)[objc_getClass("SBWiFiManager") sharedInstance];
  	if (![wifi wiFiEnabled])
  	{
  		[wifi setWiFiEnabled:YES];
  	}

	shouldShowPicker = YES;

	[(WFWiFiManager *)[objc_getClass("WFWiFiManager") sharedInstance] scan];

	_alertWindow = [[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds] retain];
	_alertWindow.backgroundColor = [UIColor clearColor];
	_alertWindow.userInteractionEnabled = NO;
	_alertWindow.windowLevel = UIWindowLevelAlert;
	_alertWindow.hidden = NO;

	UIProgressHUD *hud = [[objc_getClass("UIProgressHUD") alloc] initWithWindow:_alertWindow];
	[hud setText:@"Scanning..."];
	[hud showInView:_alertWindow];
	self.hud = hud;
}

- (void)hideHUD
{
	dispatch_async(dispatch_get_main_queue(),^{
		WiPiListener *listener = (WiPiListener *)[[LAActivator sharedInstance] listenerForName:@"com.bensge.wipi"];
		UIProgressHUD *hud = [listener hud];
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
		// Register listener
		[[LAActivator sharedInstance] registerListener:[self new] forName:@"com.bensge.wipi"];
	}
}

@end

/*
*  -------
* | HOOKS |
*  -------
*/


/*
* iOS 6 & 7 specific
*/

%group Wifi67
%hook WFWiFiManager

- (BOOL)_shouldShowPicker
{
	BOOL ret = %orig;
	if (shouldShowPicker)
	{
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

- (BOOL)_shouldShowPicker:(BOOL)yoloRiteYa
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

- (void)didDeactivateForReason:(int)reason
{
	%log;
	shouldShowPicker = NO;
	%orig;
}

%end
%end

/*
* General stuff
*/

%group Wifi
%hook WFWiFiManager

- (void)scan
{
	[[objc_getClass("WFWiFiManager") sharedInstance] setValue:[NSNumber numberWithInt:-130] forKey:@"_rssiThreshold"];
	%orig;
}

%end
%end

/*
* FlipSwitch hooks
*/

%group FlipSwitch
%hook FSSwitchMainPanel

- (BOOL)hasAlternateActionForSwitchIdentifier:(NSString *)identifier
{
	if ([identifier isEqualToString:@"com.a3tweaks.switch.wifi"])
	{
		return YES;
	}
	return %orig;
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)identifier
{
	if ([identifier isEqualToString:@"com.a3tweaks.switch.wifi"])
	{
		[[LAActivator sharedInstance] sendEvent:nil toListenerWithName:@"com.bensge.wipi"];
	}
	else
	{
		%orig;
	}
}

%end
%end

/*
* ControlCenter toggle hooks
*/

%group ControlCenter
%hook SBControlCenterButton

static char wipiHoldGestureRecognizer;

- (void)setIdentifier:(NSString *)identifier
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

- (void)dealloc
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
- (void)_wipi_longHoldAction:(UILongPressGestureRecognizer *)sender
{
	if (sender.state == UIGestureRecognizerStateBegan)
	{
		[[LAActivator sharedInstance] sendEvent:nil toListenerWithName:@"com.bensge.wipi"];
	}
}

%end
%end

/*
* Hook setup code
*/

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