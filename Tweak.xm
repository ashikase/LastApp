/**
 * Name: LastApp
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Desc: Quickly switch to the previously-active application
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: New BSD (See LICENSE file for details)
 *
 * Last-modified: 2014-08-20 14:21:35
 */

#import <libactivator/libactivator.h>

#include "firmware.h"
#include "Headers.h"

//==============================================================================

// DESC: Register the action with the Activator extension.

@interface LastAppActivator : NSObject <LAListener>
@end

@implementation LastAppActivator

+ (void)load {
    static LastAppActivator *listener = nil;
    if (listener == nil) {
        // Create LastApp's event listener and register it with libactivator.
        listener = [[LastAppActivator alloc] init];
        [[LAActivator sharedInstance] registerListener:listener forName:@APP_ID];
    }
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    [springBoard lastApp_switchToLastApp];

    // Prevent the default OS implementation.
    event.handled = YES;
}

@end

//==============================================================================

// DESC: Record the display stack creation and destruction.
// NOTE: This is necessary, as the display stack pointers are stored by
//       SpringBoard in a local static variable, and hence are not normally
//       (practically) accessible.

static NSMutableArray *displayStacks$ = nil;

// Display stack names
#define SBWPreActivateDisplayStack        [displayStacks$ objectAtIndex:0]
#define SBWActiveDisplayStack             [displayStacks$ objectAtIndex:1]
#define SBWSuspendingDisplayStack         [displayStacks$ objectAtIndex:2]
#define SBWSuspendedEventOnlyDisplayStack [displayStacks$ objectAtIndex:3]

%hook SBDisplayStack %group GFirmware_LT_60

- (id)init {
    self = %orig();
    if (self != nil) {
        [displayStacks$ addObject:self];
    }
    return self;
}

- (void)dealloc {
    [displayStacks$ removeObject:self];
    %orig();
}

%end %end

// DESC: Create an array to record the pointers to the display stacks.

%hook SpringBoard %group GFirmware_LT_60

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    // NOTE: SpringBoard creates four stacks at startup.
    // NOTE: Must create array before calling original implementation.
    displayStacks$ = [[NSMutableArray alloc] initWithCapacity:4];

    %orig();
}

%end %end

//==============================================================================

// DESC: Record the workspace creation and destruction.
// NOTE: As with display stacks on earlier iOS versions, the variable that holds
//       the workspace pointer is not (practically) accessible.
// NOTE: iOS 9 added a class and method for retrieving the workspace.

static SBWorkspace *workspace$ = nil;

%hook SBWorkspace %group GFirmware_GTE_60_LT_90

- (id)init {
    self = %orig();
    if (self != nil) {
        workspace$ = [self retain];
    }
    return self;
}

- (void)dealloc {
    if (workspace$ == self) {
        [workspace$ release];
        workspace$ = nil;
    }
    %orig();
}

%end %end

//==============================================================================

// DESC: When the active app changes, record the identifier of the new and
//       previous active apps.

static NSString *currentDisplayId$ = nil;
static NSString *prevDisplayId$ = nil;

static inline NSString *topApplicationIdentifier() {
    if (IOS_GTE(8_0)) {
        return [[(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication] bundleIdentifier];
    } else {
        return (IOS_LT(6_0)) ?
            [[SBWActiveDisplayStack topApplication] displayIdentifier] :
            [workspace$.bksWorkspace topApplication];
    }
}

static inline BOOL isDisplayingPowerDown() {
    if (IOS_GTE(8_0)) {
        SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
        return (springBoard.powerDownController != nil);
    } else if ([%c(SBPowerDownController) respondsToSelector:@selector(sharedInstance)]) {
        return [(SBPowerDownController *)[%c(SBPowerDownController) sharedInstance] isOrderedFront];
    } else {
        return NO;
    }
}

static void saveTopApplication() {
    BOOL isLocked = NO;

    if (IOS_GTE(11_0)) {
        isLocked = ![[%c(SBCoverSheetPresentationManager) sharedInstance] hasBeenDismissedSinceKeybagLock];
    } else if (IOS_LT(7_0)) {
        SBAwayController *awayCont = [%c(SBAwayController) sharedAwayController];
        isLocked = [awayCont isLocked];
    } else {
        isLocked = [[%c(SBUserAgent) sharedUserAgent] deviceIsLocked];
    }

    if (isLocked) {
        // Ignore lock screen.
        return;
    }

    if (isDisplayingPowerDown()) {
        // Ignore power-down screen.
        return;
    }

    NSString *displayId = topApplicationIdentifier();
    if (displayId && ![displayId isEqualToString:currentDisplayId$]) {
        // Active application has changed.
        // NOTE: SpringBoard is purposely ignored.
        // Store the previously-current app as the previous app.
        [prevDisplayId$ autorelease];
        prevDisplayId$ = currentDisplayId$;

        // Store the new current app.
        currentDisplayId$ = [displayId copy];
    }
}

%hook SpringBoard %group GFirmware_LT_70
- (void)frontDisplayDidChange { %orig(); saveTopApplication(); }
%end %end

%hook SpringBoard %group GFirmware_GTE_70
- (void)frontDisplayDidChange:(SBApplication *)app { %orig(); saveTopApplication(); }
%end %end

//==============================================================================

// DESC: Switch between the last two active apps.

static BOOL shouldBackground$ = NO;

static inline BOOL canInvoke() {
    // Should not invoke if either lock screen or power-off screen is active.
    BOOL isLocked = NO;
    BOOL isEmergencyCall = NO;

    if (IOS_GTE(11_0)) {
        isLocked = ![[%c(SBCoverSheetPresentationManager) sharedInstance] hasBeenDismissedSinceKeybagLock];
        isEmergencyCall = [[%c(SBTelephonyManager) sharedTelephonyManager] isEmergencyCallActive];
    } else if (IOS_LT(7_0)) {
        SBAwayController *awayCont = [%c(SBAwayController) sharedAwayController];
        isLocked = [awayCont isLocked];
        isEmergencyCall = [awayCont isMakingEmergencyCall];
    } else {
        isLocked = [[%c(SBUserAgent) sharedUserAgent] deviceIsPasscodeLocked];
        isEmergencyCall = [[%c(SBTelephonyManager) sharedTelephonyManager] isEmergencyCallActive];
    }

    return !(isLocked
            || isEmergencyCall
            || [(SBIconController *)[%c(SBIconController) sharedInstance] isEditing]
            || isDisplayingPowerDown());
}

static inline SBApplication *topApplication() {
    if (IOS_GTE(8_0)) {
        return [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
    } else {
        return (IOS_LT(6_0)) ?
            [SBWActiveDisplayStack topApplication] :
            [workspace$ _applicationForBundleIdentifier:[workspace$.bksWorkspace topApplication] frontmost:YES];
    }
}

%hook SpringBoard

- (void)dealloc {
    [prevDisplayId$ release];
    [currentDisplayId$ release];

    if (IOS_LT(6_0)) {
        [displayStacks$ release];
    }

    %orig();
}

%new
- (void)lastApp_switchToLastApp {
    if (!canInvoke()) return;

    SBApplication *fromApp = topApplication();
    NSString *fromIdent;
    if (IOS_GTE(8_0)) {
        fromIdent = [fromApp bundleIdentifier];
    } else {
        fromIdent = [fromApp displayIdentifier];
    }
    if (![fromIdent isEqualToString:prevDisplayId$]) {
        // App to switch to is not the current app.
        SBApplication *toApp;
        if (IOS_GTE(8_0)) {
            toApp = [(SBApplicationController *)[%c(SBApplicationController) sharedInstance]
                applicationWithBundleIdentifier:(fromIdent ? prevDisplayId$ : currentDisplayId$)];
        } else {
            toApp = [(SBApplicationController *)[%c(SBApplicationController) sharedInstance]
                applicationWithDisplayIdentifier:(fromIdent ? prevDisplayId$ : currentDisplayId$)];
        }

        if (toApp) {
            if (IOS_GTE(11_0)) {
                SBMainWorkspace *workspace = [%c(SBMainWorkspace) sharedInstance];
                SBDeviceApplicationSceneEntity *app = [[%c(SBDeviceApplicationSceneEntity) alloc] initWithApplicationForMainDisplay:toApp];
                SBWorkspaceTransitionRequest *request = [workspace createRequestForApplicationActivation:app options:0];
                [workspace executeTransitionRequest:request];
                [app release];
            } else if (IOS_GTE(9_0)) {
                // NOTE: The "createRequest..." method used below does *not* follow the ownership rule;
                //       the returned object is autoreleased.
                SBMainWorkspace *workspace = [%c(SBMainWorkspace) sharedInstance];
                SBWorkspaceApplication *app = [[%c(SBWorkspaceApplication) alloc] initWithApplication:toApp];
                SBWorkspaceTransitionRequest *request = [workspace createRequestForApplicationActivation:app options:0];
                [workspace executeTransitionRequest:request];
                [app release];
            } else if (IOS_GTE(8_0)) {
                NSString *name = @"ActivateLastApp";
                FBWorkspaceEvent *event = [%c(FBWorkspaceEvent) eventWithName:name handler:^{
                    SBAlertManager *alertManager = workspace$.alertManager;
                    SBAppToAppWorkspaceTransaction *transaction = [%c(SBAppToAppWorkspaceTransaction) alloc];
                    transaction = [transaction initWithAlertManager:alertManager from:fromApp to:toApp withResult:nil];
                    [workspace$ setCurrentTransaction:transaction];
                    [transaction release];
                }];
                [(FBWorkspaceEventQueue *)[%c(FBWorkspaceEventQueue) sharedInstance] executeOrAppendEvent:event];
            } else if (IOS_GTE(6_0)) {
                NSString *label = @"ActivateLastApp";
                SBWorkspaceEvent *event = [%c(SBWorkspaceEvent) eventWithLabel:label handler:^{
                    BKSWorkspace *workspace = [workspace$ bksWorkspace];
                    SBAlertManager *alertManager = workspace$.alertManager;
                    SBAppToAppWorkspaceTransaction *transaction = [%c(SBAppToAppWorkspaceTransaction) alloc];
                    if (IOS_LT(7_0)) {
                        transaction = [transaction initWithWorkspace:workspace alertManager:alertManager from:fromApp to:toApp];
                    } else {
                        transaction = [transaction initWithWorkspace:workspace alertManager:alertManager from:fromApp to:toApp activationHandler:nil];
                    }
                    [workspace$ setCurrentTransaction:transaction];
                    [transaction release];
                }];
                [(SBWorkspaceEventQueue *)[%c(SBWorkspaceEventQueue) sharedInstance] executeOrAppendEvent:event];
            } else {
                [toApp setDisplaySetting:0x4 flag:YES]; // animate

                if (fromIdent == nil) {
                    // Switching from SpringBoard; activate last "current" app.
                    [SBWPreActivateDisplayStack pushDisplay:toApp];
                } else {
                    // Switching from another app; activate previously-active app.
                    if (IOS_LT(4_0)) {
                        // Firmware 3.x
                        [toApp setActivationSetting:0x40 flag:YES]; // animateOthersSuspension
                        [toApp setActivationSetting:0x20000 flag:YES]; // appToApp
                    } else {
                        // Firmware 4.x+
                        [toApp setActivationSetting:0x80 flag:YES]; // animateOthersSuspension
                        [toApp setActivationSetting:0x40000 flag:YES]; // appToApp
                    }

                    if (shouldBackground$) {
                        // If Backgrounder is installed, enable backgrounding for current application.
                        if ([self respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)]) {
                            [self setBackgroundingEnabled:YES forDisplayIdentifier:fromIdent];
                        }
                    }

                    // NOTE: Must set animation flag for deactivation, otherwise
                    //       application window does not disappear (reason yet unknown).
                    [fromApp setDeactivationSetting:0x2 flag:YES]; // animate

                    // Activate the target application.
                    // NOTE: will wait for deactivation of current app due to appToApp flag.
                    [SBWPreActivateDisplayStack pushDisplay:toApp];

                    // Deactivate current application by moving from active to suspending stack.
                    [SBWActiveDisplayStack popDisplay:fromApp];
                    [SBWSuspendingDisplayStack pushDisplay:fromApp];
                }
            }
        }
    }
}

%end

//==============================================================================

static void loadPreferences() {
    shouldBackground$ = (BOOL)CFPreferencesGetAppBooleanValue(CFSTR("shouldBackground"), CFSTR(APP_ID), NULL);
}

static void reloadPreferences(CFNotificationCenterRef center, void *observer,
    CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    // NOTE: Must synchronize preferences from disk.
    CFPreferencesAppSynchronize(CFSTR(APP_ID));
    loadPreferences();
}

__attribute__((constructor)) static void init() {
    @autoreleasepool {
        // NOTE: This library should only be loaded for SpringBoard.
        NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
        if ([identifier isEqualToString:@"com.apple.springboard"]) {
            // Initialize hooks
            %init();

            if (IOS_LT(6_0)) {
                %init(GFirmware_LT_60);
            } else if (IOS_LT(9_0)) {
                %init(GFirmware_GTE_60_LT_90);
            }

            if (IOS_LT(7_0)) {
                %init(GFirmware_LT_70);
            } else {
                %init(GFirmware_GTE_70);
            }

            // Load preferences.
            loadPreferences();

            // Add observer for changes made to preferences.
            CFNotificationCenterAddObserver(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    NULL, reloadPreferences, CFSTR(APP_ID"-settings"),
                    NULL, 0);

            // Create the libactivator event listener.
            [LastAppActivator load];
        }
    }
}

/* vim: set ft=logos sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
