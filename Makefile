export TARGET = iphone:clang:9.3:6.0
INSTALL_TARGET_PROCESSES += SpringBoard
DEBUG = 0

#PACKAGE_VERSION = $(THEOS_PACKAGE_BASE_VERSION)
ARCHS = armv7 arm64

TWEAK_NAME = WiPi
WiPi_FILES = Tweak.xm
WiPi_FRAMEWORKS = UIKit QuartzCore
WiPi_LDFLAGS = -lactivator

BUNDLE_NAME = WiPiSettings
WiPiSettings_FILES = Preference.m
WiPiSettings_INSTALL_PATH = /Library/PreferenceBundles
WiPiSettings_FRAMEWORKS = UIKit
WiPiSettings_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/WiPi.plist$(ECHO_END)

after-install::
	install.exec "killall -9 SpringBoard"
