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

#ifndef kCFCoreFoundationVersionNumber_iOS_4_0
#define kCFCoreFoundationVersionNumber_iOS_4_0 550.32
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_6_0
#define kCFCoreFoundationVersionNumber_iOS_6_0 793.00
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_7_0
#define kCFCoreFoundationVersionNumber_iOS_7_0 847.20
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_8_0_0
#define kCFCoreFoundationVersionNumber_iOS_8_0_0 1140.10
#endif

@interface SBDisplay : NSObject
- (void)setActivationSetting:(unsigned)setting flag:(BOOL)flag;
- (void)setDeactivationSetting:(unsigned)setting flag:(BOOL)flag;
- (void)setDisplaySetting:(unsigned)setting flag:(BOOL)flag;
@end

@interface SBApplication : SBDisplay  @end
@interface SBApplication (Firmware_LT_80)
- (id)displayIdentifier;
@end
@interface SBApplication (Firmware_GTE_80)
- (id)bundleIdentifier;
@end

@interface SBAlert : SBDisplay @end

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

// NOTE: This is needed to prevent a compiler warning
@interface SpringBoard (Backgrounder)
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

// iOS 8.0+
@interface SpringBoard (Firmware_GTE_80)
- (id)_accessibilityFrontMostApplication;
@end

@interface BSEventQueueEvent : NSObject
+ (id)eventWithName:(id)name handler:(id)handler;
@end

@interface FBWorkspaceEvent : BSEventQueueEvent
@end

@interface FBWorkspaceEventQueue : NSObject
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

//==============================================================================

// DESC: Register the action with the Activator extension.

@interface LastAppActivator : NSObject <LAListener>
@end

@implementation LastAppActivator

+ (void)load
{
    static LastAppActivator *listener = nil;
    if (listener == nil) {
        // Create LastApp's event listener and register it with libactivator
        listener = [[LastAppActivator alloc] init];
        [[LAActivator sharedInstance] registerListener:listener forName:@APP_ID];
    }
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    [springBoard lastApp_switchToLastApp];

    // Prevent the default OS implementation
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

- (id)init
{
    id stack = %orig();
    [displayStacks$ addObject:stack];
    return stack;
}

- (void)dealloc
{
    [displayStacks$ removeObject:self];
    %orig();
}

%end %end

//==============================================================================

// DESC: Record the workspace creation and destruction.
// NOTE: As with display stacks on earlier iOS versions, the variable that holds
//       the workspace pointer is not (practically) accessible.

static SBWorkspace *workspace$ = nil;

%hook SBWorkspace %group GFirmware_GTE_60

- (id)init
{
    self = %orig();
    if (self != nil) {
        workspace$ = [self retain];
    }
    return self;
}

- (void)dealloc
{
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

static inline NSString *topApplicationIdentifier()
{
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0_0) {
        return [[(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication] bundleIdentifier];
    } else {
        return (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_6_0) ?
            [[SBWActiveDisplayStack topApplication] displayIdentifier] :
            [workspace$.bksWorkspace topApplication];
    }
}

static void saveTopApplication()
{
    if ([[objc_getClass("SBAwayController") sharedAwayController] isLocked]) {
        // Ignore lock screen
        return;
    }

    if ([objc_getClass("SBPowerDownController") respondsToSelector:@selector(sharedInstance)]) {
        if ([(SBPowerDownController *)[objc_getClass("SBPowerDownController") sharedInstance] isOrderedFront]) {
            // Ignore power-down screen
            return;
        }
    }

    NSString *displayId = topApplicationIdentifier();
    if (displayId && ![displayId isEqualToString:currentDisplayId$]) {
        // Active application has changed
        // NOTE: SpringBoard is purposely ignored
        // Store the previously-current app as the previous app
        [prevDisplayId$ autorelease];
        prevDisplayId$ = currentDisplayId$;

        // Store the new current app
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

static inline BOOL canInvoke()
{
    // Should not invoke if either lock screen or power-off screen is active.
    BOOL isLocked = NO;
    BOOL isEmergencyCall = NO;

    if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0) {
        SBAwayController *awayCont = [%c(SBAwayController) sharedAwayController];
        isLocked = [awayCont isLocked];
        isEmergencyCall = [awayCont isMakingEmergencyCall];
    } else {
        isLocked = [[%c(SBUserAgent) sharedUserAgent] deviceIsPasscodeLocked];
        isEmergencyCall = [[%c(SBTelephonyManager) sharedTelephonyManager] isEmergencyCallActive];
    }

    if ([objc_getClass("SBPowerDownController") respondsToSelector:@selector(sharedInstance)]) {
        return !(isLocked
                || isEmergencyCall
                || [(SBIconController *)[%c(SBIconController) sharedInstance] isEditing]
                || [(SBPowerDownController *)[%c(SBPowerDownController) sharedInstance] isOrderedFront]);
    } else {
        return !(isLocked
                || isEmergencyCall
                || [(SBIconController *)[%c(SBIconController) sharedInstance] isEditing]);
    }
}

static inline SBApplication *topApplication()
{
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0_0) {
        return [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
    } else {
        return (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_6_0) ?
            [SBWActiveDisplayStack topApplication] :
            [workspace$ _applicationForBundleIdentifier:[workspace$.bksWorkspace topApplication] frontmost:YES];
    }
}

%hook SpringBoard

- (void)dealloc
{
    [prevDisplayId$ release];
    [currentDisplayId$ release];
    [displayStacks$ release];

    %orig();
}

%new
- (void)lastApp_switchToLastApp
{
    if (!canInvoke()) return;

    SBApplication *fromApp = topApplication();
    NSString *fromIdent;
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0_0) {
        fromIdent = [fromApp bundleIdentifier];
    } else {
        fromIdent = [fromApp displayIdentifier];
    }
    if (![fromIdent isEqualToString:prevDisplayId$]) {
        // App to switch to is not the current app
        SBApplication *toApp;
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0_0) {
            toApp = [(SBApplicationController *)[objc_getClass("SBApplicationController") sharedInstance]
                applicationWithBundleIdentifier:(fromIdent ? prevDisplayId$ : currentDisplayId$)];
        } else {
            toApp = [(SBApplicationController *)[objc_getClass("SBApplicationController") sharedInstance]
                applicationWithDisplayIdentifier:(fromIdent ? prevDisplayId$ : currentDisplayId$)];
        }

        if (toApp) {
            if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_6_0) {
                [toApp setDisplaySetting:0x4 flag:YES]; // animate

                if (fromIdent == nil) {
                    // Switching from SpringBoard; activate last "current" app
                    [SBWPreActivateDisplayStack pushDisplay:toApp];
                } else {
                    // Switching from another app; activate previously-active app
                    if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_4_0) {
                        // Firmware 3.x
                        [toApp setActivationSetting:0x40 flag:YES]; // animateOthersSuspension
                        [toApp setActivationSetting:0x20000 flag:YES]; // appToApp
                    } else {
                        // Firmware 4.x+
                        [toApp setActivationSetting:0x80 flag:YES]; // animateOthersSuspension
                        [toApp setActivationSetting:0x40000 flag:YES]; // appToApp
                    }

                    if (shouldBackground$) {
                        // If Backgrounder is installed, enable backgrounding for current application
                        if ([self respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)]) {
                            [self setBackgroundingEnabled:YES forDisplayIdentifier:fromIdent];
                        }
                    }

                    // NOTE: Must set animation flag for deactivation, otherwise
                    //       application window does not disappear (reason yet unknown)
                    [fromApp setDeactivationSetting:0x2 flag:YES]; // animate

                    // Activate the target application
                    // NOTE: will wait for deactivation of current app due to appToApp flag
                    [SBWPreActivateDisplayStack pushDisplay:toApp];

                    // Deactivate current application by moving from active to suspending stack
                    [SBWActiveDisplayStack popDisplay:fromApp];
                    [SBWSuspendingDisplayStack pushDisplay:fromApp];
                }
            } else if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0_0) {
                NSString *name = @"ActivateLastApp";
                FBWorkspaceEvent *event = [objc_getClass("FBWorkspaceEvent") eventWithName:name handler:^{
                    SBAlertManager *alertManager = workspace$.alertManager;
                    SBAppToAppWorkspaceTransaction *transaction = [objc_getClass("SBAppToAppWorkspaceTransaction") alloc];
                    transaction = [transaction initWithAlertManager:alertManager from:fromApp to:toApp withResult:nil];
                    [workspace$ setCurrentTransaction:transaction];
                    [transaction release];
                }];
                [(FBWorkspaceEventQueue *)[objc_getClass("FBWorkspaceEventQueue") sharedInstance] executeOrAppendEvent:event];
            } else {
                NSString *label = @"ActivateLastApp";
                SBWorkspaceEvent *event = [objc_getClass("SBWorkspaceEvent") eventWithLabel:label handler:^{
                    BKSWorkspace *workspace = [workspace$ bksWorkspace];
                    SBAlertManager *alertManager = workspace$.alertManager;
                    SBAppToAppWorkspaceTransaction *transaction = [objc_getClass("SBAppToAppWorkspaceTransaction") alloc];
                    if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0) {
                        transaction = [transaction initWithWorkspace:workspace alertManager:alertManager from:fromApp to:toApp];
                    } else {
                        transaction = [transaction initWithWorkspace:workspace alertManager:alertManager from:fromApp to:toApp activationHandler:nil];
                    }
                    [workspace$ setCurrentTransaction:transaction];
                    [transaction release];
                }];
                [(SBWorkspaceEventQueue *)[objc_getClass("SBWorkspaceEventQueue") sharedInstance] executeOrAppendEvent:event];
            }
        }
    }
}

%end

//==============================================================================

// DESC: Create an array to record the pointers to the display stacks.

%hook SpringBoard %group GFirmware_LT_60

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    // NOTE: SpringBoard creates four stacks at startup
    // NOTE: Must create array before calling original implementation
    displayStacks$ = [[NSMutableArray alloc] initWithCapacity:4];

    %orig();
}

%end %end

//==============================================================================

static void loadPreferences()
{
    shouldBackground$ = (BOOL)CFPreferencesGetAppBooleanValue(CFSTR("shouldBackground"), CFSTR(APP_ID), NULL);
}

static void reloadPreferences(CFNotificationCenterRef center, void *observer,
    CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    // NOTE: Must synchronize preferences from disk
    CFPreferencesAppSynchronize(CFSTR(APP_ID));
    loadPreferences();
}

__attribute__((constructor)) static void init()
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // NOTE: This library should only be loaded for SpringBoard
    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([identifier isEqualToString:@"com.apple.springboard"]) {
        // Initialize hooks
        %init;

        if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_6_0) {
            %init(GFirmware_LT_60);
        } else {
            %init(GFirmware_GTE_60);
        }

        if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0) {
            %init(GFirmware_LT_70);
        } else {
            %init(GFirmware_GTE_70);
        }

        // Load preferences
        loadPreferences();

        // Add observer for changes made to preferences
        CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL, reloadPreferences, CFSTR(APP_ID"-settings"),
                NULL, 0);

        // Create the libactivator event listener
        [LastAppActivator load];
    }

    [pool release];
}

/* vim: set ft=logos sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
