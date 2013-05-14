/**
 * Name: LastApp
 * Type: iPhone OS SpringBoard extension (MobileSubstrate-based)
 * Desc: Quickly switch to the previously-active application
 *
 * Author: Lance Fetters (aka. ashikase)
 * License: New BSD (See LICENSE file for details)
 *
 * Last-modified: 2013-02-14 23:58:57
 */

#import <libactivator/libactivator.h>

#ifndef kCFCoreFoundationVersionNumber_iOS_4_0
#define kCFCoreFoundationVersionNumber_iOS_4_0 550.32
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_6_0
#define kCFCoreFoundationVersionNumber_iOS_6_0 793.00
#endif

@interface SBDisplay : NSObject
- (void)setActivationSetting:(unsigned)setting flag:(BOOL)flag;
- (void)setDeactivationSetting:(unsigned)setting flag:(BOOL)flag;
- (void)setDisplaySetting:(unsigned)setting flag:(BOOL)flag;
@end

@interface SBApplication : SBDisplay
- (id)displayIdentifier;
@end

@interface SBAlert : SBDisplay @end

@interface SBApplicationController : NSObject
+ (id)sharedInstance;
- (id)applicationWithDisplayIdentifier:(id)displayIdentifier;
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
- (id)initWithWorkspace:(BKSWorkspace *)workspace alertManager:(SBAlertManager *)manager from:(SBApplication *)from to:(SBApplication *)to;
@end

@interface SBWorkspace : NSObject
@property(readonly, assign, nonatomic) SBAlertManager *alertManager;
@property(readonly, assign, nonatomic) BKSWorkspace *bksWorkspace;
@property(retain, nonatomic) SBWorkspaceTransaction *currentTransaction;
- (id)_applicationForBundleIdentifier:(id)bundleIdentifier frontmost:(BOOL)frontmost;
@end

@interface SBWorkspaceEvent : NSObject
+ (id)eventWithLabel:(NSString *)label handler:(void (^)(void))handler;
@end

@interface SBWorkspaceEventQueue : NSObject
+ (SBWorkspaceEventQueue *)sharedInstance;
- (void)executeOrAppendEvent:(SBWorkspaceEvent *)event;
@end


//==============================================================================

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

NSMutableArray *displayStacks$ = nil;

// Display stack names
#define SBWPreActivateDisplayStack        [displayStacks$ objectAtIndex:0]
#define SBWActiveDisplayStack             [displayStacks$ objectAtIndex:1]
#define SBWSuspendingDisplayStack         [displayStacks$ objectAtIndex:2]
#define SBWSuspendedEventOnlyDisplayStack [displayStacks$ objectAtIndex:3]

%hook SBDisplayStack %group GFirmware_LT_60

- (id)init
{
    id stack = %orig;
    [displayStacks$ addObject:stack];
    return stack;
}

- (void)dealloc
{
    [displayStacks$ removeObject:self];
    %orig;
}

%end %end

//==============================================================================

static SBWorkspace *workspace$ = nil;

%hook SBWorkspace %group GFirmware_GTE_60

- (id)init
{
    self = %orig;
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
    %orig;
}

%end %end

//==============================================================================

static BOOL shouldBackground$ = NO;

static NSString *currentDisplayId$ = nil;
static NSString *prevDisplayId$ = nil;

static BOOL canInvoke()
{
    // Should not invoke if either lock screen or power-off screen is active
    SBAwayController *awayCont = [%c(SBAwayController) sharedAwayController];
    return !([awayCont isLocked]
            || [awayCont isMakingEmergencyCall]
            || [(SBIconController *)[%c(SBIconController) sharedInstance] isEditing]
            || [(SBPowerDownController *)[%c(SBPowerDownController) sharedInstance] isOrderedFront]);
}

static inline SBApplication *topApplication()
{
    return (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_6_0) ?
        [SBWActiveDisplayStack topApplication] :
        [workspace$ _applicationForBundleIdentifier:[workspace$.bksWorkspace topApplication] frontmost:YES];
}

static inline NSString *topApplicationIdentifier()
{
    return (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_6_0) ?
        [[SBWActiveDisplayStack topApplication] displayIdentifier] :
        [workspace$.bksWorkspace topApplication];
}

%hook SpringBoard

- (void)dealloc
{
    [prevDisplayId$ release];
    [currentDisplayId$ release];
    [displayStacks$ release];

    %orig;
}

- (void)frontDisplayDidChange
{
    %orig;

    if ([[%c(SBAwayController) sharedAwayController] isLocked]
            || [(SBPowerDownController *)[%c(SBPowerDownController) sharedInstance] isOrderedFront]) {
            // Ignore lock screen and power-down screen
            return;
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

%new
- (void)lastApp_switchToLastApp
{
    if (!canInvoke()) return;

    SBApplication *fromApp = topApplication();
    NSString *fromIdent = [fromApp displayIdentifier];
    if (![fromIdent isEqualToString:prevDisplayId$]) {
        // App to switch to is not the current app
        SBApplication *toApp = [(SBApplicationController *)[%c(SBApplicationController) sharedInstance]
            applicationWithDisplayIdentifier:(fromIdent ? prevDisplayId$ : currentDisplayId$)];
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
            } else {
                NSString *label = [NSString stringWithFormat:@"ActivateApplication = %@", [toApp displayIdentifier]];
                SBWorkspaceEvent *workspaceEvent = [%c(SBWorkspaceEvent) eventWithLabel:label handler:^{
                    SBAlertManager *alertManager = workspace$.alertManager;
                    SBAppToAppWorkspaceTransaction *transaction = [[%c(SBAppToAppWorkspaceTransaction) alloc]
                        initWithWorkspace:workspace$.bksWorkspace alertManager:alertManager from:fromApp to:toApp];

                    [workspace$ setCurrentTransaction:transaction];

                    [transaction release];
                }];

                [(SBWorkspaceEventQueue *)[%c(SBWorkspaceEventQueue) sharedInstance] executeOrAppendEvent:workspaceEvent];
            }
        }
    }
}

%end

//==============================================================================

%hook SpringBoard %group GFirmware_LT_60

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    // NOTE: SpringBoard creates four stacks at startup
    // NOTE: Must create array before calling original implementation
    displayStacks$ = [[NSMutableArray alloc] initWithCapacity:4];

    %orig;
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
