#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <libactivator/libactivator.h>
#import <objc/runtime.h>
#import "Private.h"

#define PREF_PATH @"/var/mobile/Library/Preferences/com.bensge.wipi.plist"

static BOOL shouldShowPicker = NO;
static BOOL longHoldEnabled;

static void LoadSettings()
{
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    
    longHoldEnabled = [dict objectForKey:@"enabled"] ? [[dict objectForKey:@"enabled"] boolValue] : YES;
}

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

@interface WFWiFiManager (Additions)
- (NSString *)currentNetworkBSSID;
@end

@implementation WiPiListener

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	if (shouldShowPicker)
	{
		//WiPi already active, It does not work well on lock screen.
		return;
	}
    
    //It does not work well on lock screen on iOS10.
    if (kCFCoreFoundationVersionNumber >= 1348.00 && [[objc_getClass("SBUserAgent") sharedUserAgent] deviceIsLocked]) return;

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

- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
    return @"WiPi";
}

- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
    return @"Show WiFi Picker";
}

- (NSData *)activator:(LAActivator *)activator requiresSmallIconDataForListenerName:(NSString *)listenerName scale:(CGFloat *)scale
{
    if (*scale == 1.0) {
        return [NSData dataWithContentsOfFile:@"/Library/PreferenceBundles/WiPiSettings.bundle/WiPi.png"];
    } else if (*scale == 2.0){
        return [NSData dataWithContentsOfFile:@"/Library/PreferenceBundles/WiPiSettings.bundle/WiPi@2x.png"];
    } else {
        return [NSData dataWithContentsOfFile:@"/Library/PreferenceBundles/WiPiSettings.bundle/WiPi@3x.png"];
    }
}

- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName
{
    //It does not work well on lock screen on iOS10.
    if (kCFCoreFoundationVersionNumber >= 1348.00) {
        return @[@"springboard", @"application"];
    } else {
        return @[@"springboard", @"lockscreen", @"application"];
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
	shouldShowPicker = NO;
	%orig;
}

// Fix the appearance of the wifi picker in iOS 8 and up
// Remove white table background, add top border to tableview
- (void)configure:(BOOL)arg1 requirePasscodeForActions:(BOOL)arg2
{
	%orig;
	UITableView *table = [self valueForKey:@"_table"];
	table.backgroundColor = UIColor.clearColor;
	// This is not very elegant. The tableView is not in the view hierarchy at this point, but soon will be.
	// We can't just add the border view to the tableView, then it moves while scolling :/
	dispatch_async(dispatch_get_main_queue(), ^{
		UIView *topBorder = [[UIView alloc] initWithFrame:CGRectMake(0,0,table.frame.size.width,0.5)];
		topBorder.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
		topBorder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[table.superview addSubview:topBorder];
	});
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
	//Only on 7 and later
	if (kCFCoreFoundationVersionNumber >= 847.20)
	{
		[[objc_getClass("WFWiFiManager") sharedInstance] setValue:[NSNumber numberWithInt:-130] forKey:@"_rssiThreshold"];
	}
	%orig;
}

NSData *(*_dynamic_WiFiNetworkGetSSIDData)(void *) = (NSData *(*)(void *))(dlsym(RTLD_DEFAULT, "WiFiNetworkGetSSIDData"));
void *(*_dynamic_WiFiDeviceClientCopyCurrentNetwork)(void *) = (void *(*)(void *))(dlsym(RTLD_DEFAULT, "WiFiDeviceClientCopyCurrentNetwork"));
CFDictionaryRef (*_dynamic_WiFiNetworkCopyRecord)(void *) = (CFDictionaryRef (*)(void *))(dlsym(RTLD_DEFAULT, "WiFiNetworkCopyRecord"));
CFStringRef (*_dynamic_WiFiNetworkGetProperty)(void *, CFStringRef) = (CFStringRef (*) (void *, CFStringRef))(dlsym(RTLD_DEFAULT, "WiFiNetworkGetProperty"));

%new
- (NSString *)currentNetworkBSSID
{
	//Doesn't work with key value coding, c struct pointers not supported
	//void *device = [self valueForKey:@"_device"];
	void *device = MSHookIvar<void *>(self, "_device");
	if (device != NULL)
	{
		void *currentNetwork = _dynamic_WiFiDeviceClientCopyCurrentNetwork(device);
		if (currentNetwork != NULL)
		{
			//NSDictionary *properties = (NSDictionary *)_dynamic_WiFiNetworkCopyRecord(currentNetwork);
			NSString *data = (NSString *)_dynamic_WiFiNetworkGetProperty(currentNetwork, CFSTR("BSSID"));
			return data;
		}
	}
	return NULL;
}

%end

%hook WFWiFiAlertItem

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)idx
{
	UITableViewCell *cell = %orig();
	if ([cell isKindOfClass:objc_getClass("WFWiFiCell")])
	{
		NSDictionary *networkData = [cell valueForKey:@"_dict"];

		NSString *currentNetworkBSSID = (NSString *)[[objc_getClass("WFWiFiManager") sharedInstance] currentNetworkBSSID];

		if ([networkData[@"BSSID"] isEqualToString:currentNetworkBSSID])
		{
			cell.textLabel.text = [@"✓ " stringByAppendingString:cell.textLabel.text];
		}
	}
    
    return cell;
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
    LoadSettings();
    
	if ([identifier isEqualToString:@"com.a3tweaks.switch.wifi"] && longHoldEnabled)
	{
		return YES;
	}
	return %orig;
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)identifier
{
    LoadSettings();
    
	if ([identifier isEqualToString:@"com.a3tweaks.switch.wifi"] && longHoldEnabled)
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
* CCUIControlCenterPushButton for >= iOS 10
* SBControlCenterButton       for <= iOS  9
*/



%group ControlCenter
%hook BUTTONCLASS

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
    LoadSettings();
    
	if (sender.state == UIGestureRecognizerStateBegan && longHoldEnabled)
	{
		[[LAActivator sharedInstance] sendEvent:nil toListenerWithName:@"com.bensge.wipi"];
	}
}

%end
%end

/*
* Hook setup code
*/

void _init()
{
	static dispatch_once_t once;
    dispatch_once(&once, ^{
		%init(Wifi);
	});
}

void initiOS6And7()
{
	_init();
	static dispatch_once_t once;
    dispatch_once(&once, ^{
		%init(Wifi67);
	});
}

void initiOS8AndLater()
{
	_init();
	static dispatch_once_t once;
    dispatch_once(&once, ^{
		%init(Wifi8);
	});
}

void initFlipSwitch()
{
	static dispatch_once_t once;
    dispatch_once(&once, ^{
		%init(FlipSwitch);
	});
}

%group General9AndEarlier
%hook SBPluginManager

- (void)loadAllLaunchPlugins
{
	%orig;
	//Specific hooks
	if ([objc_getClass("WFWiFiManager") instancesRespondToSelector:@selector(_shouldShowPicker)])
	{
		initiOS6And7();
	}
	else if ([objc_getClass("WFWiFiManager") instancesRespondToSelector:@selector(_shouldShowPicker:)])
	{
		initiOS8AndLater();
	}

	//FlipSwitch hooks
	if (objc_getClass("FSSwitchPanel"))
	{
		initFlipSwitch();
	}
}
%end
%end

%group General10AndLater
%hook NSBundle
+ (instancetype)bundleWithPath:(NSString *)path {
	NSBundle *ret = %orig;
	if ([path isEqualToString:@"/System/Library/SpringBoardPlugins/WiFiPicker.servicebundle"]) {
		[ret load];
		initiOS8AndLater();
		initFlipSwitch();
	}
	return ret;
}

%end
%end

%ctor
{
    @autoreleasepool {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        (CFNotificationCallback)LoadSettings,
                                        CFSTR("com.bensge.wipi.preferencechanged"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        
        if (kCFCoreFoundationVersionNumber >= 1348.00)
        {
            %init(General10AndLater);
        }
        else {
            %init(General9AndEarlier);
        }
        
        if (objc_getClass("SBControlCenterButton") || objc_getClass("CCUIControlCenterPushButton"))
        {
            %init(ControlCenter,BUTTONCLASS=(objc_getClass("SBControlCenterButton") ?: objc_getClass("CCUIControlCenterPushButton")));
        }
        
        LoadSettings();
    }
}