ARCHS = armv7
TARGET = iphone:clang:6.1:5.1
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = iPad1VNC
iPad1VNC_FILES = src/main.m src/AppDelegate.m src/VNCClient.m src/VNCView.m src/TerminalSession.m src/LegacyTerminalBuffer.m src/KeychainStore.m
iPad1VNC_FRAMEWORKS = UIKit Foundation CoreGraphics Security
iPad1VNC_CFLAGS = -fno-objc-arc -Wall -Wextra -Wno-deprecated-declarations
iPad1VNC_LDFLAGS = -Wl,-dead_strip -lz

iPad1VNC_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/application.mk
