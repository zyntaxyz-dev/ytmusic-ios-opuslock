TARGET := iphone:clang:latest:16.0
ARCHS = arm64
FINALPACKAGE = 1

LIBRARY_NAME = OpusLock
OpusLock_FILES = Tweak/OpusLock.m Tweak/OpusLockPolicy.m Tweak/OpusLockOverlay.m
OpusLock_CFLAGS = -fobjc-arc -Os -Wall -Wno-deprecated-declarations -Werror=implicit-function-declaration
OpusLock_FRAMEWORKS = Foundation UIKit AVFoundation
OpusLock_INSTALL_PATH = /usr/lib

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/library.mk
