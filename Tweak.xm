#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <libactivator/libactivator.h>
#import <objc/runtime.h>
#import "Private.h"

#define PREF_PATH @"/var/mobile/Library/Preferences/com.bensge.wipi.plist"
#define SETTINGS_CHANGED_NOTIFICATION "com.bensge.wipi.preferencechanged"
#define DUMMY_TITLES 0

#define CoreFoundationiOS7 847.20
#define CoreFoundationiOS10 1348.00

static BOOL shouldShowPicker = NO;

static NSUserDefaults *defaults = nil;
static BOOL legacyLongHoldEnabled = YES;

/*
*  -------------
* | Preferences |
*  -------------
*/

static void settingsChangedCallback()
{
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    
    legacyLongHoldEnabled = [dict objectForKey:@"enabled"] ? [[dict objectForKey:@"enabled"] boolValue] : YES;
}

static void loadSettings()
{
	if (kCFCoreFoundationVersionNumber >= CoreFoundationiOS7)
	{
	   	defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.bensge.wipi"];
	    [defaults registerDefaults:@{
	    	@"enabled" : @YES
	    }];
	}
	else
	{
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        (CFNotificationCallback)settingsChangedCallback,
                                        CFSTR(settingsChangedNotification),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
		settingsChangedCallback();
	}
}

static BOOL isLongHoldEnabled()
{
	if (kCFCoreFoundationVersionNumber >= CoreFoundationiOS7)
	{
		return [defaults boolForKey:@"enabled"];
	}
	else {
		return legacyLongHoldEnabled;
	}
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
- (NSSet<NSString *> *)currentNetworkBSSIDs;
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
    if (kCFCoreFoundationVersionNumber >= CoreFoundationiOS10 && [[objc_getClass("SBUserAgent") sharedUserAgent] deviceIsLocked]) return;

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

- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
	__block NSBundle *preferenceBundle = nil;
	static dispatch_once_t once;
    dispatch_once(&once, ^{
		preferenceBundle = [NSBundle bundleWithPath:@"/Library/PreferenceBundles/WiPiSettings.bundle/"];
	});

	UIImage *icon = [UIImage imageNamed:@"WiPi" inBundle:preferenceBundle];
	return icon;
}

- (NSArray *)activator:(LAActivator *)activator requiresCompatibleEventModesForListenerWithName:(NSString *)listenerName
{
    //It does not work well on lock screen on iOS10.
    if (kCFCoreFoundationVersionNumber >= CoreFoundationiOS10) {
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
	if (kCFCoreFoundationVersionNumber >= CoreFoundationiOS7)
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
- (NSArray<NSString *> *)currentNetworkBSSIDs
{
	//Doesn't work with key value coding, c struct pointers not supported
	//void *device = [self valueForKey:@"_device"];
	void *device = MSHookIvar<void *>(self, "_device");
	if (device != NULL)
	{
		void *currentNetwork = _dynamic_WiFiDeviceClientCopyCurrentNetwork(device);
		if (currentNetwork != NULL)
		{
			NSDictionary *properties = (NSDictionary *)_dynamic_WiFiNetworkCopyRecord(currentNetwork);
			// The properties dictionary is of the following form:
			/*
			{
				"AP_MODE" = 2;
			    "ASSOC_FLAGS" = 1;
			    "BEACON_INT" = 20;
			    BSSID = "55:65:51:57:25:55";
			    CAPABILITIES = 1329;
			    CHANNEL = 44;
				networkKnownBSSListKey = (
		            {
			            BSSID = "55:65:51:57:25:55";
			            CHANNEL = 6;
			            "CHANNEL_FLAGS" = 10;
			            lastRoamed = "2017-07-20 13:57:31 +0000";
			        },
		            {
			            BSSID = "11:11:11:11:11:11";
			            CHANNEL = 44;
			            "CHANNEL_FLAGS" = 1040;
			            lastRoamed = "2017-07-20 14:01:11 +0000";
			        }
			    );
			}
		    */
			//NSString *data = (NSString *)_dynamic_WiFiNetworkGetProperty(currentNetwork, CFSTR("BSSID"));
			NSString *bssid = properties[@"BSSID"];

			NSMutableSet<NSString *> *bssidSet = [NSMutableSet setWithObject:bssid];

			NSObject *knownBSSIDsList = properties[@"networkKnownBSSListKey"];
			if (knownBSSIDsList && [knownBSSIDsList isKindOfClass:NSArray.class])
			{
				for (NSObject *bssidInfo in (NSArray *)knownBSSIDsList)
				{
					if ([bssidInfo isKindOfClass:NSDictionary.class])
					{
						NSObject *knownBSSID = ((NSDictionary *)bssidInfo)[@"BSSID"];
						if ([knownBSSID isKindOfClass:NSString.class]) {
							[bssidSet addObject:(NSString *)knownBSSID];
						}
					}
				}
			}
			return [[bssidSet copy] autorelease];
		}
	}
	return NULL;
}

%end

%hook WFWiFiAlertItem

// Useful for taking screenshots
#if DUMMY_TITLES
NSArray *dummyTitles = @[
	@"My WiFi network",
	@"Corporate network",
	@"Family network",
	@"Dog WiFi",
	@"Restaurant",
	@"Public WiFi"
];
#endif

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)idx
{
	UITableViewCell *cell = %orig();
	if ([cell isKindOfClass:objc_getClass("WFWiFiCell")])
	{
		NSDictionary *networkData = [cell valueForKey:@"_dict"];

		NSSet<NSString *> *currentNetworkBSSIDs = [[objc_getClass("WFWiFiManager") sharedInstance] currentNetworkBSSIDs];

		if ([currentNetworkBSSIDs containsObject:networkData[@"BSSID"]] || [networkData[@"isValid"] boolValue])
		{
#if DUMMY_TITLES		
			NSString *originalText = idx.row < dummyTitles.count ? dummyTitles[idx.row] : cell.textLabel.text;
#else
			NSString *originalText = cell.textLabel.text;
#endif

			NSMutableAttributedString *label = [[NSMutableAttributedString alloc] initWithString:[@"✓ " stringByAppendingString:originalText]];
			if ([UIColor.class respondsToSelector:@selector(systemBlueColor)])
			{
				[label addAttribute:NSForegroundColorAttributeName value:UIColor.systemBlueColor range:NSMakeRange(0,1)];
			}
			cell.textLabel.attributedText = [[label copy] autorelease];
			[label release];
		}

#if DUMMY_TITLES
		else if (idx.row < dummyTitles.count)
		{
			cell.textLabel.text = dummyTitles[idx.row];
		}
#endif

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
    if ([identifier isEqualToString:@"com.a3tweaks.switch.wifi"] && isLongHoldEnabled())
	{
		return YES;
	}
	return %orig;
}

- (void)applyAlternateActionForSwitchIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:@"com.a3tweaks.switch.wifi"] && isLongHoldEnabled())
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
    if (sender.state == UIGestureRecognizerStateBegan && isLongHoldEnabled())
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

/*
*  -------------
* | Constructor |
*  -------------
*/

%ctor
{
    @autoreleasepool
    {	
        if (kCFCoreFoundationVersionNumber >= CoreFoundationiOS10)
        {
            %init(General10AndLater);
        }
        else {
            %init(General9AndEarlier);
        }
        
        if (objc_getClass("SBControlCenterButton") || objc_getClass("CCUIControlCenterPushButton"))
        {
            %init(ControlCenter, BUTTONCLASS=(objc_getClass("SBControlCenterButton") ?: objc_getClass("CCUIControlCenterPushButton")));
        }
        
        loadSettings();
    }
}