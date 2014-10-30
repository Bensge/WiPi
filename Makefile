#DEBUG=1
ARCHS = armv7 arm64

include theos/makefiles/common.mk

TARGET=7.0:clang

TWEAK_NAME = WiPi
WiPi_FILES = Tweak.xm
WiPi_FRAMEWORKS = UIKit QuartzCore
WiPi_LDFLAGS = -lactivator

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"