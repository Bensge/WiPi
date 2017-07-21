#import <UIKit/UIKit.h>
#import <Preferences/PSControlTableCell.h>
#import <Preferences/PSListController.h>

@interface WiPiPreferenceController : PSListController
@end

@implementation WiPiPreferenceController
- (id)specifiers {
	if (_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"WiPi" target:self] retain];
	}
	return _specifiers;
}
@end