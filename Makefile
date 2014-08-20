TWEAK_NAME = LastApp
APP_ID = jp.ashikase.lastapp

LastApp_OBJCC_FILES = Tweak.mm
LastApp_CFLAGS = -F$(SYSROOT)/System/Library/CoreServices -DAPP_ID=\"$(APP_ID)\"
LastApp_LDFLAGS = -lactivator
LastApp_FRAMEWORKS = UIKit CoreGraphics

TARGET := iphone:7.1:3.0
ARCHS := armv6 arm64

# NOTE: The following is needed until logos is updated to not generate
#       unnecessary 'ungrouped' objects.
GO_EASY_ON_ME := 1

include theos/makefiles/common.mk
include theos/makefiles/tweak.mk

distclean: clean
	- rm -f $(THEOS_PROJECT_DIR)/$(APP_ID)*.deb
	- rm -f $(THEOS_PROJECT_DIR)/.theos/packages/*
