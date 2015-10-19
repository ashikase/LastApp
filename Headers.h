/**
 * Name: LastApp
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Desc: Quickly switch to the previously-active application
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: New BSD (See LICENSE file for details)
 */

#ifndef LASTAPP_HEADERS_H_
#define LASTAPP_HEADERS_H_

@interface SBDisplay : NSObject
- (void)setActivationSetting:(unsigned)setting flag:(BOOL)flag;
- (void)setDeactivationSetting:(unsigned)setting flag:(BOOL)flag;
- (void)setDisplaySetting:(unsigned)setting flag:(BOOL)flag;
@end

@interface SBAlert : SBDisplay @end

@interface SBApplication : SBDisplay  @end
@interface SBApplication (Firmware_LT_80)
- (id)displayIdentifier;
@end
@interface SBApplication (Firmware_GTE_80)
- (id)bundleIdentifier;
@end

@interface SBApplicationController : NSObject
+ (id)sharedInstance;
@end
@interface SBApplicationController (Firmware_LT_80)
- (id)applicationWithDisplayIdentifier:(id)displayIdentifier;
@end
@interface SBApplicationController (Firmware_GTE_80)
- (id)applicationWithBundleIdentifier:(id)bundleIdentifier;
@end

@interface SBAwayController : SBAlert
+ (id)sharedAwayController;
- (BOOL)isLocked;
- (BOOL)isMakingEmergencyCall;
@end

@interface SBDisplayStack : NSObject
- (id)popDisplay:(id)display;
- (void)pushDisplay:(id)display;
- (id)topApplication;
@end

@interface SBIconController : NSObject
+ (id)sharedInstance;
- (BOOL)isEditing;
@end

@interface SBPowerDownController : SBAlert
+ (id)sharedInstance;
- (BOOL)isOrderedFront;
@end

@interface SpringBoard : UIApplication @end
@interface SpringBoard (Backgrounder)
// NOTE: This is needed to prevent a compiler warning
- (void)setBackgroundingEnabled:(BOOL)enabled forDisplayIdentifier:(NSString *)identifier;
@end
@interface SpringBoard (LastApp)
- (void)lastApp_switchToLastApp;
@end

// iOS 6.0+
@interface BKSWorkspace : NSObject
- (id)topApplication;
@end
@interface SBAlertManager : NSObject @end
@interface SBWorkspaceTransaction : NSObject @end
@interface SBToAppWorkspaceTransaction : SBWorkspaceTransaction @end
@interface SBAppToAppWorkspaceTransaction : SBToAppWorkspaceTransaction
@end
@interface SBAppToAppWorkspaceTransaction (Firmware_GTE_60_LT_70)
- (id)initWithWorkspace:(id)workspace alertManager:(id)manager from:(id)from to:(id)to;
@end
@interface SBAppToAppWorkspaceTransaction (Firmware_GTE_70_LT_80)
- (id)initWithWorkspace:(id)workspace alertManager:(id)manager from:(id)from to:(id)to activationHandler:(id)handler;
@end
@interface SBAppToAppWorkspaceTransaction (Firmware_GTE_80)
- (id)initWithAlertManager:(id)manager from:(id)from to:(id)to withResult:(id)handler;
@end
@interface SBAppToAppWorkspaceTransaction (Firmware_GTE_90)
- (id)initWithTransitionRequest:(id)arg1;
@end

@interface SBWorkspace : NSObject
@property(readonly, assign, nonatomic) SBAlertManager *alertManager;
@property(readonly, assign, nonatomic) BKSWorkspace *bksWorkspace;
@property(retain, nonatomic) SBWorkspaceTransaction *currentTransaction;
- (id)_applicationForBundleIdentifier:(id)bundleIdentifier frontmost:(BOOL)frontmost;
@end

@interface SBWorkspaceEvent : NSObject
+ (id)eventWithLabel:(id)label handler:(id)handler;
@end

@interface SBWorkspaceEventQueue : NSObject
+ (id)sharedInstance;
- (void)executeOrAppendEvent:(id)event;
@end

// iOS 7.0+
@interface SBTelephonyManager : NSObject
+ (id)sharedTelephonyManager;
- (BOOL)isEmergencyCallActive;
@end

@interface SBUserAgent : NSObject
+ (id)sharedUserAgent;
- (BOOL)deviceIsPasscodeLocked;
@end

// iOS 8.0+
@interface BSEventQueueEvent : NSObject
+ (id)eventWithName:(id)name handler:(id)handler;
@end

@interface FBWorkspaceEvent : BSEventQueueEvent
@end

@interface FBWorkspaceEventQueue : NSObject
+ (id)sharedInstance;
- (void)executeOrAppendEvent:(id)event;
@end

@interface SpringBoard (Firmware_GTE_80)
@property(retain, nonatomic) SBPowerDownController *powerDownController;
- (id)_accessibilityFrontMostApplication;
@end

// iOS 9.0+
@interface SBMainWorkspace : SBWorkspace
// CALLED
+ (id)sharedInstance;
- (id)createRequestForApplicationActivation:(id)arg1 options:(unsigned int)arg2;
- (BOOL)executeTransitionRequest:(id)arg1;
@end

@interface SBWorkspaceEntity : NSObject @end
@interface SBWorkspaceApplication : SBWorkspaceEntity
// CALLED
- (id)initWithApplication:(id)arg1;
@end

@interface SBWorkspaceTransitionRequest : NSObject @end

#endif // LASTAPP_HEADERS_H_

/* vim: set ft=objc ff=unix sw=4 ts=4 expandtab tw=80: */
