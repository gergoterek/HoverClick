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
static NSString * const HoverClickFinderBundleID = @"com.apple.finder";
static NSString * const HoverClickFallbackShortVersion = @"0.0.0";
static NSString * const HoverClickRightClickFocusDefaultsKey = @"rightClickFocusEnabled";
static NSString * const HoverClickHoverClickAssistDefaultsKey = @"hoverClickAssistEnabled";
static NSString * const HoverClickVersionChangeHelp = @"UI-Menubar: simplified diagnostics, permissions layout, hover submenu, and live version display.";
static NSString * const HoverClickLeftClickFocusHelp = @"Activates a background window before passing through your original left click.";
static NSString * const HoverClickRightClickFocusHelp = @"Activates a background window before opening its normal right-click menu.";
static NSString * const HoverClickHoverClickAssistHelp = @"Experimental placeholder for future hover-dependent buttons; requires Left Click Focus and currently adds no cursor movement or synthetic clicks.";
static NSString * const HoverClickAccessibilityStatusHelp = @"Shows whether macOS currently allows HoverClick to inspect and focus windows.";
static NSString * const HoverClickOpenAccessibilitySettingsHelp = @"Opens the macOS Accessibility privacy pane so you can review HoverClick access.";
static NSString * const HoverClickLaunchAtLoginHelp = @"Starts HoverClick automatically after you log in, without changing click behavior.";
static NSString * const HoverClickVerboseDiagnosticsHelp = @"Adds more detailed troubleshooting logs while HoverClick is running.";
static NSString * const HoverClickCopyDiagnosticsSummaryHelp = @"Copies the current HoverClick status summary to the clipboard.";
static NSString * const HoverClickQuitHelp = @"Stops HoverClick until you launch it again.";
static const CGFloat HoverClickStatusItemLength = 23.0;
static const CGFloat HoverClickStatusIconPointSize = 16.0;
static const CGFloat HoverClickHeaderWidth = 286.0;
static const CGFloat HoverClickHeaderHeight = 24.0;
static const CGFloat HoverClickHeaderHorizontalPadding = 14.0;
static const CGFloat HoverClickHeaderLabelY = 4.0;
static const CGFloat HoverClickHeaderLabelHeight = 18.0;
static const CGFloat HoverClickHeaderTitleWidth = 130.0;
static const CGFloat HoverClickHeaderVersionWidth = 122.0;

static NSString *HoverClickDisplayVersion(void) {
    NSString *shortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    if (shortVersion.length == 0) {
        NSLog(@"[HoverClick] missing CFBundleShortVersionString; using fallback %@", HoverClickFallbackShortVersion);
        shortVersion = HoverClickFallbackShortVersion;
    }

    return shortVersion;
}

static NSString *HoverClickHeaderVersion(void) {
    return [NSString stringWithFormat:@"v%@", HoverClickDisplayVersion()];
}

static NSMenuItem *HoverClickCreateHeaderMenuItem(void) {
    NSString *headerVersion = HoverClickHeaderVersion();
    NSRect headerFrame = NSMakeRect(0.0, 0.0, HoverClickHeaderWidth, HoverClickHeaderHeight);
    NSView *headerView = [[NSView alloc] initWithFrame:headerFrame];
    headerView.toolTip = HoverClickVersionChangeHelp;

    NSTextField *nameLabel = [NSTextField labelWithString:@"HoverClick"];
    nameLabel.frame = NSMakeRect(HoverClickHeaderHorizontalPadding,
                                 HoverClickHeaderLabelY,
                                 HoverClickHeaderTitleWidth,
                                 HoverClickHeaderLabelHeight);
    nameLabel.font = [NSFont menuBarFontOfSize:0.0];
    nameLabel.textColor = [NSColor disabledControlTextColor];
    nameLabel.toolTip = HoverClickVersionChangeHelp;
    [headerView addSubview:nameLabel];

    NSTextField *versionLabel = [NSTextField labelWithString:headerVersion];
    versionLabel.frame = NSMakeRect(HoverClickHeaderWidth - HoverClickHeaderHorizontalPadding - HoverClickHeaderVersionWidth,
                                    HoverClickHeaderLabelY,
                                    HoverClickHeaderVersionWidth,
                                    HoverClickHeaderLabelHeight);
    versionLabel.alignment = NSTextAlignmentRight;
    versionLabel.font = [NSFont menuFontOfSize:0.0];
    versionLabel.textColor = [NSColor disabledControlTextColor];
    versionLabel.toolTip = HoverClickVersionChangeHelp;
    [headerView addSubview:versionLabel];

    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:@""
                                                        action:nil
                                                 keyEquivalent:@""];
    headerItem.enabled = NO;
    headerItem.indentationLevel = 0;
    headerItem.state = NSControlStateValueOff;
    headerItem.view = headerView;
    headerItem.toolTip = HoverClickVersionChangeHelp;
    return headerItem;
}

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
@property(nonatomic, strong) NSMenuItem *clickToFocusItem;
@property(nonatomic, strong) NSMenuItem *rightClickFocusItem;
@property(nonatomic, strong) NSMenuItem *hoverMenuItem;
@property(nonatomic, strong) NSMenuItem *hoverClickAssistItem;
@property(nonatomic, strong) NSMenuItem *launchAtLoginItem;
@property(nonatomic, strong) NSMenuItem *diagnosticsItem;
@property(nonatomic, strong) NSMenuItem *verboseItem;
- (void)handleEventTapDisabledWithReason:(NSString *)reason shouldReenable:(BOOL)shouldReenable;
- (void)handleLeftMouseDown:(CGEventRef)event;
- (void)handleRightMouseDown:(CGEventRef)event;
- (BOOL)isEffectiveHoverClickAssistEnabled;
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
    CFAbsoluteTime _lastRightClickFocusTime;
    pid_t _lastRightClickFocusPid;
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
    _lastRightClickFocusTime = 0;
    _lastRightClickFocusPid = 0;
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
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:HoverClickStatusItemLength];

    NSStatusBarButton *button = self.statusItem.button;
    if (@available(macOS 11.0, *)) {
        NSImage *image = [NSImage imageWithSystemSymbolName:@"cursorarrow.click"
                                  accessibilityDescription:@"HoverClick"];
        if (image != nil) {
            NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:HoverClickStatusIconPointSize
                                                                                                        weight:NSFontWeightSemibold
                                                                                                         scale:NSImageSymbolScaleLarge];
            image = [image imageWithSymbolConfiguration:configuration] ?: image;
            [image setTemplate:YES];
            image.size = NSMakeSize(HoverClickStatusIconPointSize, HoverClickStatusIconPointSize);
            button.image = image;
            button.imagePosition = NSImageOnly;
            button.imageScaling = NSImageScaleProportionallyUpOrDown;
        } else {
            button.title = @"HC";
        }
    } else {
        button.title = @"HC";
    }

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"HoverClick"];
    [menu setAutoenablesItems:NO];

    [menu addItem:HoverClickCreateHeaderMenuItem()];

    [menu addItem:[NSMenuItem separatorItem]];

    self.clickToFocusItem = [[NSMenuItem alloc] initWithTitle:@"Left Click Focus"
                                                       action:@selector(toggleClickToFocus:)
                                                keyEquivalent:@""];
    self.clickToFocusItem.target = self;
    self.clickToFocusItem.enabled = YES;
    self.clickToFocusItem.indentationLevel = 0;
    self.clickToFocusItem.toolTip = HoverClickLeftClickFocusHelp;
    [menu addItem:self.clickToFocusItem];

    self.rightClickFocusItem = [[NSMenuItem alloc] initWithTitle:@"Right Click Focus"
                                                          action:@selector(toggleRightClickFocus:)
                                                   keyEquivalent:@""];
    self.rightClickFocusItem.target = self;
    self.rightClickFocusItem.enabled = YES;
    self.rightClickFocusItem.indentationLevel = 0;
    self.rightClickFocusItem.toolTip = HoverClickRightClickFocusHelp;
    [menu addItem:self.rightClickFocusItem];

    self.hoverMenuItem = [[NSMenuItem alloc] initWithTitle:@"Hover"
                                                    action:nil
                                             keyEquivalent:@""];
    self.hoverMenuItem.enabled = YES;
    self.hoverMenuItem.indentationLevel = 0;
    self.hoverMenuItem.state = NSControlStateValueOff;

    NSMenu *hoverMenu = [[NSMenu alloc] initWithTitle:@"Hover"];
    [hoverMenu setAutoenablesItems:NO];
    self.hoverMenuItem.submenu = hoverMenu;
    [menu addItem:self.hoverMenuItem];

    self.hoverClickAssistItem = [[NSMenuItem alloc] initWithTitle:@"Hover Click Assist"
                                                           action:@selector(toggleHoverClickAssist:)
                                                    keyEquivalent:@""];
    self.hoverClickAssistItem.target = self;
    self.hoverClickAssistItem.enabled = YES;
    self.hoverClickAssistItem.indentationLevel = 0;
    self.hoverClickAssistItem.toolTip = HoverClickHoverClickAssistHelp;
    [hoverMenu addItem:self.hoverClickAssistItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *permissionsStartupItem = [[NSMenuItem alloc] initWithTitle:@"Permissions & Startup"
                                                                    action:nil
                                                             keyEquivalent:@""];
    permissionsStartupItem.enabled = YES;
    permissionsStartupItem.indentationLevel = 0;
    permissionsStartupItem.state = NSControlStateValueOff;

    NSMenu *permissionsStartupMenu = [[NSMenu alloc] initWithTitle:@"Permissions & Startup"];
    [permissionsStartupMenu setAutoenablesItems:NO];
    permissionsStartupItem.submenu = permissionsStartupMenu;
    [menu addItem:permissionsStartupItem];

    self.permissionItem = [[NSMenuItem alloc] initWithTitle:@"Accessibility: Not Granted"
                                                     action:@selector(refreshAccessibilityStatus:)
                                              keyEquivalent:@""];
    self.permissionItem.target = self;
    self.permissionItem.enabled = YES;
    self.permissionItem.indentationLevel = 0;
    self.permissionItem.state = NSControlStateValueOff;
    self.permissionItem.toolTip = HoverClickAccessibilityStatusHelp;
    [permissionsStartupMenu addItem:self.permissionItem];

    self.launchAtLoginItem = [[NSMenuItem alloc] initWithTitle:@"Launch at Login"
                                                        action:@selector(toggleLaunchAtLogin:)
                                                 keyEquivalent:@""];
    self.launchAtLoginItem.target = self;
    self.launchAtLoginItem.enabled = YES;
    self.launchAtLoginItem.indentationLevel = 0;
    self.launchAtLoginItem.toolTip = HoverClickLaunchAtLoginHelp;
    [permissionsStartupMenu addItem:self.launchAtLoginItem];

    [permissionsStartupMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Open Accessibility Settings"
                                                          action:@selector(openAccessibilitySettings:)
                                                   keyEquivalent:@""];
    settingsItem.target = self;
    settingsItem.enabled = YES;
    settingsItem.indentationLevel = 0;
    settingsItem.state = NSControlStateValueOff;
    settingsItem.toolTip = HoverClickOpenAccessibilitySettingsHelp;
    [permissionsStartupMenu addItem:settingsItem];

    self.diagnosticsItem = [[NSMenuItem alloc] initWithTitle:@"Diagnostics"
                                                      action:nil
                                               keyEquivalent:@""];
    self.diagnosticsItem.enabled = YES;
    self.diagnosticsItem.indentationLevel = 0;
    self.diagnosticsItem.state = NSControlStateValueOff;

    NSMenu *diagnosticsMenu = [[NSMenu alloc] initWithTitle:@"Diagnostics"];
    [diagnosticsMenu setAutoenablesItems:NO];
    self.diagnosticsItem.submenu = diagnosticsMenu;
    [menu addItem:self.diagnosticsItem];

    self.verboseItem = [[NSMenuItem alloc] initWithTitle:@"Verbose Diagnostics"
                                                  action:@selector(toggleVerboseDiagnostics:)
                                           keyEquivalent:@""];
    self.verboseItem.target = self;
    self.verboseItem.enabled = YES;
    self.verboseItem.indentationLevel = 0;
    self.verboseItem.toolTip = HoverClickVerboseDiagnosticsHelp;
    [diagnosticsMenu addItem:self.verboseItem];

    NSMenuItem *copyDiagnosticsItem = [[NSMenuItem alloc] initWithTitle:@"Copy Diagnostics Summary"
                                                                 action:@selector(copyDiagnosticsSummary:)
                                                          keyEquivalent:@""];
    copyDiagnosticsItem.target = self;
    copyDiagnosticsItem.enabled = YES;
    copyDiagnosticsItem.indentationLevel = 0;
    copyDiagnosticsItem.state = NSControlStateValueOff;
    copyDiagnosticsItem.toolTip = HoverClickCopyDiagnosticsSummaryHelp;
    [diagnosticsMenu addItem:copyDiagnosticsItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];
    quitItem.target = NSApp;
    quitItem.enabled = YES;
    quitItem.indentationLevel = 0;
    quitItem.state = NSControlStateValueOff;
    quitItem.toolTip = HoverClickQuitHelp;
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
    [self updateMenuTitles];
}

- (void)printLaunchStatus {
    BOOL trusted = [self accessibilityTrusted];
    HoverClickLog("HoverClick: bundle id = %s", HoverClickBundleID.UTF8String);
    HoverClickLog("HoverClick: version = %s", HoverClickDisplayVersion().UTF8String);
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
    self.launchAtLoginItem.toolTip = HoverClickLaunchAtLoginHelp;

#if HOVERCLICK_HAS_SERVICE_MANAGEMENT
    if (@available(macOS 13.0, *)) {
        SMAppService *service = SMAppService.mainAppService;
        SMAppServiceStatus status = service.status;
        NSString *statusDescription = [self launchAtLoginStatusDescription:status];

        self.launchAtLoginItem.enabled = YES;
        self.launchAtLoginItem.toolTip = HoverClickLaunchAtLoginHelp;

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
    self.launchAtLoginItem.title = @"Launch at Login: Unavailable";
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
    if (!_clickToFocusEnabled) {
        HoverClickLog("HoverClick: Hover Click Assist toggle ignored because Left Click Focus is disabled");
        [self updateMenuTitles];
        return;
    }

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

- (NSString *)launchAtLoginStatusForDiagnostics {
#if HOVERCLICK_HAS_SERVICE_MANAGEMENT
    if (@available(macOS 13.0, *)) {
        return [self launchAtLoginStatusDescription:SMAppService.mainAppService.status];
    }
#endif

    return @"unavailable";
}

- (NSString *)clickDetectionStatusForDiagnostics {
    if (![self accessibilityTrusted]) {
        return _userWantsEventTap ? @"permission missing" : @"disabled";
    }

    if (!_userWantsEventTap) {
        return @"disabled";
    }

    if (_eventTapInstalled && _eventTap != NULL) {
        return @"active";
    }

    return @"inactive";
}

- (NSString *)lastActionForDiagnostics {
    NSString *result = _lastClickResult ?: @"None";
    if ([result isEqualToString:@"None"]) {
        return @"none recorded";
    }

    if ([result isEqualToString:@"Permission Missing"]) {
        return @"Accessibility permission missing";
    }

    if ([result isEqualToString:@"Event Tap Create Failed"]) {
        return @"click detection setup failed";
    }

    if ([result isEqualToString:@"Event Tap Source Failed"]) {
        return @"click detection source setup failed";
    }

    if ([result isEqualToString:@"Event Tap Disabled"]) {
        return @"click detection disabled";
    }

    if ([result isEqualToString:@"Diagnostics Summary Copied"]) {
        return @"diagnostics summary copied";
    }

    if ([result isEqualToString:@"Disabled"]) {
        return @"left click focus disabled";
    }

    if ([result isEqualToString:@"Right Click Disabled"]) {
        return @"right click focus disabled";
    }

    if ([result isEqualToString:@"No AX Element"]) {
        return @"no window element found";
    }

    if ([result isEqualToString:@"No Target PID"]) {
        return @"target app process unavailable";
    }

    if ([result isEqualToString:@"No Target App"]) {
        return @"target app unavailable";
    }

    if ([result isEqualToString:@"Ignored Own App"] ||
        [result isEqualToString:@"Ignored Menu/UI"]) {
        return @"menu or status-item click ignored";
    }

    if ([result isEqualToString:@"No Target Window"]) {
        return @"target window unavailable";
    }

    if ([result isEqualToString:@"Ignored Transient UI"]) {
        return @"transient menu or popover click ignored";
    }

    if ([result isEqualToString:@"Already Frontmost"]) {
        return @"target app already frontmost";
    }

    return result;
}

- (NSString *)diagnosticsSummaryText {
    NSString *accessibilityStatus = [self accessibilityTrusted] ? @"granted" : @"not granted";

    return [NSString stringWithFormat:
            @"HoverClick diagnostics\n"
             "Version: v%@\n"
             "Accessibility: %@\n"
             "Launch at Login: %@\n"
             "Click detection: %@\n"
             "Last handled action: %@\n"
             "Left Click Focus: %@\n"
             "Right Click Focus: %@\n"
             "Hover Click Assist: %@\n"
             "Hover Click Assist effective: %@\n"
             "Verbose Diagnostics: %@\n"
             "Event tap mask: left and right mouse-down only; mouse movement is not observed\n"
             "Stable core: no synthetic clicks and no cursor movement",
            HoverClickDisplayVersion(),
            accessibilityStatus,
            [self launchAtLoginStatusForDiagnostics],
            [self clickDetectionStatusForDiagnostics],
            [self lastActionForDiagnostics],
            _clickToFocusEnabled ? @"enabled" : @"disabled",
            _rightClickFocusEnabled ? @"enabled" : @"disabled",
            _hoverClickAssistEnabled ? @"enabled" : @"disabled",
            [self isEffectiveHoverClickAssistEnabled] ? @"enabled" : @"disabled",
            _verboseDiagnostics ? @"enabled" : @"disabled"];
}

- (void)copyDiagnosticsSummary:(id)sender {
    (void)sender;

    NSString *summary = [self diagnosticsSummaryText];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:summary forType:NSPasteboardTypeString];

    HoverClickLog("HoverClick: diagnostics summary copied");
    [self setLastClickResult:@"Diagnostics Summary Copied"];
}

- (void)updateMenuTitles {
    BOOL trusted = [self accessibilityTrusted];
    self.permissionItem.title = trusted ? @"Accessibility: Granted" : @"Accessibility: Not Granted";
    self.permissionItem.state = trusted ? NSControlStateValueOn : NSControlStateValueOff;

    self.clickToFocusItem.title = @"Left Click Focus";
    self.clickToFocusItem.state = _clickToFocusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.rightClickFocusItem.title = @"Right Click Focus";
    self.rightClickFocusItem.state = _rightClickFocusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.hoverMenuItem.title = @"Hover";
    self.hoverMenuItem.enabled = _clickToFocusEnabled;
    self.hoverMenuItem.state = NSControlStateValueOff;
    self.hoverClickAssistItem.title = @"Hover Click Assist";
    self.hoverClickAssistItem.enabled = _clickToFocusEnabled;
    self.hoverClickAssistItem.state = _hoverClickAssistEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [self updateLaunchAtLoginMenuItem];
    self.verboseItem.title = @"Verbose Diagnostics";
    self.verboseItem.state = _verboseDiagnostics ? NSControlStateValueOn : NSControlStateValueOff;
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

- (BOOL)isEffectiveHoverClickAssistEnabled {
    return _clickToFocusEnabled && _hoverClickAssistEnabled;
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

    CGEventFlags modifierFlags = CGEventGetFlags(event);
    [self handleResolvedElement:element
                       rawPoint:rawPoint
                        axPoint:axPoint
                     sequenceID:clickID
                        trigger:"right-click"
                  modifierFlags:modifierFlags];
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
    [self handleResolvedElement:element
                       rawPoint:rawPoint
                        axPoint:axPoint
                     sequenceID:clickID
                        trigger:"click"
                  modifierFlags:0];
}

- (void)handleResolvedElement:(AXUIElementRef)element
                     rawPoint:(CGPoint)rawPoint
                      axPoint:(CGPoint)axPoint
                   sequenceID:(uint64_t)sequenceID
                      trigger:(const char *)trigger
                modifierFlags:(CGEventFlags)modifierFlags {
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

    NSRunningApplication *frontApp = [NSWorkspace sharedWorkspace].frontmostApplication;
    BOOL targetIsFrontmost = frontApp != nil && frontApp.processIdentifier == targetPid;
    if (targetIsFrontmost) {
        BOOL afterRecentRightClickFocus = (strcmp(trigger, "click") == 0 &&
                                           _lastRightClickFocusPid == targetPid &&
                                           CFAbsoluteTimeGetCurrent() - _lastRightClickFocusTime < 5.0);
        HoverClickLog("HoverClick: %s #%llu ignored reason=already-frontmost pid=%d app=%s recentRightClickFocus=%s; event passed through",
                      trigger,
                      sequenceID,
                      targetPid,
                      appName.UTF8String,
                      afterRecentRightClickFocus ? "YES" : "NO");
        [self setLastClickResult:@"Already Frontmost"];
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
           sourceElement:element
                 rawPoint:rawPoint
                  axPoint:axPoint
              sequenceID:sequenceID
                 trigger:trigger
           modifierFlags:modifierFlags];
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
         sourceElement:(AXUIElementRef)sourceElement
               rawPoint:(CGPoint)rawPoint
                axPoint:(CGPoint)axPoint
            sequenceID:(uint64_t)sequenceID
               trigger:(const char *)trigger
         modifierFlags:(CGEventFlags)modifierFlags {
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

    if (frontImmediate && strcmp(trigger, "right-click") == 0) {
        if ([self isFinderApplication:targetApp]) {
            [self selectFinderItemForRightClickElement:sourceElement
                                            sequenceID:sequenceID
                                         modifierFlags:modifierFlags];
        }

        _lastRightClickFocusPid = targetPid;
        _lastRightClickFocusTime = CFAbsoluteTimeGetCurrent();
    }

    [self setLastClickResult:frontImmediate ? @"Succeeded" : @"Verify Failed"];
    HoverClickLog("HoverClick: %s #%llu event passed through", trigger, sequenceID);

    if (![self isEffectiveHoverClickAssistEnabled]) {
        if (_hoverClickAssistEnabled) {
            HoverClickLog("HoverClick: Experimental Hover Click Assist ON but ineffective because Left Click Focus is disabled: no assist path scheduled");
            return;
        }

        HoverClickLog("HoverClick: Experimental Hover Click Assist OFF: no assist path scheduled");
        return;
    }

    HoverClickLog("HoverClick: Experimental Hover Click Assist ON: placeholder no-op; no assist path scheduled");
}

- (BOOL)isFinderApplication:(NSRunningApplication *)application {
    if (application == nil) {
        return NO;
    }

    NSString *bundleIdentifier = application.bundleIdentifier ?: @"";
    return [bundleIdentifier isEqualToString:HoverClickFinderBundleID];
}

- (BOOL)modifierFlagsAllowFinderSelectionAssist:(CGEventFlags)modifierFlags {
    CGEventFlags selectionModifierFlags = kCGEventFlagMaskShift |
                                          kCGEventFlagMaskControl |
                                          kCGEventFlagMaskAlternate |
                                          kCGEventFlagMaskCommand;
    return (modifierFlags & selectionModifierFlags) == 0;
}

- (void)selectFinderItemForRightClickElement:(AXUIElementRef)sourceElement
                                  sequenceID:(uint64_t)sequenceID
                               modifierFlags:(CGEventFlags)modifierFlags {
    if (sourceElement == NULL) {
        return;
    }

    if (![self modifierFlagsAllowFinderSelectionAssist:modifierFlags]) {
        HoverClickLog("HoverClick: right-click #%llu Finder selection assist skipped reason=modifier-flags flags=0x%llx",
                      sequenceID,
                      (unsigned long long)modifierFlags);
        return;
    }

    AXUIElementRef selectionContainer = NULL;
    CFStringRef selectionAttribute = NULL;
    AXUIElementRef item = [self copyFinderSelectableItemForElement:sourceElement
                                                selectionContainer:&selectionContainer
                                                selectionAttribute:&selectionAttribute];
    if (item == NULL || selectionContainer == NULL || selectionAttribute == NULL) {
        [self diagnosticLog:"HoverClick: right-click #%llu Finder selection assist skipped reason=no-file-selection-target",
                            sequenceID];
        if (item != NULL) {
            CFRelease(item);
        }
        if (selectionContainer != NULL) {
            CFRelease(selectionContainer);
        }
        return;
    }

    BOOL alreadySelected = NO;
    if (![self finderItemIsSelected:item
                         inContainer:selectionContainer
                  selectionAttribute:selectionAttribute
                            selected:&alreadySelected]) {
        HoverClickLog("HoverClick: right-click #%llu Finder selection assist skipped reason=selection-state-unknown",
                      sequenceID);
        CFRelease(item);
        CFRelease(selectionContainer);
        return;
    }

    NSString *attributeName = (__bridge NSString *)selectionAttribute;
    if (alreadySelected) {
        HoverClickLog("HoverClick: right-click #%llu Finder selection assist preserved existing selection attribute=%s",
                      sequenceID,
                      attributeName.UTF8String);
        CFRelease(item);
        CFRelease(selectionContainer);
        return;
    }

    const void *values[] = { item };
    CFArrayRef selectedItems = CFArrayCreate(kCFAllocatorDefault,
                                             values,
                                             1,
                                             &kCFTypeArrayCallBacks);
    if (selectedItems == NULL) {
        HoverClickLog("HoverClick: right-click #%llu Finder selection assist failed reason=array-create",
                      sequenceID);
        CFRelease(item);
        CFRelease(selectionContainer);
        return;
    }

    AXError selectionError = AXUIElementSetAttributeValue(selectionContainer,
                                                         selectionAttribute,
                                                         selectedItems);
    CFRelease(selectedItems);

    if (selectionError == kAXErrorSuccess) {
        HoverClickLog("HoverClick: right-click #%llu Finder selection assist selected target attribute=%s",
                      sequenceID,
                      attributeName.UTF8String);
    } else {
        HoverClickLog("HoverClick: right-click #%llu Finder selection assist set failed error=%s attribute=%s",
                      sequenceID,
                      HoverClickAXErrorName(selectionError),
                      attributeName.UTF8String);
    }
    CFRelease(item);
    CFRelease(selectionContainer);
}

- (AXUIElementRef)copyFinderSelectableItemForElement:(AXUIElementRef)element
                                 selectionContainer:(AXUIElementRef *)selectionContainer
                                 selectionAttribute:(CFStringRef *)selectionAttribute {
    if (selectionContainer != NULL) {
        *selectionContainer = NULL;
    }
    if (selectionAttribute != NULL) {
        *selectionAttribute = NULL;
    }
    if (element == NULL) {
        return NULL;
    }

    AXUIElementRef current = (AXUIElementRef)CFRetain(element);
    for (NSInteger depth = 0; depth < 8 && current != NULL; depth++) {
        NSString *role = [self stringAttribute:kAXRoleAttribute fromElement:current] ?: @"unknown";
        if ([self finderElementHasFilename:current]) {
            CFStringRef foundSelectionAttribute = NULL;
            AXUIElementRef foundSelectionContainer = [self copySettableFinderSelectionContainerForItem:current
                                                                                    selectionAttribute:&foundSelectionAttribute];
            if (foundSelectionContainer != NULL && foundSelectionAttribute != NULL) {
                [self diagnosticLog:"HoverClick: Finder selectable item found depth=%ld role=%s selectionAttribute=%s",
                                    (long)depth,
                                    role.UTF8String,
                                    ((__bridge NSString *)foundSelectionAttribute).UTF8String];
                if (selectionContainer != NULL) {
                    *selectionContainer = foundSelectionContainer;
                } else {
                    CFRelease(foundSelectionContainer);
                }
                if (selectionAttribute != NULL) {
                    *selectionAttribute = foundSelectionAttribute;
                }
                return current;
            }

            if (foundSelectionContainer != NULL) {
                CFRelease(foundSelectionContainer);
            }
        }

        if ([self roleLooksLikeWindow:role]) {
            break;
        }

        AXUIElementRef parent = [self copyParentElementForElement:current];
        CFRelease(current);
        current = parent;
    }

    if (current != NULL) {
        CFRelease(current);
    }
    return NULL;
}

- (BOOL)finderElementHasFilename:(AXUIElementRef)element {
    NSString *filename = [self stringAttribute:kAXFilenameAttribute fromElement:element];
    return filename.length > 0;
}

- (AXUIElementRef)copySettableFinderSelectionContainerForItem:(AXUIElementRef)item
                                           selectionAttribute:(CFStringRef *)selectionAttribute {
    if (selectionAttribute != NULL) {
        *selectionAttribute = NULL;
    }
    if (item == NULL) {
        return NULL;
    }

    NSString *itemRole = [self stringAttribute:kAXRoleAttribute fromElement:item] ?: @"";
    BOOL preferRows = [itemRole isEqualToString:@"AXRow"];
    CFStringRef firstAttribute = preferRows ? kAXSelectedRowsAttribute : kAXSelectedChildrenAttribute;
    CFStringRef secondAttribute = preferRows ? kAXSelectedChildrenAttribute : kAXSelectedRowsAttribute;

    AXUIElementRef current = (AXUIElementRef)CFRetain(item);
    for (NSInteger depth = 0; depth < 8 && current != NULL; depth++) {
        AXUIElementRef parent = [self copyParentElementForElement:current];
        CFRelease(current);
        current = parent;
        if (current == NULL) {
            return NULL;
        }

        CFStringRef candidateAttributes[] = { firstAttribute, secondAttribute };
        for (NSUInteger index = 0; index < 2; index++) {
            Boolean settable = false;
            AXError settableError = AXUIElementIsAttributeSettable(current,
                                                                   candidateAttributes[index],
                                                                   &settable);
            if (settableError == kAXErrorSuccess && settable) {
                if (selectionAttribute != NULL) {
                    *selectionAttribute = candidateAttributes[index];
                }
                return current;
            }
        }
    }

    if (current != NULL) {
        CFRelease(current);
    }
    return NULL;
}

- (BOOL)finderItemIsSelected:(AXUIElementRef)item
                 inContainer:(AXUIElementRef)selectionContainer
          selectionAttribute:(CFStringRef)selectionAttribute
                    selected:(BOOL *)selected {
    BOOL known = NO;
    BOOL isSelected = NO;

    BOOL selectedAttributeValue = NO;
    if ([self boolAttribute:kAXSelectedAttribute fromElement:item value:&selectedAttributeValue]) {
        known = YES;
        isSelected = selectedAttributeValue;
    }

    BOOL containedInSelection = NO;
    if ([self element:item
        appearsInArrayAttribute:selectionAttribute
                      ofElement:selectionContainer
                       contains:&containedInSelection]) {
        known = YES;
        isSelected = isSelected || containedInSelection;
    }

    if (selected != NULL) {
        *selected = isSelected;
    }
    return known;
}

- (BOOL)element:(AXUIElementRef)element
appearsInArrayAttribute:(CFStringRef)attribute
      ofElement:(AXUIElementRef)container
       contains:(BOOL *)contains {
    if (contains != NULL) {
        *contains = NO;
    }
    if (element == NULL || container == NULL || attribute == NULL) {
        return NO;
    }

    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(container, attribute, &value);
    if (error != kAXErrorSuccess || value == NULL) {
        return NO;
    }

    BOOL known = NO;
    BOOL found = NO;
    if (CFGetTypeID(value) == CFArrayGetTypeID()) {
        known = YES;
        CFArrayRef array = (CFArrayRef)value;
        CFIndex count = CFArrayGetCount(array);
        for (CFIndex index = 0; index < count; index++) {
            CFTypeRef candidate = CFArrayGetValueAtIndex(array, index);
            if (candidate != NULL &&
                CFGetTypeID(candidate) == AXUIElementGetTypeID() &&
                CFEqual(candidate, element)) {
                found = YES;
                break;
            }
        }
    }

    CFRelease(value);
    if (contains != NULL) {
        *contains = found;
    }
    return known;
}

- (BOOL)boolAttribute:(CFStringRef)attribute fromElement:(AXUIElementRef)element value:(BOOL *)outValue {
    if (outValue != NULL) {
        *outValue = NO;
    }
    if (element == NULL || attribute == NULL) {
        return NO;
    }

    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
    if (error != kAXErrorSuccess || value == NULL) {
        return NO;
    }

    BOOL known = NO;
    BOOL result = NO;
    if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
        known = YES;
        result = CFBooleanGetValue((CFBooleanRef)value);
    }

    CFRelease(value);
    if (known && outValue != NULL) {
        *outValue = result;
    }
    return known;
}

- (AXUIElementRef)copyParentElementForElement:(AXUIElementRef)element {
    if (element == NULL) {
        return NULL;
    }

    CFTypeRef parentValue = NULL;
    AXError parentError = AXUIElementCopyAttributeValue(element, kAXParentAttribute, &parentValue);
    if (parentError != kAXErrorSuccess || parentValue == NULL) {
        return NULL;
    }

    if (CFGetTypeID(parentValue) != AXUIElementGetTypeID()) {
        CFRelease(parentValue);
        return NULL;
    }

    return (AXUIElementRef)parentValue;
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
    if (url == nil) {
        HoverClickLog("HoverClick: failed to create Accessibility settings URL");
        return;
    }

    if (![[NSWorkspace sharedWorkspace] openURL:url]) {
        HoverClickLog("HoverClick: failed to open Accessibility settings URL");
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
