TWEAK_NAME = LastApp
APP_ID = jp.ashikase.lastapp

LastApp_OBJCC_FILES = Tweak.mm
LastApp_CFLAGS = -F$(SYSROOT)/System/Library/CoreServices -DAPP_ID=\"$(APP_ID)\"
LastApp_LDFLAGS = -lactivator
LastApp_FRAMEWORKS = UIKit CoreGraphics

# Uncomment the following lines when compiling with self-built version of LLVM/Clang
#export ARCHS =
#export SDKTARGET = arm-apple-darwin11
#export TARGET_CXX = clang -ccc-host-triple $(SDKTARGET)
#export TARGET_LD = $(SDKTARGET)-g++

include theos/makefiles/common.mk
include theos/makefiles/tweak.mk

distclean: clean
	- rm -f $(THEOS_PROJECT_DIR)/$(APP_ID)*.deb
	- rm -f $(THEOS_PROJECT_DIR)/.theos/packages/*
