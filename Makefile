TWEAK_NAME = LastApp
APP_ID = jp.ashikase.lastapp

LastApp_OBJCC_FILES = Tweak.mm
LastApp_CFLAGS = -F$(SYSROOT)/System/Library/CoreServices -DAPP_ID=\"$(APP_ID)\"
LastApp_LDFLAGS = -lactivator
LastApp_FRAMEWORKS = UIKit CoreGraphics

include theos/makefiles/common.mk
include theos/makefiles/tweak.mk
