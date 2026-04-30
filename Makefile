TARGET := iphone:clang:latest:16.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME = rootless


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTGestures

YTGestures_FILES = Tweak.x
YTGestures_CFLAGS = -fobjc-arc
YTGestures_FRAMEWORKS = UIKit MediaPlayer AVFoundation
YTGestures_LOGOSFLAGS = -c generator=internal

include $(THEOS_MAKE_PATH)/tweak.mk
