export TARGET = iphone:clang:9.3:6.0
INSTALL_TARGET_PROCESSES += SpringBoard

#DEBUG=1
ARCHS = armv7 arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WiPi
WiPi_FILES = Tweak.xm
WiPi_FRAMEWORKS = UIKit QuartzCore
WiPi_LDFLAGS = -lactivator

include $(THEOS_MAKE_PATH)/tweak.mk

