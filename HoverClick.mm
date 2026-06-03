#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>
#import <os/log.h>
#include <stdarg.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static NSString * const HoverClickBundleID = @"com.gergoterek.HoverClick";
static NSString * const HoverClickHoverFocusDefaultsKey = @"HoverFocusEnabled";
static const CFTimeInterval HoverClickHoverDelaySeconds = 0.25;
static const CFTimeInterval HoverClickHoverRepeatIntervalSeconds = 0.75;
static const CGFloat HoverClickHoverMovementTolerance = 6.0;

static void HoverClickLog(const char *format, ...) {
    char buffer[1024];

    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    printf("%s\n", buffer);
    fflush(stdout);
    os_log(OS_LOG_DEFAULT, "%{public}s", buffer);
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
@property(nonatomic, strong) NSMenuItem *hoverFocusItem;
@property(nonatomic, strong) NSMenuItem *clickToFocusItem;
@property(nonatomic, strong) NSMenuItem *verboseItem;
@property(nonatomic, strong) NSMenuItem *lastClickItem;
- (void)handleEventTapDisabledWithReason:(NSString *)reason shouldReenable:(BOOL)shouldReenable;
- (void)handleLeftMouseDown:(CGEventRef)event;
- (void)handleMouseMoved:(CGEventRef)event;
@end

@implementation HoverClickAppDelegate {
    BOOL _userWantsEventTap;
    BOOL _eventTapInstalled;
    BOOL _clickToFocusEnabled;
    BOOL _hoverFocusEnabled;
    BOOL _verboseDiagnostics;
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _eventTapSource;
    CFAbsoluteTime _lastMouseDownLogTime;
    uint64_t _clickSequence;
    uint64_t _hoverSequence;
    uint64_t _hoverGeneration;
    uint64_t _latestVerificationSequence;
    NSUInteger _pendingDelayedVerifications;
    BOOL _hasLatestHoverPoint;
    CGPoint _latestHoverPoint;
    NSString *_lastHoverTargetKey;
    CFAbsoluteTime _lastHoverFocusTime;
    NSString *_lastClickResult;
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
    } else if (type == kCGEventMouseMoved) {
        [controller handleMouseMoved:event];
    }

    return event;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    _userWantsEventTap = YES;
    _eventTapInstalled = NO;
    _clickToFocusEnabled = YES;
    _hoverFocusEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:HoverClickHoverFocusDefaultsKey];
    _verboseDiagnostics = YES;
    _eventTap = NULL;
    _eventTapSource = NULL;
    _lastMouseDownLogTime = 0;
    _clickSequence = 0;
    _hoverSequence = 0;
    _hoverGeneration = 0;
    _latestVerificationSequence = 0;
    _pendingDelayedVerifications = 0;
    _hasLatestHoverPoint = NO;
    _latestHoverPoint = CGPointZero;
    _lastHoverTargetKey = nil;
    _lastHoverFocusTime = 0;
    _lastClickResult = @"None";

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

    self.hoverFocusItem = [[NSMenuItem alloc] initWithTitle:@"Hover Focus: Off"
                                                     action:@selector(toggleHoverFocus:)
                                              keyEquivalent:@""];
    self.hoverFocusItem.target = self;
    self.hoverFocusItem.enabled = YES;
    [menu addItem:self.hoverFocusItem];

    self.clickToFocusItem = [[NSMenuItem alloc] initWithTitle:@"Click-to-Focus: Enabled"
                                                       action:@selector(toggleClickToFocus:)
                                                keyEquivalent:@""];
    self.clickToFocusItem.target = self;
    self.clickToFocusItem.enabled = YES;
    [menu addItem:self.clickToFocusItem];

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

    CGEventMask mask = CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventMouseMoved);
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
        _hoverGeneration++;
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
    _hoverGeneration++;
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

- (void)toggleHoverFocus:(id)sender {
    (void)sender;
    _hoverFocusEnabled = !_hoverFocusEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:_hoverFocusEnabled forKey:HoverClickHoverFocusDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (!_hoverFocusEnabled) {
        _hoverGeneration++;
        _hasLatestHoverPoint = NO;
    }

    HoverClickLog("HoverClick: hover focus %s", _hoverFocusEnabled ? "enabled" : "disabled");
    [self updateMenuTitles];
}

- (void)toggleClickToFocus:(id)sender {
    (void)sender;
    _clickToFocusEnabled = !_clickToFocusEnabled;
    HoverClickLog("HoverClick: click-to-focus %s", _clickToFocusEnabled ? "enabled" : "disabled");
    [self setLastClickResult:_clickToFocusEnabled ? @"Click-to-Focus Enabled" : @"Click-to-Focus Disabled"];
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

    self.hoverFocusItem.title = _hoverFocusEnabled ? @"Hover Focus: On" : @"Hover Focus: Off";
    self.clickToFocusItem.title = _clickToFocusEnabled ? @"Click-to-Focus: Enabled" : @"Click-to-Focus: Disabled";
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
    [self diagnosticLog:"HoverClick: click #%llu received raw=(%.1f,%.1f) converted=(%.1f,%.1f)",
                        clickID,
                        rawPoint.x,
                        rawPoint.y,
                        axPoint.x,
                        axPoint.y];

    if (!_clickToFocusEnabled) {
        HoverClickLog("HoverClick: click #%llu click-to-focus disabled; event passed through", clickID);
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

- (void)handleMouseMoved:(CGEventRef)event {
    if (!_hoverFocusEnabled || !_eventTapInstalled || event == NULL) {
        return;
    }

    CGPoint rawPoint = CGEventGetLocation(event);
    if (_hasLatestHoverPoint && [self distanceFromPoint:rawPoint toPoint:_latestHoverPoint] < HoverClickHoverMovementTolerance) {
        return;
    }

    _hasLatestHoverPoint = YES;
    _latestHoverPoint = rawPoint;
    _hoverGeneration++;
    uint64_t generation = _hoverGeneration;
    CGPoint scheduledPoint = rawPoint;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(HoverClickHoverDelaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation != self->_hoverGeneration ||
            !self->_hoverFocusEnabled ||
            !self->_eventTapInstalled ||
            !self->_hasLatestHoverPoint) {
            return;
        }

        if ([self distanceFromPoint:scheduledPoint toPoint:self->_latestHoverPoint] > HoverClickHoverMovementTolerance) {
            return;
        }

        [self performHoverFocusAtPoint:scheduledPoint];
    });
}

- (void)performHoverFocusAtPoint:(CGPoint)rawPoint {
    _hoverSequence++;
    uint64_t hoverID = _hoverSequence;
    CGPoint axPoint = [self accessibilityPointForEventPoint:rawPoint];

    HoverClickLog("HoverClick: hover #%llu candidate raw=(%.1f,%.1f) converted=(%.1f,%.1f)",
                  hoverID,
                  rawPoint.x,
                  rawPoint.y,
                  axPoint.x,
                  axPoint.y);

    AXUIElementRef element = [self copyElementAtAccessibilityPoint:axPoint];
    if (element == NULL) {
        HoverClickLog("HoverClick: hover #%llu ignored reason=no-ax-element", hoverID);
        return;
    }

    [self handleResolvedElement:element rawPoint:rawPoint axPoint:axPoint sequenceID:hoverID trigger:"hover"];
    CFRelease(element);
}

- (CGFloat)distanceFromPoint:(CGPoint)a toPoint:(CGPoint)b {
    CGFloat dx = a.x - b.x;
    CGFloat dy = a.y - b.y;
    return sqrt((dx * dx) + (dy * dy));
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

    if (strcmp(trigger, "hover") == 0 && [self shouldSkipRepeatedHoverForPid:targetPid appName:appName windowTitle:windowTitle]) {
        HoverClickLog("HoverClick: hover #%llu ignored reason=same-target-repeat app=%s pid=%d", sequenceID, appName.UTF8String, targetPid);
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

- (BOOL)shouldSkipRepeatedHoverForPid:(pid_t)targetPid appName:(NSString *)appName windowTitle:(NSString *)windowTitle {
    NSString *targetKey = [NSString stringWithFormat:@"%d:%@:%@", targetPid, appName ?: @"", windowTitle ?: @""];
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();

    if (_lastHoverTargetKey != nil &&
        [_lastHoverTargetKey isEqualToString:targetKey] &&
        now - _lastHoverFocusTime < HoverClickHoverRepeatIntervalSeconds) {
        return YES;
    }

    _lastHoverTargetKey = targetKey;
    _lastHoverFocusTime = now;
    return NO;
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

    HoverClickLog("HoverClick: %s #%llu %s-to-focus executed target=%s pid=%d frontBefore=%s pid=%d",
                  trigger,
                  sequenceID,
                  trigger,
                  appName.UTF8String,
                  targetPid,
                  frontBeforeName.UTF8String,
                  frontBeforePid);

    AXError raiseError = AXUIElementPerformAction(targetWindow, kAXRaiseAction);
    HoverClickLog("HoverClick: %s #%llu AXRaise %s", trigger, sequenceID, HoverClickAXErrorName(raiseError));

    AXUIElementRef appElement = AXUIElementCreateApplication(targetPid);
    AXError focusedWindowError = kAXErrorIllegalArgument;
    AXError mainWindowError = kAXErrorIllegalArgument;
    AXError focusedAttrError = kAXErrorIllegalArgument;
    if (appElement != NULL) {
        focusedWindowError = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute, targetWindow);
        mainWindowError = AXUIElementSetAttributeValue(targetWindow, kAXMainAttribute, kCFBooleanTrue);
        focusedAttrError = AXUIElementSetAttributeValue(targetWindow, kAXFocusedAttribute, kCFBooleanTrue);
        CFRelease(appElement);
    }

    HoverClickLog("HoverClick: %s #%llu AX focusedWindow set %s", trigger, sequenceID, HoverClickAXErrorName(focusedWindowError));
    [self diagnosticLog:"HoverClick: %s #%llu AX mainWindow set %s", trigger, sequenceID, HoverClickAXErrorName(mainWindowError)];
    [self diagnosticLog:"HoverClick: %s #%llu AX focused attribute set %s", trigger, sequenceID, HoverClickAXErrorName(focusedAttrError)];

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

    NSRunningApplication *frontAfter = [NSWorkspace sharedWorkspace].frontmostApplication;
    BOOL frontImmediate = frontAfter.processIdentifier == targetPid;
    HoverClickLog("HoverClick: %s #%llu %s-to-focus immediate verify frontApp=%s current=%s pid=%d",
                  trigger,
                  sequenceID,
                  trigger,
                  frontImmediate ? "YES" : "NO",
                  (frontAfter.localizedName ?: @"unknown").UTF8String,
                  frontAfter.processIdentifier);

    [self setLastClickResult:frontImmediate ? @"Succeeded" : @"Verify Pending"];
    HoverClickLog("HoverClick: %s #%llu event passed through", trigger, sequenceID);

    if (_pendingDelayedVerifications >= 8) {
        HoverClickLog("HoverClick: %s #%llu delayed verify skipped; pending limit reached", trigger, sequenceID);
        return;
    }

    _pendingDelayedVerifications++;
    _latestVerificationSequence++;
    uint64_t verifyToken = _latestVerificationSequence;
    AXUIElementRef retainedWindow = targetWindow != NULL ? (AXUIElementRef)CFRetain(targetWindow) : NULL;
    pid_t verifyPid = targetPid;
    NSString *verifyAppName = [appName copy];
    uint64_t verifySequenceID = sequenceID;
    NSString *verifyTrigger = [NSString stringWithUTF8String:trigger];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->_pendingDelayedVerifications > 0) {
            self->_pendingDelayedVerifications--;
        }

        NSRunningApplication *targetStillRunning = [NSRunningApplication runningApplicationWithProcessIdentifier:verifyPid];
        if (targetStillRunning == nil) {
            HoverClickLog("HoverClick: %s #%llu delayed verify stale target=%s pid=%d appExited=YES",
                          verifyTrigger.UTF8String,
                          verifySequenceID,
                          verifyAppName.UTF8String,
                          verifyPid);
            if (retainedWindow != NULL) {
                CFRelease(retainedWindow);
            }
            return;
        }

        NSRunningApplication *delayedFront = [NSWorkspace sharedWorkspace].frontmostApplication;
        BOOL delayedFrontMatches = delayedFront.processIdentifier == verifyPid;
        BOOL newerClickOccurred = self->_latestVerificationSequence != verifyToken;

        BOOL focusedWindowMatches = NO;
        if (retainedWindow != NULL) {
            AXUIElementRef verifyAppElement = AXUIElementCreateApplication(verifyPid);
            if (verifyAppElement != NULL) {
                CFTypeRef focusedWindowValue = NULL;
                AXError focusedWindowRead = AXUIElementCopyAttributeValue(verifyAppElement,
                                                                          kAXFocusedWindowAttribute,
                                                                          &focusedWindowValue);
                if (focusedWindowRead == kAXErrorSuccess && focusedWindowValue != NULL) {
                    if (CFGetTypeID(focusedWindowValue) == AXUIElementGetTypeID()) {
                        focusedWindowMatches = CFEqual(focusedWindowValue, retainedWindow);
                    }
                    CFRelease(focusedWindowValue);
                }
                CFRelease(verifyAppElement);
            }
        }

        HoverClickLog("HoverClick: %s #%llu delayed verify target=%s pid=%d frontApp=%s focusedWindow=%s newerClick=%s",
                      verifyTrigger.UTF8String,
                      verifySequenceID,
                      verifyAppName.UTF8String,
                      verifyPid,
                      delayedFrontMatches ? "YES" : "NO",
                      focusedWindowMatches ? "YES" : "NO",
                      newerClickOccurred ? "YES" : "NO");

        if (retainedWindow != NULL) {
            CFRelease(retainedWindow);
        }
    });
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
