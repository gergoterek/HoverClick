#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>
#import <os/log.h>
#if __has_include(<ServiceManagement/ServiceManagement.h>)
#import <ServiceManagement/ServiceManagement.h>
#define HOVERCLICK_HAS_SERVICE_MANAGEMENT 1
#else
#define HOVERCLICK_HAS_SERVICE_MANAGEMENT 0
#endif
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static NSString * const HoverClickBundleID = @"com.gergoterek.HoverClick";
static NSString * const HoverClickRightClickFocusDefaultsKey = @"rightClickFocusEnabled";
static NSString * const HoverClickHoverClickAssistDefaultsKey = @"hoverClickAssistEnabled";

static void HoverClickLog(const char *format, ...) {
    char buffer[1024];
    char output[1200];

    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    const char *message = buffer;
    static const char legacyPrefix[] = "HoverClick: ";
    static const char requiredPrefix[] = "[HoverClick]";
    if (strncmp(message, requiredPrefix, sizeof(requiredPrefix) - 1) == 0) {
        snprintf(output, sizeof(output), "%s", message);
    } else {
        if (strncmp(message, legacyPrefix, sizeof(legacyPrefix) - 1) == 0) {
            message += sizeof(legacyPrefix) - 1;
        }
        snprintf(output, sizeof(output), "%s %s", requiredPrefix, message);
    }

    printf("%s\n", output);
    fflush(stdout);
    os_log(OS_LOG_DEFAULT, "%{public}s", output);
}

static const char *HoverClickAXErrorName(AXError error) {
    switch (error) {
        case kAXErrorSuccess: return "success";
        case kAXErrorFailure: return "failure";
        case kAXErrorIllegalArgument: return "illegalArgument";
        case kAXErrorInvalidUIElement: return "invalidUIElement";
        case kAXErrorInvalidUIElementObserver: return "invalidUIElementObserver";
        case kAXErrorCannotComplete: return "cannotComplete";
        case kAXErrorAttributeUnsupported: return "attributeUnsupported";
        case kAXErrorActionUnsupported: return "actionUnsupported";
        case kAXErrorNotificationUnsupported: return "notificationUnsupported";
        case kAXErrorNotImplemented: return "notImplemented";
        case kAXErrorNotificationAlreadyRegistered: return "notificationAlreadyRegistered";
        case kAXErrorNotificationNotRegistered: return "notificationNotRegistered";
        case kAXErrorAPIDisabled: return "apiDisabled";
        case kAXErrorNoValue: return "noValue";
        case kAXErrorParameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported";
        case kAXErrorNotEnoughPrecision: return "notEnoughPrecision";
    }
    return "unknown";
}

@interface HoverClickAppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *permissionItem;
@property(nonatomic, strong) NSMenuItem *eventTapItem;
@property(nonatomic, strong) NSMenuItem *clickToFocusItem;
@property(nonatomic, strong) NSMenuItem *rightClickFocusItem;
@property(nonatomic, strong) NSMenuItem *hoverClickAssistItem;
@property(nonatomic, strong) NSMenuItem *launchAtLoginItem;
@property(nonatomic, strong) NSMenuItem *verboseItem;
@property(nonatomic, strong) NSMenuItem *lastClickItem;
- (void)handleEventTapDisabledWithReason:(NSString *)reason shouldReenable:(BOOL)shouldReenable;
- (void)handleLeftMouseDown:(CGEventRef)event;
- (void)handleRightMouseDown:(CGEventRef)event;
@end

@implementation HoverClickAppDelegate {
    BOOL _userWantsEventTap;
    BOOL _eventTapInstalled;
    BOOL _clickToFocusEnabled;
    BOOL _rightClickFocusEnabled;
    BOOL _hoverClickAssistEnabled;
    BOOL _verboseDiagnostics;
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _eventTapSource;
    CFAbsoluteTime _lastMouseDownLogTime;
    CFAbsoluteTime _lastRightMouseDownLogTime;
    uint64_t _clickSequence;
    NSString *_lastClickResult;
    NSString *_lastLaunchAtLoginStatusDescription;
}

static CGEventRef HoverClickEventTapCallback(CGEventTapProxy proxy,
                                             CGEventType type,
                                             CGEventRef event,
                                             void *refcon) {
    (void)proxy;

    HoverClickAppDelegate *controller = (__bridge HoverClickAppDelegate *)refcon;
    if (type == kCGEventTapDisabledByTimeout) {
        HoverClickLog("HoverClick: event tap disabled by timeout");
        [controller handleEventTapDisabledWithReason:@"timeout" shouldReenable:YES];
        return NULL;
    }

    if (type == kCGEventTapDisabledByUserInput) {
        HoverClickLog("HoverClick: event tap disabled by user input");
        [controller handleEventTapDisabledWithReason:@"user input" shouldReenable:YES];
        return NULL;
    }

    if (event == NULL) {
        return NULL;
    }

    if (type == kCGEventLeftMouseDown) {
        [controller handleLeftMouseDown:event];
    } else if (type == kCGEventRightMouseDown) {
        [controller handleRightMouseDown:event];
    }

    return event;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    _userWantsEventTap = YES;
    _eventTapInstalled = NO;
    _clickToFocusEnabled = YES;
    _rightClickFocusEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:HoverClickRightClickFocusDefaultsKey];
    _hoverClickAssistEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:HoverClickHoverClickAssistDefaultsKey];
    _verboseDiagnostics = YES;
    _eventTap = NULL;
    _eventTapSource = NULL;
    _lastMouseDownLogTime = 0;
    _lastRightMouseDownLogTime = 0;
    _clickSequence = 0;
    _lastClickResult = @"None";
    _lastLaunchAtLoginStatusDescription = nil;

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self createStatusItem];
    [self printLaunchStatus];
    [self refreshAccessibilityStatus:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self removeEventTap];
}

- (void)createStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    NSStatusBarButton *button = self.statusItem.button;
    if (@available(macOS 11.0, *)) {
        NSImage *image = [NSImage imageWithSystemSymbolName:@"cursorarrow.click"
                                  accessibilityDescription:@"HoverClick"];
        if (image != nil) {
            [image setTemplate:YES];
            button.image = image;
        } else {
            button.title = @"HC";
        }
    } else {
        button.title = @"HC";
    }

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"HoverClick"];
    [menu setAutoenablesItems:NO];

    self.permissionItem = [[NSMenuItem alloc] initWithTitle:@"Accessibility: Not Granted"
                                                     action:@selector(refreshAccessibilityStatus:)
                                              keyEquivalent:@""];
    self.permissionItem.target = self;
    self.permissionItem.enabled = YES;
    [menu addItem:self.permissionItem];

    self.eventTapItem = [[NSMenuItem alloc] initWithTitle:@"Event Tap: Disabled"
                                                   action:@selector(toggleEventTap:)
                                            keyEquivalent:@""];
    self.eventTapItem.target = self;
    self.eventTapItem.enabled = YES;
    [menu addItem:self.eventTapItem];

    [menu addItem:[NSMenuItem separatorItem]];

    self.clickToFocusItem = [[NSMenuItem alloc] initWithTitle:@"Left Click Focus: On"
                                                       action:@selector(toggleClickToFocus:)
                                                keyEquivalent:@""];
    self.clickToFocusItem.target = self;
    self.clickToFocusItem.enabled = YES;
    [menu addItem:self.clickToFocusItem];

    self.rightClickFocusItem = [[NSMenuItem alloc] initWithTitle:@"Right Click Focus"
                                                          action:@selector(toggleRightClickFocus:)
                                                   keyEquivalent:@""];
    self.rightClickFocusItem.target = self;
    self.rightClickFocusItem.enabled = YES;
    [menu addItem:self.rightClickFocusItem];

    self.hoverClickAssistItem = [[NSMenuItem alloc] initWithTitle:@"Experimental Hover Click Assist: Off"
                                                           action:@selector(toggleHoverClickAssist:)
                                                    keyEquivalent:@""];
    self.hoverClickAssistItem.target = self;
    self.hoverClickAssistItem.enabled = YES;
    [menu addItem:self.hoverClickAssistItem];

    self.launchAtLoginItem = [[NSMenuItem alloc] initWithTitle:@"Launch at Login"
                                                        action:@selector(toggleLaunchAtLogin:)
                                                 keyEquivalent:@""];
    self.launchAtLoginItem.target = self;
    self.launchAtLoginItem.enabled = YES;
    [menu addItem:self.launchAtLoginItem];

    self.verboseItem = [[NSMenuItem alloc] initWithTitle:@"Verbose Diagnostics: On"
                                                  action:@selector(toggleVerboseDiagnostics:)
                                           keyEquivalent:@""];
    self.verboseItem.target = self;
    self.verboseItem.enabled = YES;
    [menu addItem:self.verboseItem];

    self.lastClickItem = [[NSMenuItem alloc] initWithTitle:@"Last Click: None"
                                                    action:@selector(refreshAccessibilityStatus:)
                                             keyEquivalent:@""];
    self.lastClickItem.target = self;
    self.lastClickItem.enabled = YES;
    [menu addItem:self.lastClickItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Open Accessibility Settings"
                                                          action:@selector(openAccessibilitySettings:)
                                                   keyEquivalent:@""];
    settingsItem.target = self;
    settingsItem.enabled = YES;
    [menu addItem:settingsItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];
    quitItem.target = NSApp;
    quitItem.enabled = YES;
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
    [self updateMenuTitles];
}

- (void)printLaunchStatus {
    BOOL trusted = [self accessibilityTrusted];
    HoverClickLog("HoverClick: bundle id = %s", HoverClickBundleID.UTF8String);
    HoverClickLog("HoverClick: accessibility trusted = %s", trusted ? "YES" : "NO");
    HoverClickLog("HoverClick: launch state leftClickFocus=%s rightClickFocus=%s experimentalHoverClickAssist=%s rightClickDefaultsKey=%s hoverClickAssistDefaultsKey=%s",
                  _clickToFocusEnabled ? "ON" : "OFF",
                  _rightClickFocusEnabled ? "ON" : "OFF",
                  _hoverClickAssistEnabled ? "ON" : "OFF",
                  HoverClickRightClickFocusDefaultsKey.UTF8String,
                  HoverClickHoverClickAssistDefaultsKey.UTF8String);
}

- (void)logLaunchAtLoginStatus:(NSString *)statusDescription force:(BOOL)force {
    if (statusDescription == nil) {
        statusDescription = @"unknown";
    }

    if (!force &&
        _lastLaunchAtLoginStatusDescription != nil &&
        [_lastLaunchAtLoginStatusDescription isEqualToString:statusDescription]) {
        return;
    }

    _lastLaunchAtLoginStatusDescription = [statusDescription copy];
    HoverClickLog("HoverClick: Launch at Login status = %s", statusDescription.UTF8String);
}

- (void)logLaunchAtLoginErrorForOperation:(NSString *)operation error:(NSError *)error {
    NSString *domain = error.domain ?: @"unknown";
    NSString *description = error.localizedDescription ?: @"unknown";
    NSLog(@"[HoverClick] Launch at Login %@ failed domain=%@ code=%ld description=%@",
          operation ?: @"operation",
          domain,
          (long)error.code,
          description);
}

#if HOVERCLICK_HAS_SERVICE_MANAGEMENT
- (NSString *)launchAtLoginStatusDescription:(SMAppServiceStatus)status {
    if (@available(macOS 13.0, *)) {
        switch (status) {
            case SMAppServiceStatusNotRegistered:
                return @"not registered";
            case SMAppServiceStatusEnabled:
                return @"enabled";
            case SMAppServiceStatusRequiresApproval:
                return @"requires approval";
            case SMAppServiceStatusNotFound:
                return @"not found";
        }
    }

    return @"unavailable";
}
#endif

- (void)updateLaunchAtLoginMenuItem {
    if (self.launchAtLoginItem == nil) {
        return;
    }

    self.launchAtLoginItem.title = @"Launch at Login";

#if HOVERCLICK_HAS_SERVICE_MANAGEMENT
    if (@available(macOS 13.0, *)) {
        SMAppService *service = SMAppService.mainAppService;
        SMAppServiceStatus status = service.status;
        NSString *statusDescription = [self launchAtLoginStatusDescription:status];

        self.launchAtLoginItem.enabled = YES;
        self.launchAtLoginItem.toolTip = [NSString stringWithFormat:@"ServiceManagement status: %@", statusDescription];

        switch (status) {
            case SMAppServiceStatusEnabled:
                self.launchAtLoginItem.state = NSControlStateValueOn;
                break;
            case SMAppServiceStatusRequiresApproval:
                self.launchAtLoginItem.state = NSControlStateValueMixed;
                break;
            case SMAppServiceStatusNotRegistered:
            case SMAppServiceStatusNotFound:
                self.launchAtLoginItem.state = NSControlStateValueOff;
                break;
        }

        [self logLaunchAtLoginStatus:statusDescription force:NO];
        return;
    }
#endif

    self.launchAtLoginItem.enabled = NO;
    self.launchAtLoginItem.state = NSControlStateValueOff;
    self.launchAtLoginItem.toolTip = @"Launch at Login requires macOS 13 or later.";
    [self logLaunchAtLoginStatus:@"unavailable on this macOS version" force:NO];
}

- (BOOL)accessibilityTrusted {
    return AXIsProcessTrusted();
}

- (void)refreshAccessibilityStatus:(id)sender {
    (void)sender;

    BOOL trusted = [self accessibilityTrusted];
    HoverClickLog("HoverClick: accessibility trusted = %s", trusted ? "YES" : "NO");

    if (trusted) {
        if (_userWantsEventTap) {
            [self installEventTap];
        }
    } else {
        [self removeEventTap];
        if (_userWantsEventTap) {
            HoverClickLog("HoverClick: event tap permission missing. Check Accessibility permission.");
            [self setLastClickResult:@"Permission Missing"];
        }
    }

    [self updateMenuTitles];
}

- (BOOL)installEventTap {
    if (![self accessibilityTrusted]) {
        [self updateMenuTitles];
        return NO;
    }

    if (_eventTapInstalled && _eventTap != NULL && _eventTapSource != NULL) {
        HoverClickLog("HoverClick: event tap already installed; skipping duplicate install");
        [self updateMenuTitles];
        return YES;
    }

    if (_eventTap != NULL || _eventTapSource != NULL) {
        [self removeEventTap];
    }

    CGEventMask mask = CGEventMaskBit(kCGEventLeftMouseDown) |
                       CGEventMaskBit(kCGEventRightMouseDown);
    HoverClickLog("HoverClick: event tap mask=0x%llx leftMouseDown=YES rightMouseDown=YES mouseMoved=NO scroll=NO",
                  (unsigned long long)mask);
    _eventTap = CGEventTapCreate(kCGHIDEventTap,
                                 kCGHeadInsertEventTap,
                                 kCGEventTapOptionDefault,
                                 mask,
                                 HoverClickEventTapCallback,
                                 (__bridge void *)self);
    if (_eventTap == NULL) {
        _eventTapInstalled = NO;
        HoverClickLog("HoverClick: failed to create event tap. Check Accessibility permission.");
        [self setLastClickResult:@"Event Tap Create Failed"];
        [self updateMenuTitles];
        return NO;
    }

    _eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    if (_eventTapSource == NULL) {
        CFRelease(_eventTap);
        _eventTap = NULL;
        _eventTapInstalled = NO;
        HoverClickLog("HoverClick: failed to create event tap source.");
        [self setLastClickResult:@"Event Tap Source Failed"];
        [self updateMenuTitles];
        return NO;
    }

    CFRunLoopAddSource(CFRunLoopGetCurrent(), _eventTapSource, kCFRunLoopCommonModes);
    CGEventTapEnable(_eventTap, true);
    _eventTapInstalled = CGEventTapIsEnabled(_eventTap);

    HoverClickLog("HoverClick: event tap installed mode=pass-through-default");
    [self updateMenuTitles];
    return _eventTapInstalled;
}

- (void)removeEventTap {
    if (_eventTap == NULL && _eventTapSource == NULL && !_eventTapInstalled) {
        HoverClickLog("HoverClick: event tap remove requested but no active tap");
        [self updateMenuTitles];
        return;
    }

    if (_eventTap != NULL) {
        CGEventTapEnable(_eventTap, false);
    }

    if (_eventTapSource != NULL) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _eventTapSource, kCFRunLoopCommonModes);
        CFRelease(_eventTapSource);
        _eventTapSource = NULL;
    }

    if (_eventTap != NULL) {
        CFRelease(_eventTap);
        _eventTap = NULL;
    }

    if (_eventTapInstalled) {
        HoverClickLog("HoverClick: event tap removed");
    }

    _eventTapInstalled = NO;
    [self updateMenuTitles];
}

- (void)handleEventTapDisabledWithReason:(NSString *)reason shouldReenable:(BOOL)shouldReenable {
    _eventTapInstalled = NO;
    [self updateMenuTitles];

    if (!_userWantsEventTap) {
        HoverClickLog("HoverClick: event tap disabled by %s; user disabled tap, not re-enabling", reason.UTF8String);
        return;
    }

    if (![self accessibilityTrusted]) {
        [self removeEventTap];
        return;
    }

    if (!shouldReenable) {
        HoverClickLog("HoverClick: event tap disabled by %s; not re-enabling", reason.UTF8String);
        return;
    }

    if (_eventTap != NULL) {
        CGEventTapEnable(_eventTap, true);
        _eventTapInstalled = CGEventTapIsEnabled(_eventTap);
        HoverClickLog("HoverClick: event tap re-enabled after %s", reason.UTF8String);
        [self updateMenuTitles];
        return;
    }

    [self installEventTap];
}

- (void)toggleEventTap:(id)sender {
    (void)sender;

    if (_eventTapInstalled) {
        _userWantsEventTap = NO;
        [self removeEventTap];
        [self setLastClickResult:@"Event Tap Disabled"];
        return;
    }

    _userWantsEventTap = YES;
    if (![self accessibilityTrusted]) {
        HoverClickLog("HoverClick: event tap permission missing. Check Accessibility permission.");
        [self setLastClickResult:@"Permission Missing"];
        [self updateMenuTitles];
        return;
    }

    [self installEventTap];
}

- (void)toggleClickToFocus:(id)sender {
    (void)sender;
    _clickToFocusEnabled = !_clickToFocusEnabled;
    HoverClickLog("HoverClick: left click focus %s", _clickToFocusEnabled ? "enabled" : "disabled");
    [self setLastClickResult:_clickToFocusEnabled ? @"Left Click Focus Enabled" : @"Left Click Focus Disabled"];
    [self updateMenuTitles];
}

- (void)toggleRightClickFocus:(id)sender {
    (void)sender;
    _rightClickFocusEnabled = !_rightClickFocusEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:_rightClickFocusEnabled forKey:HoverClickRightClickFocusDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    HoverClickLog("HoverClick: right click focus %s", _rightClickFocusEnabled ? "enabled" : "disabled");
    [self setLastClickResult:_rightClickFocusEnabled ? @"Right Click Focus Enabled" : @"Right Click Focus Disabled"];
    [self updateMenuTitles];
}

- (void)toggleHoverClickAssist:(id)sender {
    (void)sender;
    _hoverClickAssistEnabled = !_hoverClickAssistEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:_hoverClickAssistEnabled forKey:HoverClickHoverClickAssistDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    HoverClickLog("HoverClick: Experimental Hover Click Assist %s", _hoverClickAssistEnabled ? "enabled" : "disabled");
    HoverClickLog("HoverClick: Experimental Hover Click Assist %s: no assist path scheduled",
                  _hoverClickAssistEnabled ? "ON" : "OFF");
    [self setLastClickResult:_hoverClickAssistEnabled ? @"Experimental Assist Enabled" : @"Experimental Assist Disabled"];
    [self updateMenuTitles];
}

- (void)toggleLaunchAtLogin:(id)sender {
    (void)sender;

#if HOVERCLICK_HAS_SERVICE_MANAGEMENT
    if (@available(macOS 13.0, *)) {
        SMAppService *service = SMAppService.mainAppService;
        SMAppServiceStatus status = service.status;
        NSString *statusDescription = [self launchAtLoginStatusDescription:status];
        NSError *error = nil;

        HoverClickLog("HoverClick: Launch at Login toggle requested currentStatus=%s", statusDescription.UTF8String);

        if (status == SMAppServiceStatusEnabled || status == SMAppServiceStatusRequiresApproval) {
            if ([service unregisterAndReturnError:&error]) {
                HoverClickLog("HoverClick: Launch at Login unregister succeeded");
            } else {
                [self logLaunchAtLoginErrorForOperation:@"unregister" error:error];
            }
        } else {
            if ([service registerAndReturnError:&error]) {
                HoverClickLog("HoverClick: Launch at Login register succeeded");
            } else {
                [self logLaunchAtLoginErrorForOperation:@"register" error:error];
            }
        }

        [self updateMenuTitles];
        return;
    }
#endif

    HoverClickLog("HoverClick: Launch at Login unavailable; requires macOS 13 or later");
    [self updateMenuTitles];
}

- (void)toggleVerboseDiagnostics:(id)sender {
    (void)sender;
    _verboseDiagnostics = !_verboseDiagnostics;
    HoverClickLog("HoverClick: verbose diagnostics %s", _verboseDiagnostics ? "enabled" : "disabled");
    [self updateMenuTitles];
}

- (void)updateMenuTitles {
    BOOL trusted = [self accessibilityTrusted];
    self.permissionItem.title = trusted ? @"Accessibility: Granted" : @"Accessibility: Missing";

    if (!trusted && _userWantsEventTap) {
        self.eventTapItem.title = @"Event Tap: Permission Missing";
    } else if (_eventTapInstalled && _eventTap != NULL) {
        self.eventTapItem.title = @"Event Tap: Enabled";
    } else {
        self.eventTapItem.title = @"Event Tap: Disabled";
    }

    self.clickToFocusItem.title = _clickToFocusEnabled ? @"Left Click Focus: On" : @"Left Click Focus: Off";
    self.rightClickFocusItem.title = @"Right Click Focus";
    self.rightClickFocusItem.state = _rightClickFocusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.hoverClickAssistItem.title = _hoverClickAssistEnabled ? @"Experimental Hover Click Assist: On" : @"Experimental Hover Click Assist: Off";
    [self updateLaunchAtLoginMenuItem];
    self.verboseItem.title = _verboseDiagnostics ? @"Verbose Diagnostics: On" : @"Verbose Diagnostics: Off";

    NSString *result = _lastClickResult ?: @"None";
    if (result.length > 48) {
        result = [[result substringToIndex:45] stringByAppendingString:@"..."];
    }
    self.lastClickItem.title = [NSString stringWithFormat:@"Last Click: %@", result];
}

- (void)setLastClickResult:(NSString *)result {
    _lastClickResult = result ?: @"None";
    [self updateMenuTitles];
}

- (void)diagnosticLog:(const char *)format, ... {
    if (!_verboseDiagnostics) {
        return;
    }

    char buffer[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    HoverClickLog("%s", buffer);
}

- (void)handleLeftMouseDown:(CGEventRef)event {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - _lastMouseDownLogTime < 0.02) {
        return;
    }
    _lastMouseDownLogTime = now;
    _clickSequence++;
    uint64_t clickID = _clickSequence;

    CGPoint rawPoint = CGEventGetLocation(event);
    CGPoint axPoint = [self accessibilityPointForEventPoint:rawPoint];
    [self diagnosticLog:"HoverClick: click #%llu received leftClickFocus=%s experimentalHoverClickAssist=%s raw=(%.1f,%.1f) converted=(%.1f,%.1f)",
                        clickID,
                        _clickToFocusEnabled ? "ON" : "OFF",
                        _hoverClickAssistEnabled ? "ON" : "OFF",
                        rawPoint.x,
                        rawPoint.y,
                        axPoint.x,
                        axPoint.y];

    if (!_clickToFocusEnabled) {
        HoverClickLog("HoverClick: click #%llu left click focus disabled; event passed through", clickID);
        [self setLastClickResult:@"Disabled"];
        return;
    }

    AXUIElementRef element = [self copyElementAtAccessibilityPoint:axPoint];
    if (element == NULL) {
        HoverClickLog("HoverClick: click #%llu AX element not found at x=%.1f, y=%.1f; event passed through", clickID, axPoint.x, axPoint.y);
        [self setLastClickResult:@"No AX Element"];
        return;
    }

    [self handleResolvedElement:element rawPoint:rawPoint axPoint:axPoint clickID:clickID];
    CFRelease(element);
}

- (void)handleRightMouseDown:(CGEventRef)event {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - _lastRightMouseDownLogTime < 0.02) {
        return;
    }
    _lastRightMouseDownLogTime = now;
    _clickSequence++;
    uint64_t clickID = _clickSequence;

    CGPoint rawPoint = CGEventGetLocation(event);
    CGPoint axPoint = [self accessibilityPointForEventPoint:rawPoint];
    [self diagnosticLog:"HoverClick: right-click #%llu received rightClickFocus=%s leftClickFocus=%s experimentalHoverClickAssist=%s raw=(%.1f,%.1f) converted=(%.1f,%.1f)",
                        clickID,
                        _rightClickFocusEnabled ? "ON" : "OFF",
                        _clickToFocusEnabled ? "ON" : "OFF",
                        _hoverClickAssistEnabled ? "ON" : "OFF",
                        rawPoint.x,
                        rawPoint.y,
                        axPoint.x,
                        axPoint.y];

    if (!_rightClickFocusEnabled) {
        HoverClickLog("HoverClick: right-click #%llu right click focus disabled; event passed through", clickID);
        [self setLastClickResult:@"Right Click Disabled"];
        return;
    }

    AXUIElementRef element = [self copyElementAtAccessibilityPoint:axPoint];
    if (element == NULL) {
        HoverClickLog("HoverClick: right-click #%llu AX element not found at x=%.1f, y=%.1f; event passed through", clickID, axPoint.x, axPoint.y);
        [self setLastClickResult:@"No AX Element"];
        return;
    }

    [self handleResolvedElement:element rawPoint:rawPoint axPoint:axPoint sequenceID:clickID trigger:"right-click"];
    CFRelease(element);
}

- (CGPoint)accessibilityPointForEventPoint:(CGPoint)eventPoint {
    return eventPoint;
}

- (AXUIElementRef)copyElementAtAccessibilityPoint:(CGPoint)point {
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    if (systemWide == NULL) {
        HoverClickLog("HoverClick: failed to create system-wide AX element");
        return NULL;
    }

    AXUIElementRef element = NULL;
    AXError error = AXUIElementCopyElementAtPosition(systemWide,
                                                     (float)point.x,
                                                     (float)point.y,
                                                     &element);
    CFRelease(systemWide);

    if (error != kAXErrorSuccess || element == NULL) {
        [self diagnosticLog:"HoverClick: AXUIElementCopyElementAtPosition failed error=%s", HoverClickAXErrorName(error)];
        return NULL;
    }

    return element;
}

- (void)handleResolvedElement:(AXUIElementRef)element rawPoint:(CGPoint)rawPoint axPoint:(CGPoint)axPoint clickID:(uint64_t)clickID {
    [self handleResolvedElement:element rawPoint:rawPoint axPoint:axPoint sequenceID:clickID trigger:"click"];
}

- (void)handleResolvedElement:(AXUIElementRef)element rawPoint:(CGPoint)rawPoint axPoint:(CGPoint)axPoint sequenceID:(uint64_t)sequenceID trigger:(const char *)trigger {
    NSString *role = [self stringAttribute:kAXRoleAttribute fromElement:element] ?: @"unknown";
    NSString *elementTitle = [self stringAttribute:kAXTitleAttribute fromElement:element] ?: @"";
    [self diagnosticLog:"HoverClick: %s #%llu AX element found role=%s title=%s",
                        trigger,
                        sequenceID,
                        role.UTF8String,
                        elementTitle.UTF8String];

    pid_t targetPid = 0;
    AXError pidError = AXUIElementGetPid(element, &targetPid);
    if (pidError != kAXErrorSuccess || targetPid <= 0) {
        HoverClickLog("HoverClick: %s #%llu target pid unresolved error=%s; event passed through", trigger, sequenceID, HoverClickAXErrorName(pidError));
        [self setLastClickResult:@"No Target PID"];
        return;
    }

    NSRunningApplication *targetApp = [NSRunningApplication runningApplicationWithProcessIdentifier:targetPid];
    if (targetApp == nil) {
        HoverClickLog("HoverClick: %s #%llu target app unresolved pid=%d; event passed through", trigger, sequenceID, targetPid);
        [self setLastClickResult:@"No Target App"];
        return;
    }

    NSString *appName = targetApp.localizedName ?: [NSString stringWithFormat:@"pid %d", targetPid];
    HoverClickLog("HoverClick: %s #%llu target pid=%d app=%s", trigger, sequenceID, targetPid, appName.UTF8String);

    if (targetPid == getpid()) {
        HoverClickLog("HoverClick: %s #%llu ignored reason=own-app; event passed through", trigger, sequenceID);
        [self setLastClickResult:@"Ignored Own App"];
        return;
    }

    if ([self shouldIgnoreRole:role appName:appName targetPid:targetPid point:axPoint]) {
        HoverClickLog("HoverClick: %s #%llu ignored reason=menu-role role=%s app=%s; event passed through", trigger, sequenceID, role.UTF8String, appName.UTF8String);
        [self setLastClickResult:@"Ignored Menu/UI"];
        return;
    }

    AXUIElementRef targetWindow = [self copyWindowForElement:element];
    if (targetWindow == NULL) {
        HoverClickLog("HoverClick: %s #%llu AX window not found for pid=%d app=%s; event passed through", trigger, sequenceID, targetPid, appName.UTF8String);
        [self setLastClickResult:@"No Target Window"];
        return;
    }

    NSString *windowRole = [self stringAttribute:kAXRoleAttribute fromElement:targetWindow] ?: @"unknown";
    NSString *windowTitle = [self stringAttribute:kAXTitleAttribute fromElement:targetWindow] ?: @"";
    HoverClickLog("HoverClick: %s #%llu target window role=%s title=%s", trigger, sequenceID, windowRole.UTF8String, windowTitle.UTF8String);

    if ([self shouldIgnoreWindowRole:windowRole targetPid:targetPid]) {
        HoverClickLog("HoverClick: %s #%llu ignored reason=transient-window role=%s app=%s; event passed through", trigger, sequenceID, windowRole.UTF8String, appName.UTF8String);
        [self setLastClickResult:@"Ignored Transient UI"];
        CFRelease(targetWindow);
        return;
    }

    [self focusTargetApp:targetApp
                     pid:targetPid
                 appName:appName
                  window:targetWindow
                 rawPoint:rawPoint
                  axPoint:axPoint
              sequenceID:sequenceID
                 trigger:trigger];
    CFRelease(targetWindow);
}

- (BOOL)shouldIgnoreRole:(NSString *)role appName:(NSString *)appName targetPid:(pid_t)targetPid point:(CGPoint)point {
    (void)point;
    (void)targetPid;

    if ([role rangeOfString:@"Menu" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    }

    if ([role isEqualToString:@"AXStatusItem"] ||
        [role isEqualToString:@"AXSystemWide"] ||
        [role isEqualToString:@"AXPopover"]) {
        return YES;
    }

    if ([appName isEqualToString:@"HoverClick"]) {
        return YES;
    }

    return NO;
}

- (BOOL)shouldIgnoreWindowRole:(NSString *)role targetPid:(pid_t)targetPid {
    NSRunningApplication *frontApp = [NSWorkspace sharedWorkspace].frontmostApplication;
    BOOL belongsToFrontApp = frontApp != nil && frontApp.processIdentifier == targetPid;

    if (([role isEqualToString:@"AXSheet"] || [role isEqualToString:@"AXDialog"]) && belongsToFrontApp) {
        return YES;
    }

    return NO;
}

- (void)focusTargetApp:(NSRunningApplication *)targetApp
                   pid:(pid_t)targetPid
               appName:(NSString *)appName
                window:(AXUIElementRef)targetWindow
               rawPoint:(CGPoint)rawPoint
                axPoint:(CGPoint)axPoint
            sequenceID:(uint64_t)sequenceID
               trigger:(const char *)trigger {
    (void)rawPoint;
    (void)axPoint;

    NSRunningApplication *frontBefore = [NSWorkspace sharedWorkspace].frontmostApplication;
    pid_t frontBeforePid = frontBefore.processIdentifier;
    NSString *frontBeforeName = frontBefore.localizedName ?: @"unknown";

    if (frontBeforePid == targetPid) {
        HoverClickLog("HoverClick: %s #%llu ignored reason=already-frontmost pid=%d app=%s; event passed through", trigger, sequenceID, targetPid, appName.UTF8String);
        [self setLastClickResult:@"Already Frontmost"];
        return;
    }

    HoverClickLog("HoverClick: %s #%llu %s-to-focus started target=%s pid=%d frontBefore=%s pid=%d",
                  trigger,
                  sequenceID,
                  trigger,
                  appName.UTF8String,
                  targetPid,
                  frontBeforeName.UTF8String,
                  frontBeforePid);

    BOOL activateAttempted = targetApp != nil;
    BOOL activateResult = NO;
    if (targetApp != nil) {
        activateResult = [targetApp activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    }
    HoverClickLog("HoverClick: %s #%llu app activation attempted=%s result=%s",
                  trigger,
                  sequenceID,
                  activateAttempted ? "YES" : "NO",
                  activateResult ? "YES" : "NO");

    AXUIElementRef appElement = AXUIElementCreateApplication(targetPid);
    AXError frontmostError = kAXErrorIllegalArgument;
    AXError focusedWindowError = kAXErrorIllegalArgument;
    AXError mainWindowError = kAXErrorIllegalArgument;
    AXError focusedAttrError = kAXErrorIllegalArgument;
    if (appElement != NULL) {
        frontmostError = AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute, kCFBooleanTrue);
        focusedWindowError = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute, targetWindow);
        CFRelease(appElement);
    }

    HoverClickLog("HoverClick: %s #%llu AX frontmost set %s", trigger, sequenceID, HoverClickAXErrorName(frontmostError));

    AXError raiseError = AXUIElementPerformAction(targetWindow, kAXRaiseAction);
    HoverClickLog("HoverClick: %s #%llu AXRaise %s", trigger, sequenceID, HoverClickAXErrorName(raiseError));

    mainWindowError = AXUIElementSetAttributeValue(targetWindow, kAXMainAttribute, kCFBooleanTrue);
    focusedAttrError = AXUIElementSetAttributeValue(targetWindow, kAXFocusedAttribute, kCFBooleanTrue);

    HoverClickLog("HoverClick: %s #%llu AX focusedWindow set %s", trigger, sequenceID, HoverClickAXErrorName(focusedWindowError));
    [self diagnosticLog:"HoverClick: %s #%llu AX mainWindow set %s", trigger, sequenceID, HoverClickAXErrorName(mainWindowError)];
    [self diagnosticLog:"HoverClick: %s #%llu AX focused attribute set %s", trigger, sequenceID, HoverClickAXErrorName(focusedAttrError)];

    NSRunningApplication *frontAfter = [NSWorkspace sharedWorkspace].frontmostApplication;
    BOOL frontImmediate = frontAfter.processIdentifier == targetPid;
    HoverClickLog("HoverClick: %s #%llu %s-to-focus immediate verify frontApp=%s current=%s pid=%d",
                  trigger,
                  sequenceID,
                  trigger,
                  frontImmediate ? "YES" : "NO",
                  (frontAfter.localizedName ?: @"unknown").UTF8String,
                  frontAfter.processIdentifier);

    [self setLastClickResult:frontImmediate ? @"Succeeded" : @"Verify Failed"];
    HoverClickLog("HoverClick: %s #%llu event passed through", trigger, sequenceID);

    if (!_hoverClickAssistEnabled) {
        HoverClickLog("HoverClick: Experimental Hover Click Assist OFF: no assist path scheduled");
        return;
    }

    HoverClickLog("HoverClick: Experimental Hover Click Assist ON: placeholder no-op; no assist path scheduled");
}

- (AXUIElementRef)copyWindowForElement:(AXUIElementRef)element {
    AXUIElementRef current = (AXUIElementRef)CFRetain(element);

    for (NSInteger depth = 0; depth < 10 && current != NULL; depth++) {
        NSString *role = [self stringAttribute:kAXRoleAttribute fromElement:current] ?: @"unknown";
        [self diagnosticLog:"HoverClick: window search depth=%ld role=%s", (long)depth, role.UTF8String];

        if ([self roleLooksLikeWindow:role]) {
            return current;
        }

        CFTypeRef windowValue = NULL;
        AXError windowError = AXUIElementCopyAttributeValue(current, kAXWindowAttribute, &windowValue);
        if (windowError == kAXErrorSuccess && windowValue != NULL) {
            if (CFGetTypeID(windowValue) == AXUIElementGetTypeID()) {
                CFRelease(current);
                return (AXUIElementRef)windowValue;
            }
            CFRelease(windowValue);
        }

        CFTypeRef parentValue = NULL;
        AXError parentError = AXUIElementCopyAttributeValue(current, kAXParentAttribute, &parentValue);
        if (parentError != kAXErrorSuccess || parentValue == NULL) {
            [self diagnosticLog:"HoverClick: window search stopped depth=%ld parentError=%s",
                                (long)depth,
                                HoverClickAXErrorName(parentError)];
            CFRelease(current);
            return NULL;
        }

        if (CFGetTypeID(parentValue) != AXUIElementGetTypeID()) {
            CFRelease(parentValue);
            CFRelease(current);
            return NULL;
        }

        CFRelease(current);
        current = (AXUIElementRef)parentValue;
    }

    if (current != NULL) {
        CFRelease(current);
    }
    return NULL;
}

- (BOOL)roleLooksLikeWindow:(NSString *)role {
    return [role isEqualToString:(__bridge NSString *)kAXWindowRole] ||
           [role isEqualToString:@"AXDialog"] ||
           [role isEqualToString:@"AXSheet"];
}

- (NSString *)stringAttribute:(CFStringRef)attribute fromElement:(AXUIElementRef)element {
    if (element == NULL) {
        return nil;
    }

    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
    if (error != kAXErrorSuccess || value == NULL) {
        return nil;
    }

    NSString *result = nil;
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        result = [(__bridge NSString *)value copy];
    } else if (CFGetTypeID(value) == CFAttributedStringGetTypeID()) {
        result = [(__bridge NSAttributedString *)value string];
    }

    CFRelease(value);
    return result;
}

- (void)openAccessibilitySettings:(id)sender {
    (void)sender;

    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    if (url != nil) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

@end

int main(int argc, const char * argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        HoverClickAppDelegate *delegate = [[HoverClickAppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }

    return 0;
}
