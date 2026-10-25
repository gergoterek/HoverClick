#import <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>
#import <dispatch/dispatch.h>
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
static NSString * const HoverClickChromeBundleID = @"com.google.Chrome";
static NSString * const HoverClickMaccyBundleID = @"org.p0deje.Maccy";
static NSString * const HoverClickExcludedAppsDefaultsKey = @"excludedAppBundleIDs";
static NSString * const HoverClickFallbackShortVersion = @"0.0.0";
static NSString * const HoverClickFallbackBuildVersion = @"unknown";
static NSString * const HoverClickRightClickFocusDefaultsKey = @"rightClickFocusEnabled";
static NSString * const HoverClickLaunchAtLoginOnboardingPromptShownDefaultsKey = @"launchAtLoginOnboardingPromptShown";
static NSString * const HoverClickStableHelp = @"HoverClick - Windows-like click focus for macOS.";
static NSString * const HoverClickLeftClickFocusHelp = @"Activates a background window before passing through your original left click.";
static NSString * const HoverClickRightClickFocusHelp = @"Activates a background window before opening its normal right-click menu.";
static NSString * const HoverClickAccessibilityStatusHelp = @"Shows whether macOS currently allows HoverClick to inspect and focus windows.";
static NSString * const HoverClickRefreshAccessibilityHelp = @"Checks whether Accessibility permission is now granted and starts click focus when possible.";
static NSString * const HoverClickOpenAccessibilitySettingsHelp = @"Opens the macOS Accessibility privacy pane so you can review HoverClick access.";
static NSString * const HoverClickLaunchAtLoginHelp = @"Starts HoverClick automatically after you log in, without changing click behavior.";
static NSString * const HoverClickVerboseDiagnosticsHelp = @"Adds more detailed troubleshooting logs while HoverClick is running.";
static NSString * const HoverClickCopyDiagnosticsSummaryHelp = @"Copies the current HoverClick status summary to the clipboard.";
static NSString * const HoverClickCheckForUpdatesHelp = @"Checks for HoverClick updates now using Sparkle's visible update flow.";
static NSString * const HoverClickAutomaticUpdateChecksHelp = @"Lets Sparkle periodically look for updates. Downloads and installs still require user action.";
static NSString * const HoverClickAboutHelp = @"Shows HoverClick version and bundle identity.";
static NSString * const HoverClickGitHubHelp = @"Opens the HoverClick GitHub repository.";
static NSString * const HoverClickContactHelp = @"Opens a new email addressed to HoverClick support.";
static NSString * const HoverClickReleaseNotesHelp = @"Opens the HoverClick GitHub releases page.";
static NSString * const HoverClickUninstallHelp = @"Shows safe manual uninstall instructions.";
static NSString * const HoverClickQuitHelp = @"Stops HoverClick until you launch it again.";
static NSString * const HoverClickBypassKeyHelp = @"When held at click time, this modifier key makes HoverClick skip its focus behavior and return the original event unchanged.";
static NSString * const HoverClickExcludedAppsHelp = @"Apps in this list bypass HoverClick focus behavior. When you click a window belonging to an excluded app, HoverClick skips focus, raise, and activation and returns your click unchanged.";
static NSString * const HoverClickChooseExcludedAppHelp = @"Pick an installed application from the list to exclude it from HoverClick focus behavior.";
static const NSInteger HoverClickBypassKeyOff = 0;
static const NSInteger HoverClickBypassKeyShift = 2;
static const NSInteger HoverClickBypassKeyFn = 3;
static NSString * const HoverClickBypassKeyDefaultsKey = @"bypassKey";
static const CGFloat HoverClickStatusItemLength = 23.0;
static const CGFloat HoverClickStatusIconPointSize = 16.0;
static const CGFloat HoverClickMenuContentWidth = 286.0;
static const CGFloat HoverClickMenuLeadingInset = 14.0;
static const CGFloat HoverClickMenuTrailingInset = 8.0;
static const CGFloat HoverClickMenuIconTitleSpacing = 8.0;
static const CGFloat HoverClickMenuRightAccessoryWidth = 14.0;
static const CGFloat HoverClickMenuImagePointSize = 13.0;
static const CGFloat HoverClickMenuImageSize = 16.0;
static const CGFloat HoverClickMenuRowWidth = HoverClickMenuContentWidth;
static const CGFloat HoverClickMenuRowHeight = 22.0;
static const CGFloat HoverClickMenuRowIconX = HoverClickMenuLeadingInset;
static const CGFloat HoverClickMenuRowTextX = HoverClickMenuRowIconX + HoverClickMenuImageSize + HoverClickMenuIconTitleSpacing;
static const CGFloat HoverClickMenuRowFieldY = 2.0;
static const CGFloat HoverClickMenuRowFieldHeight = 18.0;
static const CGFloat HoverClickMenuRowAccessoryOverhang = 36.0;
static const CGFloat HoverClickSectionHeaderHeight = 18.0;
static const CGFloat HoverClickSectionHeaderLeadingInset = HoverClickMenuLeadingInset;
static const CGFloat HoverClickSectionHeaderLabelY = 2.0;
static const CGFloat HoverClickSectionHeaderLabelHeight = 15.0;
static const CGFloat HoverClickSectionHeaderFontSize = 11.0;
static const NSTimeInterval HoverClickDelayedVerificationDelay = 0.20;
// Upper bound for how long the tap callback waits for a requested activation to land before
// the original click is passed on. Measured on 2026-09-14: the activated application became
// frontmost 60 to 120 ms after the click (p90 121 ms, max 197 ms), the tap timeout is 1 s.
static const NSTimeInterval HoverClickActivationWaitTimeout = 0.150;
static const useconds_t HoverClickActivationWaitPollMicroseconds = 10000;
// Upper bound for the wait between a successful AX raise and the activation decision, until the
// window server lists the clicked window as the application's own front window.
static const NSTimeInterval HoverClickRaiseSettleTimeout = 0.060;
// Messaging timeout for every Accessibility call the tap callback makes. Without it a call to a
// busy application blocks for the system default. Measured 2026-09-20 in the unified log: a
// normal AX hit-test takes 2 ms (median) and 17 ms (p99), a blocked one 1.3 to 1.5 s, and each
// of the 8 blocked calls of that day tripped the tap timeout, so the click and the ones after
// it were delivered with no focus handling until the tap was re-enabled.
static const float HoverClickAXMessagingTimeoutSeconds = 0.2f;
// Time budget for one tap callback, counted from the callback entry. Once it is spent, no new
// AX work is started, the focus attempt is abandoned and the original event is returned. With
// the messaging timeout above, one more call can still be in flight when the budget runs out,
// so the callback ends after at most budget + timeout, well inside the tap's own limit (a
// callback of 827 ms did not trip the tap on 2026-09-14, one of 1315 ms did on 2026-09-20).
static const NSTimeInterval HoverClickCallbackBudgetSeconds = 0.5;
// Clock for the callback budget and the bounded waits. CFAbsoluteTimeGetCurrent follows the wall
// clock, which steps when the date is set or corrected; a backward step would let a wait run
// past its cap. CLOCK_UPTIME_RAW never steps; that it pauses during sleep does not matter for a
// budget of under a second.
static inline NSTimeInterval HoverClickMonotonicSeconds(void) {
    return (NSTimeInterval)clock_gettime_nsec_np(CLOCK_UPTIME_RAW) / 1e9;
}
static const NSUInteger HoverClickRecentDecisionHistoryLimit = 10;

static NSString *HoverClickDisplayVersion(void) {
    NSString *shortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];

    if (shortVersion.length == 0) {
        NSLog(@"[HoverClick] missing CFBundleShortVersionString; using fallback %@", HoverClickFallbackShortVersion);
        shortVersion = HoverClickFallbackShortVersion;
    }

    return shortVersion;
}

static NSString *HoverClickBuildVersion(void) {
    NSString *buildVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];

    if (buildVersion.length == 0) {
        buildVersion = HoverClickFallbackBuildVersion;
    }

    return buildVersion;
}

static NSString *HoverClickAppName(void) {
    NSString *displayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (displayName.length > 0) {
        return displayName;
    }

    NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    if (bundleName.length > 0) {
        return bundleName;
    }

    return @"HoverClick";
}

static NSString *HoverClickBundleIdentifier(void) {
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleIdentifier.length > 0) {
        return bundleIdentifier;
    }

    return HoverClickBundleID;
}

static NSString *HoverClickInfoString(NSString *key, NSString *fallback) {
    NSString *value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    if ([value isKindOfClass:[NSString class]] && value.length > 0) {
        return value;
    }

    return fallback;
}

static NSString *HoverClickInfoBoolStatus(NSString *key) {
    id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue] ? @"enabled" : @"disabled";
    }

    return @"missing";
}

static NSString *HoverClickDiagnosticTimestamp(CFAbsoluteTime timestamp) {
    if (timestamp <= 0) {
        return @"never";
    }

    NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:timestamp];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss ZZZZZ";
    return [formatter stringFromDate:date] ?: @"unknown";
}

static NSString *HoverClickEventTypeName(CGEventType type) {
    switch (type) {
        case kCGEventLeftMouseDown:
            return @"kCGEventLeftMouseDown";
        case kCGEventRightMouseDown:
            return @"kCGEventRightMouseDown";
        case kCGEventTapDisabledByTimeout:
            return @"kCGEventTapDisabledByTimeout";
        case kCGEventTapDisabledByUserInput:
            return @"kCGEventTapDisabledByUserInput";
        default:
            return [NSString stringWithFormat:@"CGEventType(%u)", (unsigned int)type];
    }
}

static NSString *HoverClickFocusTriggerLabel(const char *trigger) {
    if (trigger == NULL) {
        return @"unknown";
    }

    if (strcmp(trigger, "click") == 0) {
        return @"left";
    }

    if (strcmp(trigger, "right-click") == 0) {
        return @"right";
    }

    return [NSString stringWithUTF8String:trigger] ?: @"unknown";
}

static NSString *HoverClickRunningApplicationDescription(NSRunningApplication *app) {
    if (app == nil) {
        return @"none";
    }

    NSString *name = app.localizedName;
    if (name.length == 0) {
        name = @"unknown";
    }

    return [NSString stringWithFormat:@"%@ pid=%d", name, app.processIdentifier];
}

static NSString *HoverClickPointDescription(CGPoint point) {
    return [NSString stringWithFormat:@"x=%.1f y=%.1f", point.x, point.y];
}

static NSString *HoverClickDiagnosticValue(NSString *value, NSString *fallback) {
    if (value.length == 0) {
        return fallback ?: @"unknown";
    }

    return value;
}

// The first cutIndex UTF-16 units, or fewer: the cut moves back to the start of a surrogate pair
// or combining sequence that straddles it. A lone surrogate makes -UTF8String return NULL, and the
// whole log line then prints (null).
static NSString *HoverClickSafePrefix(NSString *value, NSUInteger cutIndex) {
    if (cutIndex >= value.length) {
        return value;
    }

    NSUInteger end = [value rangeOfComposedCharacterSequenceAtIndex:cutIndex].location;
    return [value substringToIndex:end];
}

static NSString *HoverClickTruncatedDiagnosticString(NSString *value, NSUInteger maxLength) {
    if (value.length == 0 || value.length <= maxLength || maxLength <= 3) {
        return value ?: @"";
    }

    return [HoverClickSafePrefix(value, maxLength - 3) stringByAppendingString:@"..."];
}

static BOOL HoverClickStringContainsCaseInsensitive(NSString *value, NSString *needle) {
    if (value.length == 0 || needle.length == 0) {
        return NO;
    }

    return [value rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static NSString *HoverClickMenuItemTitle(NSString *title) {
    return title ?: @"";
}

static NSImage *HoverClickMenuSystemImage(NSString *symbolName, NSString *fallbackSymbolName) {
    if (@available(macOS 11.0, *)) {
        // The empty Excluded Apps row passes no symbol name; the parameter is nonnull.
        NSImage *image = symbolName.length > 0 ?
            [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil] : nil;
        if (image == nil && fallbackSymbolName.length > 0) {
            image = [NSImage imageWithSystemSymbolName:fallbackSymbolName
                              accessibilityDescription:nil];
        }
        if (image != nil) {
            NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:HoverClickMenuImagePointSize
                                                                                                        weight:NSFontWeightRegular
                                                                                                         scale:NSImageSymbolScaleMedium];
            image = [image imageWithSymbolConfiguration:configuration] ?: image;
            [image setTemplate:YES];
            image.size = NSMakeSize(HoverClickMenuImageSize, HoverClickMenuImageSize);
        }
        return image;
    }

    return nil;
}

@interface HoverClickMenuRowView : NSView
@property(nonatomic, weak) NSMenuItem *menuItem;
@property(nonatomic, weak) id actionTarget;
@property(nonatomic) SEL actionSelector;
@property(nonatomic, strong) NSImageView *iconView;
@property(nonatomic, strong) NSTextField *titleField;
@property(nonatomic, strong) NSTextField *stateField;
@property(nonatomic, strong) NSTextField *accessoryField;
@property(nonatomic) BOOL rowEnabled;
@property(nonatomic) BOOL highlighted;
@property(nonatomic) BOOL closesMenuAfterAction;
@property(nonatomic) BOOL showsSubmenuArrow;
@property(nonatomic) BOOL useSubtleAccessory;
- (instancetype)initWithMenuItem:(NSMenuItem *)menuItem
                           image:(NSImage *)image
                  accessoryTitle:(NSString *)accessoryTitle
                  showsStateView:(BOOL)showsStateView;
- (instancetype)initWithMenuItem:(NSMenuItem *)menuItem
                           image:(NSImage *)image
                  accessoryTitle:(NSString *)accessoryTitle
                  showsStateView:(BOOL)showsStateView
                        rowWidth:(CGFloat)rowWidth;
- (void)syncFromMenuItem;
@end

@implementation HoverClickMenuRowView

- (instancetype)initWithMenuItem:(NSMenuItem *)menuItem
                           image:(NSImage *)image
                  accessoryTitle:(NSString *)accessoryTitle
                  showsStateView:(BOOL)showsStateView {
    return [self initWithMenuItem:menuItem
                            image:image
                   accessoryTitle:accessoryTitle
                   showsStateView:showsStateView
                         rowWidth:HoverClickMenuRowWidth];
}

- (instancetype)initWithMenuItem:(NSMenuItem *)menuItem
                           image:(NSImage *)image
                  accessoryTitle:(NSString *)accessoryTitle
                  showsStateView:(BOOL)showsStateView
                        rowWidth:(CGFloat)rowWidth {
    self = [super initWithFrame:NSMakeRect(0.0, 0.0, rowWidth, HoverClickMenuRowHeight)];
    if (self == nil) {
        return nil;
    }

    _menuItem = menuItem;
    _actionTarget = menuItem.target;
    _actionSelector = menuItem.action;
    _rowEnabled = menuItem.enabled;

    if (image != nil) {
        _iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(HoverClickMenuRowIconX,
                                                                  3.0,
                                                                  HoverClickMenuImageSize,
                                                                  HoverClickMenuImageSize)];
        _iconView.image = image;
        _iconView.imageScaling = NSImageScaleProportionallyDown;
        [self addSubview:_iconView];
    }

    _titleField = [NSTextField labelWithString:menuItem.title ?: @""];
    _titleField.font = [NSFont menuFontOfSize:0.0];
    _titleField.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_titleField];

    if (accessoryTitle.length > 0) {
        _accessoryField = [NSTextField labelWithString:accessoryTitle];
        _accessoryField.alignment = NSTextAlignmentRight;
        _accessoryField.font = [NSFont menuFontOfSize:0.0];
        _accessoryField.lineBreakMode = NSLineBreakByClipping;
        [self addSubview:_accessoryField];
    }

    _stateField = [NSTextField labelWithString:@""];
    _stateField.alignment = NSTextAlignmentRight;
    _stateField.font = [NSFont menuFontOfSize:0.0];
    _stateField.lineBreakMode = NSLineBreakByClipping;
    // showsStateView is kept for the call sites only: -syncFromMenuItem shows the state field
    // exactly when there is a glyph to draw, so the argument never changed the result.
    (void)showsStateView;
    [self addSubview:_stateField];

    [self layoutRowSubviewsForWidth:rowWidth];
    [self syncFromMenuItem];
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)layoutRowSubviewsForWidth:(CGFloat)w {
    CGFloat rightAccessoryX = w - HoverClickMenuTrailingInset - HoverClickMenuRightAccessoryWidth;
    CGFloat titleX = (_iconView != nil) ? HoverClickMenuRowTextX : HoverClickMenuLeadingInset;
    NSRect accessoryFrame = NSMakeRect(rightAccessoryX - HoverClickMenuRowAccessoryOverhang,
                                       HoverClickMenuRowFieldY,
                                       HoverClickMenuRightAccessoryWidth + HoverClickMenuRowAccessoryOverhang,
                                       HoverClickMenuRowFieldHeight);
    _titleField.frame = NSMakeRect(titleX, HoverClickMenuRowFieldY,
                                   rightAccessoryX - titleX, HoverClickMenuRowFieldHeight);
    if (_accessoryField != nil) {
        _accessoryField.frame = accessoryFrame;
    }
    _stateField.frame = accessoryFrame;
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self layoutRowSubviewsForWidth:newSize.width];
}

- (void)setHighlighted:(BOOL)highlighted {
    _highlighted = highlighted;
    [self setNeedsDisplay:YES];
    [self syncFromMenuItem];
}

- (void)setUseSubtleAccessory:(BOOL)useSubtleAccessory {
    _useSubtleAccessory = useSubtleAccessory;
    [self syncFromMenuItem];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas.copy) {
        [self removeTrackingArea:area];
    }
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                        options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways)
                                                          owner:self
                                                       userInfo:nil];
    [self addTrackingArea:area];
}

- (void)mouseEntered:(NSEvent *)event {
    (void)event;
    if (self.rowEnabled) {
        self.highlighted = YES;
    }
}

- (void)mouseExited:(NSEvent *)event {
    (void)event;
    self.highlighted = NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    if (self.highlighted && self.rowEnabled) {
        NSRect highlightRect = NSInsetRect(self.bounds, 5.0, 2.0);
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:highlightRect xRadius:5.0 yRadius:5.0];
        [[NSColor selectedContentBackgroundColor] setFill];
        [path fill];
    }
}

- (void)syncFromMenuItem {
    NSMenuItem *item = self.menuItem;
    self.rowEnabled = (item == nil || item.enabled);
    self.titleField.stringValue = item.title ?: @"";

    NSColor *textColor = self.rowEnabled ? [NSColor controlTextColor] : [NSColor disabledControlTextColor];
    if (self.highlighted && self.rowEnabled) {
        textColor = [NSColor selectedMenuItemTextColor];
    }
    self.titleField.textColor = textColor;
    self.stateField.textColor = textColor;
    NSColor *accessoryColor = textColor;
    if (self.useSubtleAccessory && !(self.highlighted && self.rowEnabled)) {
        accessoryColor = [NSColor tertiaryLabelColor];
    }
    self.accessoryField.textColor = accessoryColor;

    self.iconView.alphaValue = self.rowEnabled ? 1.0 : 0.35;
    self.stateField.alphaValue = self.rowEnabled ? 1.0 : 0.35;
    self.accessoryField.alphaValue = self.rowEnabled ? 1.0 : 0.35;

    if (@available(macOS 10.14, *)) {
        if (self.iconView != nil) {
            self.iconView.contentTintColor = textColor;
        }
    }

    NSString *stateGlyph = @"";
    if (self.showsSubmenuArrow) {
        stateGlyph = @"▸";
    } else if (item.state == NSControlStateValueOn) {
        stateGlyph = @"✓";
    } else if (item.state == NSControlStateValueMixed) {
        stateGlyph = @"–";
    }
    self.stateField.stringValue = stateGlyph;
    self.stateField.hidden = (stateGlyph.length == 0);
    if (self.showsSubmenuArrow) {
        if (self.highlighted && self.rowEnabled) {
            self.stateField.textColor = [NSColor selectedMenuItemTextColor];
        } else if (self.rowEnabled) {
            self.stateField.textColor = [NSColor secondaryLabelColor];
        } else {
            self.stateField.textColor = [NSColor disabledControlTextColor];
        }
    }
}

- (void)mouseDown:(NSEvent *)event {
    if (!self.rowEnabled) {
        return;
    }

    self.highlighted = YES;
    BOOL shouldSendAction = NO;
    while (YES) {
        NSEvent *nextEvent = [[self window] nextEventMatchingMask:(NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp)];
        if (nextEvent == nil) {
            break;
        }
        if (nextEvent.type == NSEventTypeLeftMouseUp) {
            NSPoint point = [self convertPoint:nextEvent.locationInWindow fromView:nil];
            shouldSendAction = NSPointInRect(point, self.bounds);
            break;
        }
    }

    self.highlighted = NO;
    if (shouldSendAction && self.actionTarget != nil && self.actionSelector != NULL) {
        [NSApp sendAction:self.actionSelector to:self.actionTarget from:self.menuItem ?: self];
        if (self.closesMenuAfterAction) {
            [self.menuItem.menu cancelTracking];
        }
    }
    if (!self.closesMenuAfterAction) {
        NSWindow *win = self.window;
        if (win != nil) {
            NSPoint winPt = [win convertPointFromScreen:[NSEvent mouseLocation]];
            NSPoint viewPt = [self convertPoint:winPt fromView:nil];
            if (NSPointInRect(viewPt, self.bounds)) {
                self.highlighted = YES;
            }
        }
    }
}

@end

static void HoverClickUseCustomSubmenuRow(NSMenuItem *item,
                                           NSString *symbolName,
                                           NSString *fallbackSymbolName,
                                           NSString *accessoryTitle,
                                           BOOL showsStateView,
                                           BOOL closesMenuAfterAction,
                                           CGFloat rowWidth) {
    NSImage *image = HoverClickMenuSystemImage(symbolName, fallbackSymbolName);
    HoverClickMenuRowView *rowView = [[HoverClickMenuRowView alloc] initWithMenuItem:item
                                                                               image:image
                                                                      accessoryTitle:accessoryTitle
                                                                      showsStateView:showsStateView
                                                                            rowWidth:rowWidth];
    rowView.closesMenuAfterAction = closesMenuAfterAction;
    if (item.toolTip.length > 0) {
        rowView.toolTip = item.toolTip;
    }
    item.view = rowView;
}

static void HoverClickUseCustomMenuRow(NSMenuItem *item,
                                       NSString *symbolName,
                                       NSString *fallbackSymbolName,
                                       NSString *accessoryTitle,
                                       BOOL showsStateView,
                                       BOOL closesMenuAfterAction) {
    HoverClickUseCustomSubmenuRow(item, symbolName, fallbackSymbolName, accessoryTitle,
                                  showsStateView, closesMenuAfterAction, HoverClickMenuRowWidth);
}

static void HoverClickUseClosingMenuRow(NSMenuItem *item, NSString *symbolName, NSString *fallbackSymbolName) {
    HoverClickUseCustomMenuRow(item, symbolName, fallbackSymbolName, nil, NO, YES);
}

static void HoverClickUseClosingPlainMenuRow(NSMenuItem *item, NSString *accessoryTitle) {
    HoverClickUseCustomMenuRow(item, nil, nil, accessoryTitle, NO, YES);
}

static void HoverClickUseNonClosingMenuRow(NSMenuItem *item, NSString *symbolName, NSString *fallbackSymbolName, BOOL showsStateView) {
    HoverClickUseCustomMenuRow(item, symbolName, fallbackSymbolName, nil, showsStateView, NO);
}

static CGFloat HoverClickMeasureMenuTitleWidth(NSString *title) {
    NSFont *font = [NSFont menuFontOfSize:0.0];
    NSDictionary *attrs = @{NSFontAttributeName: font};
    return ceil([title sizeWithAttributes:attrs].width);
}

static const CGFloat HoverClickSubmenuSafetyPadding = 10.0;

static CGFloat HoverClickCalculatedSubmenuWidth(NSArray<NSString *> *titles) {
    CGFloat maxTitleWidth = 0.0;
    for (NSString *title in titles) {
        CGFloat w = HoverClickMeasureMenuTitleWidth(title);
        if (w > maxTitleWidth) {
            maxTitleWidth = w;
        }
    }
    // Submenu child rows have an icon: titleX = HoverClickMenuRowTextX (icon + spacing).
    // rowWidth = titleText + safetyPad + textX + accessory + trailing
    CGFloat width = maxTitleWidth + HoverClickSubmenuSafetyPadding
                    + HoverClickMenuRowTextX
                    + HoverClickMenuRightAccessoryWidth
                    + HoverClickMenuTrailingInset;
    if (width > HoverClickMenuContentWidth) {
        width = HoverClickMenuContentWidth;
    }
    return width;
}

static void HoverClickUseClosingSubmenuRow(NSMenuItem *item, NSString *symbolName, NSString *fallbackSymbolName, CGFloat rowWidth) {
    HoverClickUseCustomSubmenuRow(item, symbolName, fallbackSymbolName, nil, NO, YES, rowWidth);
}

static void HoverClickUseNonClosingSubmenuRow(NSMenuItem *item, NSString *symbolName, NSString *fallbackSymbolName, BOOL showsStateView, CGFloat rowWidth) {
    HoverClickUseCustomSubmenuRow(item, symbolName, fallbackSymbolName, nil, showsStateView, NO, rowWidth);
}

static void HoverClickUseSubmenuMenuRow(NSMenuItem *item, NSString *symbolName, NSString *fallbackSymbolName) {
    NSImage *image = HoverClickMenuSystemImage(symbolName, fallbackSymbolName);
    HoverClickMenuRowView *rowView = [[HoverClickMenuRowView alloc] initWithMenuItem:item
                                                                               image:image
                                                                      accessoryTitle:nil
                                                                      showsStateView:NO];
    rowView.showsSubmenuArrow = YES;
    rowView.closesMenuAfterAction = NO;
    [rowView syncFromMenuItem];
    item.view = rowView;
}

static void HoverClickSyncMenuRowView(NSMenuItem *item) {
    if ([item.view isKindOfClass:[HoverClickMenuRowView class]]) {
        [(HoverClickMenuRowView *)item.view syncFromMenuItem];
    }
}

// Builds a non-actionable Quick Help entry: an emphasized feature name with a short, word-wrapped
// description below it. Used only inside the dedicated Quick Help submenu. This is the visible,
// reliable replacement for native in-menu hover tooltips, which AppKit does not display for
// custom NSView-backed menu rows: NSMenu's modal tracking run loop never drives NSView tooltip
// display, and item.view bypasses NSMenuItem.toolTip entirely (see the tooltip baseline note in
// docs/CURRENT_STATE.md and the reverted ui-menu-tooltips attempt). The entry adds no tracking
// areas, timers, monitors, or event taps; the owning NSMenuItem stays disabled so the row is
// informational only and is skipped by the highlight-reset pass (it is not a HoverClickMenuRowView).
static const CGFloat HoverClickQuickHelpWidth = HoverClickMenuContentWidth;
static const CGFloat HoverClickQuickHelpVerticalPadding = 4.0;
static const CGFloat HoverClickQuickHelpTitleHeight = 14.0;
static const CGFloat HoverClickQuickHelpTitleDetailGap = 1.0;

static NSMenuItem *HoverClickCreateQuickHelpItem(NSString *title, NSString *detail) {
    CGFloat textX = HoverClickMenuLeadingInset;
    CGFloat textWidth = HoverClickQuickHelpWidth - textX - HoverClickMenuTrailingInset;

    NSFont *detailFont = [NSFont systemFontOfSize:11.0];
    NSRect detailRect = [detail boundingRectWithSize:NSMakeSize(textWidth, CGFLOAT_MAX)
                                             options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                          attributes:@{NSFontAttributeName: detailFont}];
    // +2 guards against a one-pixel difference between boundingRect measurement and the
    // wrapping label's own layout so the final line never clips.
    CGFloat detailHeight = ceil(detailRect.size.height) + 2.0;

    CGFloat totalHeight = HoverClickQuickHelpVerticalPadding + detailHeight
                          + HoverClickQuickHelpTitleDetailGap + HoverClickQuickHelpTitleHeight
                          + HoverClickQuickHelpVerticalPadding;

    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, HoverClickQuickHelpWidth, totalHeight)];

    // Unflipped container (origin bottom-left): description sits below, emphasized title above it.
    NSTextField *detailLabel = [NSTextField wrappingLabelWithString:detail];
    detailLabel.font = detailFont;
    detailLabel.textColor = [[NSColor labelColor] colorWithAlphaComponent:0.65];
    detailLabel.preferredMaxLayoutWidth = textWidth;
    detailLabel.frame = NSMakeRect(textX, HoverClickQuickHelpVerticalPadding, textWidth, detailHeight);
    [container addSubview:detailLabel];

    NSTextField *titleLabel = [NSTextField labelWithString:title];
    titleLabel.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightMedium];
    titleLabel.textColor = [NSColor labelColor];
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.frame = NSMakeRect(textX,
                                  HoverClickQuickHelpVerticalPadding + detailHeight + HoverClickQuickHelpTitleDetailGap,
                                  textWidth,
                                  HoverClickQuickHelpTitleHeight);
    [container addSubview:titleLabel];

    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(title)
                                                  action:nil
                                           keyEquivalent:@""];
    item.enabled = NO;
    item.view = container;
    return item;
}

static NSTextField *HoverClickSectionHeaderLabel(NSString *title, CGFloat rowWidth, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:HoverClickMenuItemTitle(title)];
    label.frame = NSMakeRect(HoverClickSectionHeaderLeadingInset,
                             HoverClickSectionHeaderLabelY,
                             rowWidth - HoverClickSectionHeaderLeadingInset - HoverClickMenuTrailingInset,
                             HoverClickSectionHeaderLabelHeight);
    label.font = [NSFont systemFontOfSize:HoverClickSectionHeaderFontSize weight:NSFontWeightRegular];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

static NSMenuItem *HoverClickCreateSectionHeaderMenuItem(NSString *title) {
    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(title)
                                                        action:nil
                                                 keyEquivalent:@""];
    headerItem.enabled = NO;
    headerItem.indentationLevel = 0;
    headerItem.state = NSControlStateValueOff;

    NSView *headerView = [[NSView alloc] initWithFrame:NSMakeRect(0.0,
                                                                  0.0,
                                                                  HoverClickMenuContentWidth,
                                                                  HoverClickSectionHeaderHeight)];
    [headerView addSubview:HoverClickSectionHeaderLabel(title, HoverClickMenuContentWidth,
                                                        [NSColor disabledControlTextColor])];
    headerItem.view = headerView;
    return headerItem;
}

static NSMenuItem *HoverClickCreateInfoSectionHeaderMenuItem(void) {
    return HoverClickCreateSectionHeaderMenuItem(@"Info");
}

// Width-aware section header for use inside submenus whose width differs from HoverClickMenuContentWidth.
// Uses secondaryLabelColor so the category label is slightly more legible than disabledControlTextColor.
static NSMenuItem *HoverClickCreateSubmenuSectionHeader(NSString *title, CGFloat rowWidth) {
    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(title)
                                                        action:nil
                                                 keyEquivalent:@""];
    headerItem.enabled = NO;
    NSView *headerView = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, rowWidth, HoverClickSectionHeaderHeight)];
    [headerView addSubview:HoverClickSectionHeaderLabel(title, rowWidth, [NSColor secondaryLabelColor])];
    headerItem.view = headerView;
    return headerItem;
}

// Non-interactive auto-added row: lock icon + app name, no right-side accessory.
// Used for Maccy's always-active built-in bypass: disabled (non-actionable, non-removable),
// rendered with a lock icon and secondaryLabelColor text so it reads as managed/locked
// rather than disabled-to-the-point-of-being-unreadable.
static NSMenuItem *HoverClickCreateAutomaticEntryItem(NSString *appName, CGFloat rowWidth) {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, rowWidth, HoverClickMenuRowHeight)];
    NSColor *mutedColor = [NSColor secondaryLabelColor];

    NSImage *lockImage = HoverClickMenuSystemImage(@"lock", @"lock.fill");
    if (lockImage != nil) {
        NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(HoverClickMenuRowIconX,
                                                                              3.0,
                                                                              HoverClickMenuImageSize,
                                                                              HoverClickMenuImageSize)];
        iconView.image = lockImage;
        iconView.imageScaling = NSImageScaleProportionallyDown;
        if (@available(macOS 10.14, *)) {
            iconView.contentTintColor = mutedColor;
        }
        [container addSubview:iconView];
    }

    CGFloat titleX = (lockImage != nil) ? HoverClickMenuRowTextX : HoverClickMenuLeadingInset;
    NSTextField *titleField = [NSTextField labelWithString:appName ?: @""];
    titleField.frame = NSMakeRect(titleX, 2.0, rowWidth - titleX - HoverClickMenuTrailingInset, 18.0);
    titleField.font = [NSFont menuFontOfSize:0.0];
    titleField.textColor = mutedColor;
    titleField.lineBreakMode = NSLineBreakByTruncatingTail;
    [container addSubview:titleField];

    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(appName)
                                                  action:nil
                                           keyEquivalent:@""];
    item.enabled = NO;
    item.view = container;
    return item;
}

static NSMenuItem *HoverClickCreateUpdatesSectionHeaderMenuItem(void) {
    NSString *versionText = [NSString stringWithFormat:@"Version: %@", HoverClickDisplayVersion()];
    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Updates")
                                                        action:nil
                                                 keyEquivalent:@""];
    headerItem.enabled = NO;
    headerItem.indentationLevel = 0;
    headerItem.state = NSControlStateValueOff;

    CGFloat fullLabelWidth = HoverClickMenuContentWidth - HoverClickSectionHeaderLeadingInset - HoverClickMenuTrailingInset;
    NSView *headerView = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, HoverClickMenuContentWidth, HoverClickSectionHeaderHeight)];

    NSTextField *leftLabel = [NSTextField labelWithString:@"Updates"];
    leftLabel.frame = NSMakeRect(HoverClickSectionHeaderLeadingInset,
                                 HoverClickSectionHeaderLabelY,
                                 fullLabelWidth,
                                 HoverClickSectionHeaderLabelHeight);
    leftLabel.font = [NSFont systemFontOfSize:HoverClickSectionHeaderFontSize weight:NSFontWeightRegular];
    leftLabel.textColor = [NSColor disabledControlTextColor];
    leftLabel.lineBreakMode = NSLineBreakByClipping;
    [headerView addSubview:leftLabel];

    NSTextField *rightLabel = [NSTextField labelWithString:versionText];
    rightLabel.frame = NSMakeRect(HoverClickSectionHeaderLeadingInset,
                                  HoverClickSectionHeaderLabelY,
                                  fullLabelWidth,
                                  HoverClickSectionHeaderLabelHeight);
    rightLabel.font = [NSFont systemFontOfSize:HoverClickSectionHeaderFontSize weight:NSFontWeightRegular];
    rightLabel.textColor = [NSColor disabledControlTextColor];
    rightLabel.alignment = NSTextAlignmentRight;
    rightLabel.lineBreakMode = NSLineBreakByTruncatingHead;
    [headerView addSubview:rightLabel];

    headerItem.view = headerView;
    return headerItem;
}

static void HoverClickLog(const char *format, ...) __attribute__((format(printf, 1, 2)));
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

static NSString *HoverClickAXAttemptSummary(BOOL attempted, AXError error) {
    if (!attempted) {
        return @"not-attempted";
    }

    return [NSString stringWithFormat:@"attempted:%s", HoverClickAXErrorName(error)];
}

// One AX read for a diagnostic line, held to the callback deadline. Once a read has been cut
// short, by the deadline or by a timed-out read, every later read is skipped as well: an
// application that did not answer one read blocks the next one the same way.
static AXError HoverClickCopyAXAttributeBeforeDeadline(AXUIElementRef element, CFStringRef attribute, CFTypeRef *outValue, CFAbsoluteTime deadline, const char **cutShort) {
    *outValue = NULL;
    if (*cutShort != NULL) {
        return kAXErrorCannotComplete;
    }
    if (CFAbsoluteTimeGetCurrent() >= deadline) {
        *cutShort = "budget";
        return kAXErrorCannotComplete;
    }

    AXError error = AXUIElementCopyAttributeValue(element, attribute, outValue);
    if (error == kAXErrorCannotComplete) {
        *cutShort = "cannotComplete";
    }
    return error;
}

// Title plus geometry. Two windows of the same application frequently share a title, so the
// geometry is what makes a focus diagnostic line usable.
static NSString *HoverClickAXWindowIdentity(AXUIElementRef window, CFAbsoluteTime deadline) {
    if (window == NULL) {
        return @"none";
    }

    const char *cutShort = NULL;
    NSString *title = nil;
    CFTypeRef titleValue = NULL;
    if (HoverClickCopyAXAttributeBeforeDeadline(window, kAXTitleAttribute, &titleValue, deadline, &cutShort) == kAXErrorSuccess && titleValue != NULL) {
        if (CFGetTypeID(titleValue) == CFStringGetTypeID()) {
            title = [(__bridge NSString *)titleValue copy];
        }
        CFRelease(titleValue);
    }
    if (title.length == 0) {
        title = @"untitled";
    } else if (title.length > 48) {
        title = [HoverClickSafePrefix(title, 48) stringByAppendingString:@"..."];
    }

    CGPoint position = CGPointMake(-1.0, -1.0);
    CFTypeRef positionValue = NULL;
    if (HoverClickCopyAXAttributeBeforeDeadline(window, kAXPositionAttribute, &positionValue, deadline, &cutShort) == kAXErrorSuccess && positionValue != NULL) {
        if (CFGetTypeID(positionValue) == AXValueGetTypeID()) {
            AXValueGetValue((AXValueRef)positionValue, kAXValueTypeCGPoint, &position);
        }
        CFRelease(positionValue);
    }

    CGSize size = CGSizeMake(-1.0, -1.0);
    CFTypeRef sizeValue = NULL;
    if (HoverClickCopyAXAttributeBeforeDeadline(window, kAXSizeAttribute, &sizeValue, deadline, &cutShort) == kAXErrorSuccess && sizeValue != NULL) {
        if (CFGetTypeID(sizeValue) == AXValueGetTypeID()) {
            AXValueGetValue((AXValueRef)sizeValue, kAXValueTypeCGSize, &size);
        }
        CFRelease(sizeValue);
    }

    NSString *identity = [NSString stringWithFormat:@"title=\"%@\" pos=(%.0f,%.0f) size=(%.0fx%.0f)",
                                                    title,
                                                    position.x,
                                                    position.y,
                                                    size.width,
                                                    size.height];
    if (cutShort != NULL) {
        identity = [identity stringByAppendingFormat:@" identity=partial(%s)", cutShort];
    }
    return identity;
}

// Reads back the application's own kAXFocusedWindowAttribute and reports whether it is the window
// that was clicked. The frontmost-process check cannot answer that question: it only sees which
// process is in front, never which of its windows holds focus.
static NSString *HoverClickFocusedWindowComparison(AXUIElementRef appElement, AXUIElementRef targetWindow, CFAbsoluteTime deadline) {
    if (appElement == NULL) {
        return @"appFocusedWindow=no-app-element match=unknown";
    }
    if (CFAbsoluteTimeGetCurrent() >= deadline) {
        return @"appFocusedWindow=skipped(budget) match=unknown";
    }

    CFTypeRef focusedValue = NULL;
    AXError readError = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute, &focusedValue);
    if (readError != kAXErrorSuccess || focusedValue == NULL) {
        if (focusedValue != NULL) {
            CFRelease(focusedValue);
        }
        return [NSString stringWithFormat:@"appFocusedWindow=read-failed(%s) match=unknown", HoverClickAXErrorName(readError)];
    }

    NSString *result = @"appFocusedWindow=unexpected-type match=unknown";
    if (CFGetTypeID(focusedValue) == AXUIElementGetTypeID()) {
        AXUIElementRef focusedWindow = (AXUIElementRef)focusedValue;
        BOOL matches = (targetWindow != NULL && CFEqual(focusedWindow, targetWindow));
        result = [NSString stringWithFormat:@"appFocusedWindow=[%@] match=%s",
                                            HoverClickAXWindowIdentity(focusedWindow, deadline),
                                            matches ? "YES" : "NO"];
    }

    CFRelease(focusedValue);
    return result;
}

// The application the Accessibility server reports as focused, read from the system-wide element.
// Unlike NSWorkspace.frontmostApplication this does not depend on the main run loop, so it can be
// read inside the tap callback. Returns 0 when the read fails or times out.
static pid_t HoverClickAXFocusedApplicationPid(void) {
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    if (systemWide == NULL) {
        return 0;
    }
    AXUIElementSetMessagingTimeout(systemWide, HoverClickAXMessagingTimeoutSeconds);

    pid_t pid = 0;
    CFTypeRef value = NULL;
    if (AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute, &value) == kAXErrorSuccess && value != NULL) {
        if (CFGetTypeID(value) == AXUIElementGetTypeID()) {
            AXUIElementGetPid((AXUIElementRef)value, &pid);
        }
        CFRelease(value);
    }
    CFRelease(systemWide);
    return pid;
}

@interface HoverClickAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *permissionItem;
@property(nonatomic, strong) NSMenuItem *permissionRefreshItem;
@property(nonatomic, strong) NSMenuItem *clickToFocusItem;
@property(nonatomic, strong) NSMenuItem *rightClickFocusItem;
@property(nonatomic, strong) NSMenuItem *launchAtLoginItem;
@property(nonatomic, strong) NSMenuItem *diagnosticsItem;
@property(nonatomic, strong) NSMenuItem *verboseItem;
@property(nonatomic, strong) NSMenuItem *checkForUpdatesItem;
@property(nonatomic, strong) NSMenuItem *automaticUpdateChecksItem;
@property(nonatomic, strong) NSMenuItem *diagnosticsCopyItem;
@property(nonatomic, strong) NSMenuItem *bypassKeyItem;
@property(nonatomic, strong) NSMenuItem *excludedAppsItem;
@property(nonatomic, strong) SPUStandardUpdaterController *updaterController;
@property(nonatomic, strong) NSAlert *accessibilityOnboardingAlert;
- (void)recordEventTapCallbackWithType:(CGEventType)type event:(CGEventRef)event proxy:(CGEventTapProxy)proxy;
- (void)recordFocusDecisionWithTrigger:(const char *)trigger sequenceID:(uint64_t)sequenceID decision:(NSString *)decision detail:(NSString *)detail;
- (void)recordBackgroundFocusAttemptWithTrigger:(const char *)trigger sequenceID:(uint64_t)sequenceID appName:(NSString *)appName pid:(pid_t)targetPid frontmostBefore:(NSString *)frontmostBefore;
- (void)recordBackgroundFocusResult:(NSString *)result verification:(NSString *)verification failureReason:(NSString *)failureReason;
- (void)completeDelayedBackgroundFocusVerification:(NSDictionary *)context;
- (void)handleEventTapDisabledWithReason:(NSString *)reason shouldReenable:(BOOL)shouldReenable;
- (void)recordPermissionCheckResult:(NSString *)result;
- (void)removeEventTapDueToMissingAccessibilityWithReason:(NSString *)reason;
- (BOOL)refreshAccessibilityStatusForReason:(NSString *)reason promptIfMissing:(BOOL)promptIfMissing updateLastAction:(BOOL)updateLastAction;
- (void)handleEventTapCallbackWithMissingAccessibilityForType:(CGEventType)type;
- (void)handleLeftMouseDown:(CGEventRef)event;
- (void)handleRightMouseDown:(CGEventRef)event;
- (BOOL)skipKeyHeldForEvent:(CGEventRef)event clickLabel:(const char *)clickLabel;
- (void)finishSkippedClickWithSequenceID:(uint64_t)sequenceID
                                 trigger:(const char *)trigger
                                  detail:(NSString *)detail
                             focusStatus:(NSString *)focusStatus
                               finalNote:(NSString *)finalNote
                             finalResult:(NSString *)finalResult
                             clickResult:(NSString *)clickResult;
// Both loggers are printf-style: clang checks their arguments, so an NSString handed to %s or
// a %@ conversion is a compile error instead of a garbled log line.
- (void)diagnosticLog:(const char *)format, ... __attribute__((format(printf, 1, 2)));
- (NSTimeInterval)callbackElapsed;
- (NSTimeInterval)callbackBudgetRemaining;
- (BOOL)callbackBudgetExhaustedForSequenceID:(uint64_t)sequenceID trigger:(const char *)trigger stage:(const char *)stage;
- (void)applyAccessibilityMessagingTimeoutToElement:(AXUIElementRef)element;
- (void)applyGlobalAccessibilityMessagingTimeout;
- (NSArray<NSString *> *)userExcludedBundleIDs;
- (NSArray<NSDictionary<NSString *, id> *> *)installedApplicationsForSelector;
- (NSString *)displayNameForExcludedBundleID:(NSString *)bundleID;
- (void)buildExcludedAppsSubmenu;
- (void)resetMenuRowHighlightsInMenu:(NSMenu *)menu;
- (void)chooseExcludedApp:(id)sender;
- (BOOL)addExcludedBundleID:(NSString *)candidate;
- (void)removeExcludedApp:(id)sender;
- (void)showInformationalAlertWithTitle:(NSString *)title message:(NSString *)message;
- (BOOL)isChromeApplication:(NSRunningApplication *)app;
- (BOOL)isBuiltInCompatibilityBypassApplication:(NSRunningApplication *)app;
- (NSString *)browserContentDiagnosticNoteForTargetApp:(NSRunningApplication *)targetApp
                                               appName:(NSString *)appName
                                                  role:(NSString *)role
                                               subrole:(NSString *)subrole
                                          elementTitle:(NSString *)elementTitle
                                            windowRole:(NSString *)windowRole
                                           windowTitle:(NSString *)windowTitle
                                           focusStatus:(NSString *)focusStatus;
- (void)recordClickThroughInvestigationForSequenceID:(uint64_t)sequenceID
                                         focusStatus:(NSString *)focusStatus
                                           finalNote:(NSString *)finalNote;
- (void)showAccessibilityOnboardingIfNeeded;
- (void)offerLaunchAtLoginOnboardingIfNeeded;
- (void)showAboutHoverClick:(id)sender;
- (void)selectBypassKey:(id)sender;
- (void)openURLString:(NSString *)urlString label:(NSString *)label;
- (void)openGitHub:(id)sender;
- (void)openContact:(id)sender;
- (void)openReleaseNotes:(id)sender;
- (void)showUninstallInstructions:(id)sender;
- (void)quitApplication:(id)sender;
@end

@implementation HoverClickAppDelegate {
    BOOL _userWantsEventTap;
    BOOL _eventTapInstalled;
    BOOL _eventTapEnabled;
    BOOL _clickToFocusEnabled;
    BOOL _rightClickFocusEnabled;
    BOOL _verboseDiagnostics;
    BOOL _accessibilityOnboardingShownThisLaunch;
    BOOL _accessibilityTrustPromptRequestedThisLaunch;
    BOOL _launchAtLoginOnboardingOfferedThisLaunch;
    BOOL _permissionMissingPassThroughActive;
    BOOL _eventTapRemovedDueToMissingPermission;
    BOOL _eventTapRemovalScheduledDueToMissingPermission;
    BOOL _showRefreshStatusFeedback;
    NSUInteger _copyFeedbackGeneration;
    NSUInteger _refreshFeedbackGeneration;
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _eventTapSource;
    CFAbsoluteTime _lastMouseDownLogTime;
    CFAbsoluteTime _lastRightMouseDownLogTime;
    CFAbsoluteTime _lastLeftMouseDownSeenTime;
    CFAbsoluteTime _lastRightMouseDownSeenTime;
    NSTimeInterval _lastEventTapCallbackTime;
    CFAbsoluteTime _lastEventTapRecoveryAttemptTime;
    CFAbsoluteTime _lastBackgroundFocusAttemptTime;
    CFAbsoluteTime _lastSuccessfulBackgroundFocusTime;
    CFAbsoluteTime _lastRightClickFocusTime;
    pid_t _lastRightClickFocusPid;
    CFAbsoluteTime _lastFinderRightClickTime;
    pid_t _lastFinderRightClickPid;
    uint64_t _clickSequence;
    uint64_t _lastBackgroundFocusSequence;
    uint64_t _totalMouseCallbacksSeen;
    uint64_t _totalLeftMouseCallbacksSeen;
    uint64_t _totalRightMouseCallbacksSeen;
    uint64_t _totalNonMenuMouseCallbacks;
    uint64_t _totalFocusAttempts;
    uint64_t _totalSuccessfulFocusVerifications;
    uint64_t _totalPolicySkips;
    uint64_t _totalOverlaySystemUISkips;
    uint64_t _totalCompactPopupSkips;
    uint64_t _totalMenuStatusUISkips;
    uint64_t _eventTapPermissionMissingPassThroughCount;
    CFAbsoluteTime _lastPermissionCheckTime;
    NSString *_lastEventTapCallbackDescription;
    NSString *_lastEventTapRecoveryResult;
    NSString *_lastFocusDecisionDescription;
    NSString *_lastRightClickFocusDecisionDescription;
    NSString *_lastRealBackgroundClickDecisionDescription;
    NSString *_lastRealBackgroundClickOverlayDescription;
    NSString *_lastRealBackgroundClickHitTestCandidateDescription;
    NSString *_lastBackgroundFocusTrigger;
    NSString *_lastBackgroundFocusTargetApp;
    NSString *_lastBackgroundFocusFrontmostBefore;
    NSString *_lastBackgroundFocusActivation;
    NSString *_lastBackgroundFocusAXOperations;
    NSString *_lastBackgroundFocusImmediateFrontmost;
    NSString *_lastBackgroundFocusDelayedVerification;
    NSString *_lastBackgroundFocusResult;
    NSString *_lastBackgroundFocusVerification;
    NSString *_lastBackgroundFocusFailureReason;
    NSString *_lastSuccessfulBackgroundFocusDescription;
    NSString *_lastClickResult;
    NSString *_lastNonMenuClickResult;
    NSString *_lastClickThroughInvestigationDescription;
    NSString *_lastOverlaySkipReason;
    NSString *_lastOverlayCandidateDescription;
    NSString *_lastEligibleHitTestCandidateDescription;
    NSString *_lastLaunchAtLoginStatusDescription;
    NSString *_lastLaunchAtLoginOnboardingDecision;
    NSString *_lastPermissionCheckResult;
    NSString *_lastPermissionMissingPassThroughDescription;
    NSString *_lastAutomaticUpdateChecksChangeDescription;
    CFAbsoluteTime _lastAutomaticUpdateChecksChangeTime;
    NSInteger _bypassKey;
    NSString *_lastBypassDecision;
    NSMutableArray<NSMutableDictionary<NSString *, NSString *> *> *_recentDecisionHistory;
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSString *> *> *_activeDecisionHistory;
}

static CGEventRef HoverClickEventTapCallback(CGEventTapProxy proxy,
                                             CGEventType type,
                                             CGEventRef event,
                                             void *refcon) {
    HoverClickAppDelegate *controller = (__bridge HoverClickAppDelegate *)refcon;
    if (controller == nil) {
        return event;
    }

    [controller recordEventTapCallbackWithType:type event:event proxy:proxy];

    if (type == kCGEventTapDisabledByTimeout) {
        HoverClickLog("HoverClick: click listener paused by macOS reason=timeout");
        [controller handleEventTapDisabledWithReason:@"timeout" shouldReenable:YES];
        return event;
    }

    if (type == kCGEventTapDisabledByUserInput) {
        HoverClickLog("HoverClick: click listener paused by macOS reason=user input");
        [controller handleEventTapDisabledWithReason:@"user input" shouldReenable:YES];
        return event;
    }

    if (event == NULL) {
        return NULL;
    }

    if ((type == kCGEventLeftMouseDown || type == kCGEventRightMouseDown) &&
        ![controller accessibilityTrusted]) {
        [controller handleEventTapCallbackWithMissingAccessibilityForType:type];
        return event;
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
    _eventTapEnabled = NO;
    _clickToFocusEnabled = YES;
    _rightClickFocusEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:HoverClickRightClickFocusDefaultsKey];
    _bypassKey = [[NSUserDefaults standardUserDefaults] integerForKey:HoverClickBypassKeyDefaultsKey];
    if (_bypassKey != HoverClickBypassKeyOff && _bypassKey != HoverClickBypassKeyShift && _bypassKey != HoverClickBypassKeyFn) {
        _bypassKey = HoverClickBypassKeyOff;
    }
    _verboseDiagnostics = YES;
    _accessibilityOnboardingShownThisLaunch = NO;
    _accessibilityTrustPromptRequestedThisLaunch = NO;
    _launchAtLoginOnboardingOfferedThisLaunch = NO;
    _permissionMissingPassThroughActive = NO;
    _eventTapRemovedDueToMissingPermission = NO;
    _eventTapRemovalScheduledDueToMissingPermission = NO;
    _eventTap = NULL;
    _eventTapSource = NULL;
    _lastMouseDownLogTime = 0;
    _lastRightMouseDownLogTime = 0;
    _lastLeftMouseDownSeenTime = 0;
    _lastRightMouseDownSeenTime = 0;
    _lastEventTapCallbackTime = 0;
    _lastEventTapRecoveryAttemptTime = 0;
    _lastBackgroundFocusAttemptTime = 0;
    _lastSuccessfulBackgroundFocusTime = 0;
    _lastRightClickFocusTime = 0;
    _lastRightClickFocusPid = 0;
    _lastFinderRightClickTime = 0;
    _lastFinderRightClickPid = 0;
    _clickSequence = 0;
    _lastBackgroundFocusSequence = 0;
    _totalMouseCallbacksSeen = 0;
    _totalLeftMouseCallbacksSeen = 0;
    _totalRightMouseCallbacksSeen = 0;
    _totalNonMenuMouseCallbacks = 0;
    _totalFocusAttempts = 0;
    _totalSuccessfulFocusVerifications = 0;
    _totalPolicySkips = 0;
    _totalOverlaySystemUISkips = 0;
    _totalCompactPopupSkips = 0;
    _totalMenuStatusUISkips = 0;
    _eventTapPermissionMissingPassThroughCount = 0;
    _lastPermissionCheckTime = 0;
    _lastEventTapCallbackDescription = @"none";
    _lastEventTapRecoveryResult = @"none";
    _lastFocusDecisionDescription = @"none";
    _lastRightClickFocusDecisionDescription = @"none";
    _lastRealBackgroundClickDecisionDescription = @"none";
    _lastRealBackgroundClickOverlayDescription = @"none";
    _lastRealBackgroundClickHitTestCandidateDescription = @"none";
    _lastBackgroundFocusTrigger = @"none";
    _lastBackgroundFocusTargetApp = @"none";
    _lastBackgroundFocusFrontmostBefore = @"none";
    _lastBackgroundFocusActivation = @"not attempted";
    _lastBackgroundFocusAXOperations = @"not attempted";
    _lastBackgroundFocusImmediateFrontmost = @"not checked";
    _lastBackgroundFocusDelayedVerification = @"not scheduled";
    _lastBackgroundFocusResult = @"none";
    _lastBackgroundFocusVerification = @"not applicable";
    _lastBackgroundFocusFailureReason = @"none";
    _lastSuccessfulBackgroundFocusDescription = @"never";
    _lastClickResult = @"None";
    _lastNonMenuClickResult = @"None";
    _lastClickThroughInvestigationDescription = @"none";
    _lastOverlaySkipReason = @"none";
    _lastOverlayCandidateDescription = @"none";
    _lastEligibleHitTestCandidateDescription = @"none";
    _lastLaunchAtLoginStatusDescription = nil;
    _lastLaunchAtLoginOnboardingDecision = @"not offered";
    _lastPermissionCheckResult = @"not checked";
    _lastPermissionMissingPassThroughDescription = @"none";
    _lastAutomaticUpdateChecksChangeDescription = @"never";
    _lastBypassDecision = @"none";
    _recentDecisionHistory = [NSMutableArray arrayWithCapacity:HoverClickRecentDecisionHistoryLimit];
    _activeDecisionHistory = [NSMutableDictionary dictionary];

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.updaterController = [[SPUStandardUpdaterController alloc] initWithStartingUpdater:YES
                                                                          updaterDelegate:nil
                                                                        userDriverDelegate:nil];
    [self createStatusItem];
    [self printLaunchStatus];
    [self refreshAccessibilityStatus:nil];
    [self showAccessibilityOnboardingIfNeeded];
    [self offerLaunchAtLoginOnboardingIfNeeded];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    (void)notification;
    [self refreshAccessibilityStatusForReason:@"app became active"
                              promptIfMissing:NO
                             updateLastAction:NO];
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
    button.toolTip = HoverClickStableHelp;

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"HoverClick"];
    [menu setAutoenablesItems:NO];
    menu.delegate = self;

    [menu addItem:HoverClickCreateSectionHeaderMenuItem(@"HoverClick")];

    self.clickToFocusItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Left Click Focus")
                                                       action:@selector(toggleClickToFocus:)
                                                keyEquivalent:@""];
    self.clickToFocusItem.target = self;
    self.clickToFocusItem.enabled = YES;
    self.clickToFocusItem.indentationLevel = 0;
    self.clickToFocusItem.toolTip = HoverClickLeftClickFocusHelp;
    HoverClickUseNonClosingMenuRow(self.clickToFocusItem, @"cursorarrow.click", @"target", YES);
    [menu addItem:self.clickToFocusItem];

    self.rightClickFocusItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Right Click Focus")
                                                          action:@selector(toggleRightClickFocus:)
                                                   keyEquivalent:@""];
    self.rightClickFocusItem.target = self;
    self.rightClickFocusItem.enabled = YES;
    self.rightClickFocusItem.indentationLevel = 0;
    self.rightClickFocusItem.toolTip = HoverClickRightClickFocusHelp;
    HoverClickUseNonClosingMenuRow(self.rightClickFocusItem, @"contextualmenu.and.cursorarrow", @"cursorarrow", YES);
    [menu addItem:self.rightClickFocusItem];

    self.bypassKeyItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Bypass Key")
                                                    action:nil
                                             keyEquivalent:@""];
    self.bypassKeyItem.enabled = YES;
    self.bypassKeyItem.indentationLevel = 0;
    self.bypassKeyItem.state = NSControlStateValueOff;
    self.bypassKeyItem.toolTip = HoverClickBypassKeyHelp;
    HoverClickUseSubmenuMenuRow(self.bypassKeyItem, @"keyboard", @"command");

    NSMenu *bypassMenu = [[NSMenu alloc] initWithTitle:@"Bypass Key"];
    [bypassMenu setAutoenablesItems:NO];
    self.bypassKeyItem.submenu = bypassMenu;
    [menu addItem:self.bypassKeyItem];

    CGFloat bypassWidth = HoverClickCalculatedSubmenuWidth(@[@"Off", @"Shift", @"Fn"]);

    NSMenuItem *bypassOffItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Off")
                                                           action:@selector(selectBypassKey:)
                                                    keyEquivalent:@""];
    bypassOffItem.target = self;
    bypassOffItem.enabled = YES;
    bypassOffItem.tag = HoverClickBypassKeyOff;
    HoverClickUseNonClosingSubmenuRow(bypassOffItem, @"xmark.circle", @"minus.circle", YES, bypassWidth);
    [bypassMenu addItem:bypassOffItem];
    [bypassMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *bypassShiftItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Shift")
                                                             action:@selector(selectBypassKey:)
                                                      keyEquivalent:@""];
    bypassShiftItem.target = self;
    bypassShiftItem.enabled = YES;
    bypassShiftItem.tag = HoverClickBypassKeyShift;
    HoverClickUseNonClosingSubmenuRow(bypassShiftItem, @"shift", @"arrow.up", YES, bypassWidth);
    [bypassMenu addItem:bypassShiftItem];

    NSMenuItem *bypassFnItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Fn")
                                                          action:@selector(selectBypassKey:)
                                                   keyEquivalent:@""];
    bypassFnItem.target = self;
    bypassFnItem.enabled = YES;
    bypassFnItem.tag = HoverClickBypassKeyFn;
    HoverClickUseNonClosingSubmenuRow(bypassFnItem, @"globe", @"keyboard", YES, bypassWidth);
    [bypassMenu addItem:bypassFnItem];

    self.excludedAppsItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Excluded Apps")
                                                       action:nil
                                                keyEquivalent:@""];
    self.excludedAppsItem.enabled = YES;
    self.excludedAppsItem.indentationLevel = 0;
    self.excludedAppsItem.state = NSControlStateValueOff;
    self.excludedAppsItem.toolTip = HoverClickExcludedAppsHelp;
    HoverClickUseSubmenuMenuRow(self.excludedAppsItem, @"hand.raised", @"nosign");
    self.excludedAppsItem.submenu = [[NSMenu alloc] initWithTitle:@"Excluded Apps"];
    [self.excludedAppsItem.submenu setAutoenablesItems:NO];
    [menu addItem:self.excludedAppsItem];
    [self buildExcludedAppsSubmenu];

    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:HoverClickCreateSectionHeaderMenuItem(@"Access")];

    NSMenuItem *permissionsItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Permissions")
                                                             action:nil
                                                      keyEquivalent:@""];
    permissionsItem.enabled = YES;
    permissionsItem.indentationLevel = 0;
    permissionsItem.state = NSControlStateValueOff;
    HoverClickUseSubmenuMenuRow(permissionsItem, @"lock.shield", @"lock");

    NSMenu *permissionsMenu = [[NSMenu alloc] initWithTitle:@"Permissions"];
    [permissionsMenu setAutoenablesItems:NO];
    permissionsItem.submenu = permissionsMenu;
    [menu addItem:permissionsItem];

    CGFloat permissionsWidth = HoverClickCalculatedSubmenuWidth(@[
        @"Accessibility: Required",
        @"Accessibility: Granted",
        @"Launch at Login",
        @"Launch at Login: Unavailable",
        @"Refresh Status",
        @"Accessibility Settings"
    ]);

    self.permissionItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Accessibility: Required")
                                                     action:@selector(refreshAccessibilityStatus:)
                                              keyEquivalent:@""];
    self.permissionItem.target = self;
    self.permissionItem.enabled = YES;
    self.permissionItem.indentationLevel = 0;
    self.permissionItem.state = NSControlStateValueOff;
    self.permissionItem.toolTip = HoverClickAccessibilityStatusHelp;
    HoverClickUseNonClosingSubmenuRow(self.permissionItem, @"accessibility", @"person.crop.circle.badge.checkmark", YES, permissionsWidth);
    [permissionsMenu addItem:self.permissionItem];

    self.launchAtLoginItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Launch at Login")
                                                        action:@selector(toggleLaunchAtLogin:)
                                                 keyEquivalent:@""];
    self.launchAtLoginItem.target = self;
    self.launchAtLoginItem.enabled = YES;
    self.launchAtLoginItem.indentationLevel = 0;
    self.launchAtLoginItem.toolTip = HoverClickLaunchAtLoginHelp;
    HoverClickUseNonClosingSubmenuRow(self.launchAtLoginItem, @"power", @"arrow.clockwise.circle", YES, permissionsWidth);
    [permissionsMenu addItem:self.launchAtLoginItem];

    [permissionsMenu addItem:[NSMenuItem separatorItem]];

    self.permissionRefreshItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Refresh Status")
                                                            action:@selector(refreshAccessibilityStatus:)
                                                     keyEquivalent:@""];
    self.permissionRefreshItem.target = self;
    self.permissionRefreshItem.enabled = YES;
    self.permissionRefreshItem.indentationLevel = 0;
    self.permissionRefreshItem.state = NSControlStateValueOff;
    self.permissionRefreshItem.toolTip = HoverClickRefreshAccessibilityHelp;
    HoverClickUseNonClosingSubmenuRow(self.permissionRefreshItem, @"arrow.clockwise", @"arrow.clockwise.circle", NO, permissionsWidth);
    [permissionsMenu addItem:self.permissionRefreshItem];

    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Accessibility Settings")
                                                          action:@selector(openAccessibilitySettings:)
                                                   keyEquivalent:@""];
    settingsItem.target = self;
    settingsItem.enabled = YES;
    settingsItem.indentationLevel = 0;
    settingsItem.state = NSControlStateValueOff;
    settingsItem.toolTip = HoverClickOpenAccessibilitySettingsHelp;
    HoverClickUseClosingSubmenuRow(settingsItem, @"gearshape", @"accessibility", permissionsWidth);
    [permissionsMenu addItem:settingsItem];

    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:HoverClickCreateUpdatesSectionHeaderMenuItem()];

    self.checkForUpdatesItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Check Now...")
                                                          action:@selector(checkForUpdates:)
                                                   keyEquivalent:@""];
    self.checkForUpdatesItem.target = self.updaterController;
    self.checkForUpdatesItem.enabled = YES;
    self.checkForUpdatesItem.indentationLevel = 0;
    self.checkForUpdatesItem.state = NSControlStateValueOff;
    self.checkForUpdatesItem.toolTip = HoverClickCheckForUpdatesHelp;
    HoverClickUseClosingMenuRow(self.checkForUpdatesItem, @"arrow.down.circle", @"arrow.clockwise.circle");
    [menu addItem:self.checkForUpdatesItem];

    self.automaticUpdateChecksItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Auto Check Updates")
                                                                action:@selector(toggleAutomaticUpdateChecks:)
                                                         keyEquivalent:@""];
    self.automaticUpdateChecksItem.target = self;
    self.automaticUpdateChecksItem.enabled = YES;
    self.automaticUpdateChecksItem.indentationLevel = 0;
    self.automaticUpdateChecksItem.toolTip = HoverClickAutomaticUpdateChecksHelp;
    HoverClickUseNonClosingMenuRow(self.automaticUpdateChecksItem, @"clock.arrow.circlepath", @"checkmark.circle", YES);
    [menu addItem:self.automaticUpdateChecksItem];

    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:HoverClickCreateInfoSectionHeaderMenuItem()];

    // Guide: visible, reliable feature explanations to replace native in-menu hover tooltips,
    // which do not display on HoverClick's custom NSView menu rows. Standard submenu navigation
    // (not the broken hover-tooltip path) reveals the explanations. Lives one level in so the main
    // menu stays compact; entries are disabled informational rows.
    NSMenuItem *quickHelpItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Guide")
                                                           action:nil
                                                    keyEquivalent:@""];
    quickHelpItem.enabled = YES;
    quickHelpItem.indentationLevel = 0;
    quickHelpItem.state = NSControlStateValueOff;
    HoverClickUseSubmenuMenuRow(quickHelpItem, @"questionmark.bubble", @"questionmark.circle");

    NSMenu *quickHelpMenu = [[NSMenu alloc] initWithTitle:@"Guide"];
    [quickHelpMenu setAutoenablesItems:NO];
    quickHelpItem.submenu = quickHelpMenu;
    [menu addItem:quickHelpItem];

    [quickHelpMenu addItem:HoverClickCreateQuickHelpItem(@"Left Click Focus",
        @"Focuses windows on left-click.")];
    [quickHelpMenu addItem:HoverClickCreateQuickHelpItem(@"Right Click Focus",
        @"Focuses before showing context menus.")];
    [quickHelpMenu addItem:HoverClickCreateQuickHelpItem(@"Bypass Key",
        @"Hold the key to bypass HoverClick.")];
    [quickHelpMenu addItem:HoverClickCreateQuickHelpItem(@"Excluded Apps",
        @"Apps HoverClick ignores.")];
    [quickHelpMenu addItem:HoverClickCreateQuickHelpItem(@"Launch at Login",
        @"Starts HoverClick when you sign in.")];
    [quickHelpMenu addItem:HoverClickCreateQuickHelpItem(@"Permissions",
        @"Recheck Accessibility access.")];
    [quickHelpMenu addItem:HoverClickCreateQuickHelpItem(@"Verbose Mode",
        @"Adds details to diagnostics.")];
    [quickHelpMenu addItem:HoverClickCreateQuickHelpItem(@"Copy Summary",
        @"Copies settings and recent decisions.")];

    NSMenuItem *helpItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Help")
                                                      action:nil
                                               keyEquivalent:@""];
    helpItem.enabled = YES;
    helpItem.indentationLevel = 0;
    helpItem.state = NSControlStateValueOff;
    HoverClickUseSubmenuMenuRow(helpItem, @"questionmark.circle", @"questionmark");

    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    [helpMenu setAutoenablesItems:NO];
    helpItem.submenu = helpMenu;
    [menu addItem:helpItem];

    CGFloat helpWidth = HoverClickCalculatedSubmenuWidth(@[
        @"GitHub",
        @"Contact",
        @"Release Notes",
        @"Uninstall..."
    ]);

    NSMenuItem *githubItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"GitHub")
                                                        action:@selector(openGitHub:)
                                                 keyEquivalent:@""];
    githubItem.target = self;
    githubItem.enabled = YES;
    githubItem.indentationLevel = 0;
    githubItem.state = NSControlStateValueOff;
    githubItem.toolTip = HoverClickGitHubHelp;
    HoverClickUseClosingSubmenuRow(githubItem, @"link", @"globe", helpWidth);
    [helpMenu addItem:githubItem];

    NSMenuItem *contactItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Contact")
                                                         action:@selector(openContact:)
                                                  keyEquivalent:@""];
    contactItem.target = self;
    contactItem.enabled = YES;
    contactItem.indentationLevel = 0;
    contactItem.state = NSControlStateValueOff;
    contactItem.toolTip = HoverClickContactHelp;
    HoverClickUseClosingSubmenuRow(contactItem, @"envelope", @"at", helpWidth);
    [helpMenu addItem:contactItem];

    NSMenuItem *releaseNotesItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Release Notes")
                                                              action:@selector(openReleaseNotes:)
                                                       keyEquivalent:@""];
    releaseNotesItem.target = self;
    releaseNotesItem.enabled = YES;
    releaseNotesItem.indentationLevel = 0;
    releaseNotesItem.state = NSControlStateValueOff;
    releaseNotesItem.toolTip = HoverClickReleaseNotesHelp;
    HoverClickUseClosingSubmenuRow(releaseNotesItem, @"doc.text", @"doc", helpWidth);
    [helpMenu addItem:releaseNotesItem];

    [helpMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *uninstallItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Uninstall...")
                                                           action:@selector(showUninstallInstructions:)
                                                    keyEquivalent:@""];
    uninstallItem.target = self;
    uninstallItem.enabled = YES;
    uninstallItem.indentationLevel = 0;
    uninstallItem.state = NSControlStateValueOff;
    uninstallItem.toolTip = HoverClickUninstallHelp;
    HoverClickUseClosingSubmenuRow(uninstallItem, @"trash", @"xmark.circle", helpWidth);
    [helpMenu addItem:uninstallItem];

    self.diagnosticsItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Diagnostics")
                                                      action:nil
                                               keyEquivalent:@""];
    self.diagnosticsItem.enabled = YES;
    self.diagnosticsItem.indentationLevel = 0;
    self.diagnosticsItem.state = NSControlStateValueOff;
    HoverClickUseSubmenuMenuRow(self.diagnosticsItem, @"waveform.path.ecg", @"doc.text");

    NSMenu *diagnosticsMenu = [[NSMenu alloc] initWithTitle:@"Diagnostics"];
    [diagnosticsMenu setAutoenablesItems:NO];
    self.diagnosticsItem.submenu = diagnosticsMenu;
    [menu addItem:self.diagnosticsItem];

    CGFloat diagnosticsWidth = HoverClickCalculatedSubmenuWidth(@[
        @"Copy Summary",
        @"Verbose Mode"
    ]);

    self.diagnosticsCopyItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Copy Summary")
                                                         action:@selector(copyDiagnosticsSummary:)
                                                  keyEquivalent:@""];
    self.diagnosticsCopyItem.target = self;
    self.diagnosticsCopyItem.enabled = YES;
    self.diagnosticsCopyItem.indentationLevel = 0;
    self.diagnosticsCopyItem.state = NSControlStateValueOff;
    self.diagnosticsCopyItem.toolTip = HoverClickCopyDiagnosticsSummaryHelp;
    HoverClickUseNonClosingSubmenuRow(self.diagnosticsCopyItem, @"doc.on.doc", @"doc.text", NO, diagnosticsWidth);
    [diagnosticsMenu addItem:self.diagnosticsCopyItem];

    self.verboseItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Verbose Mode")
                                                  action:@selector(toggleVerboseDiagnostics:)
                                           keyEquivalent:@""];
    self.verboseItem.target = self;
    self.verboseItem.enabled = YES;
    self.verboseItem.indentationLevel = 0;
    self.verboseItem.toolTip = HoverClickVerboseDiagnosticsHelp;
    HoverClickUseNonClosingSubmenuRow(self.verboseItem, @"list.bullet.rectangle", @"list.bullet", YES, diagnosticsWidth);
    [diagnosticsMenu addItem:self.verboseItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"About...")
                                                       action:@selector(showAboutHoverClick:)
                                                keyEquivalent:@""];
    aboutItem.target = self;
    aboutItem.enabled = YES;
    aboutItem.indentationLevel = 0;
    aboutItem.state = NSControlStateValueOff;
    aboutItem.toolTip = HoverClickAboutHelp;
    HoverClickUseClosingPlainMenuRow(aboutItem, nil);
    [menu addItem:aboutItem];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Quit HoverClick")
                                                      action:@selector(quitApplication:)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    quitItem.enabled = YES;
    quitItem.indentationLevel = 0;
    quitItem.state = NSControlStateValueOff;
    quitItem.toolTip = HoverClickQuitHelp;
    HoverClickUseClosingPlainMenuRow(quitItem, @"\u2318Q");
    if ([quitItem.view isKindOfClass:[HoverClickMenuRowView class]]) {
        ((HoverClickMenuRowView *)quitItem.view).useSubtleAccessory = YES;
    }
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
    [self updateMenuTitles];
}

// Clears the highlight flag on every custom menu row view in the menu tree. Custom rows track
// their own hover highlight via mouseEntered:/mouseExited:. When a closing row dismisses the
// menu with cancelTracking (for example Excluded Apps > Add App Exclusion...), a parent row that was
// highlighted to open its submenu never receives mouseExited:, leaving it stuck highlighted on
// the next open. Resetting on menuWillOpen: guarantees a clean state every time the menu shows.
- (void)resetMenuRowHighlightsInMenu:(NSMenu *)menu {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.view isKindOfClass:[HoverClickMenuRowView class]]) {
            ((HoverClickMenuRowView *)item.view).highlighted = NO;
        }
        if (item.submenu != nil) {
            [self resetMenuRowHighlightsInMenu:item.submenu];
        }
    }
}

- (void)menuWillOpen:(NSMenu *)menu {
    if (menu != self.statusItem.menu) {
        return;
    }

    [self resetMenuRowHighlightsInMenu:menu];

    [self refreshAccessibilityStatusForReason:@"menu open"
                              promptIfMissing:NO
                             updateLastAction:NO];
}

- (void)printLaunchStatus {
    BOOL trusted = [self accessibilityTrusted];
    HoverClickLog("HoverClick: bundle id = %s", HoverClickBundleID.UTF8String);
    HoverClickLog("HoverClick: version = %s", HoverClickDisplayVersion().UTF8String);
    HoverClickLog("HoverClick: Accessibility permission granted = %s", trusted ? "YES" : "NO");
    HoverClickLog("HoverClick: launch settings leftClickFocus=%s rightClickFocus=%s skipKey=%s automaticUpdateChecks=%s automaticDownloadInstall=%s",
                  _clickToFocusEnabled ? "ON" : "OFF",
                  _rightClickFocusEnabled ? "ON" : "OFF",
                  _bypassKey == HoverClickBypassKeyShift ? "shift" : _bypassKey == HoverClickBypassKeyFn ? "fn" : "off",
                  self.updaterController.updater.automaticallyChecksForUpdates ? "ON" : "OFF",
                  self.updaterController.updater.automaticallyDownloadsUpdates ? "ON" : "OFF");
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

    self.launchAtLoginItem.title = HoverClickMenuItemTitle(@"Launch at Login");
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
        HoverClickSyncMenuRowView(self.launchAtLoginItem);
        return;
    }
#endif

    self.launchAtLoginItem.enabled = NO;
    self.launchAtLoginItem.title = HoverClickMenuItemTitle(@"Launch at Login: Unavailable");
    self.launchAtLoginItem.state = NSControlStateValueOff;
    self.launchAtLoginItem.toolTip = @"Launch at Login requires macOS 13 or later.";
    HoverClickSyncMenuRowView(self.launchAtLoginItem);
    [self logLaunchAtLoginStatus:@"unavailable on this macOS version" force:NO];
}

- (BOOL)accessibilityTrusted {
    return AXIsProcessTrusted();
}

- (void)recordPermissionCheckResult:(NSString *)result {
    _lastPermissionCheckResult = [result.length > 0 ? result : @"unknown" copy];
    _lastPermissionCheckTime = CFAbsoluteTimeGetCurrent();
}

- (void)removeEventTapDueToMissingAccessibilityWithReason:(NSString *)reason {
    NSString *safeReason = reason.length > 0 ? reason : @"permission check";
    BOOL hadTap = (_eventTap != NULL || _eventTapSource != NULL || _eventTapInstalled || _eventTapEnabled);

    _permissionMissingPassThroughActive = YES;
    if (hadTap) {
        _eventTapRemovedDueToMissingPermission = YES;
    }
    _eventTapRemovalScheduledDueToMissingPermission = NO;
    [self recordPermissionCheckResult:[NSString stringWithFormat:@"missing (%@)", safeReason]];

    HoverClickLog("HoverClick: Accessibility missing during %s; normal clicks pass through unchanged", safeReason.UTF8String);
    if (hadTap) {
        [self removeEventTap];
    } else {
        _eventTapEnabled = NO;
        [self updateMenuTitles];
    }

    if (_userWantsEventTap) {
        [self setLastClickResult:@"Permission Missing"];
    }
}

- (void)dismissAccessibilityOnboardingAlertIfNeeded {
    if (self.accessibilityOnboardingAlert == nil) {
        return;
    }

    NSWindow *alertWindow = self.accessibilityOnboardingAlert.window;
    if (alertWindow.visible) {
        [alertWindow close];
        HoverClickLog("HoverClick: Accessibility onboarding dismissed after permission refresh");
    }
    self.accessibilityOnboardingAlert = nil;
}

- (void)dismissAccessibilityOnboardingAlert:(id)sender {
    (void)sender;
    [self dismissAccessibilityOnboardingAlertIfNeeded];
}

- (void)windowWillClose:(NSNotification *)notification {
    if (self.accessibilityOnboardingAlert != nil &&
        notification.object == self.accessibilityOnboardingAlert.window) {
        self.accessibilityOnboardingAlert = nil;
    }
}

- (BOOL)refreshAccessibilityStatusForReason:(NSString *)reason promptIfMissing:(BOOL)promptIfMissing updateLastAction:(BOOL)updateLastAction {
    NSString *safeReason = reason.length > 0 ? reason : @"refresh";
    BOOL trusted = [self accessibilityTrusted];

    if (!trusted && promptIfMissing) {
        [self requestAccessibilityTrustPrompt];
        trusted = [self accessibilityTrusted];
    }

    HoverClickLog("HoverClick: Accessibility permission granted = %s reason=%s", trusted ? "YES" : "NO", safeReason.UTF8String);

    if (trusted) {
        _permissionMissingPassThroughActive = NO;
        _eventTapRemovedDueToMissingPermission = NO;
        _eventTapRemovalScheduledDueToMissingPermission = NO;
        [self recordPermissionCheckResult:[NSString stringWithFormat:@"granted (%@)", safeReason]];
        [self dismissAccessibilityOnboardingAlertIfNeeded];

        if (updateLastAction) {
            [self setLastClickResult:@"Permission Granted"];
        }

        if (_userWantsEventTap) {
            [self installEventTap];
        } else {
            [self updateMenuTitles];
        }
        return YES;
    }

    [self removeEventTapDueToMissingAccessibilityWithReason:safeReason];
    return NO;
}

- (BOOL)requestAccessibilityTrustPrompt {
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    BOOL trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    _accessibilityTrustPromptRequestedThisLaunch = YES;
    HoverClickLog("HoverClick: Accessibility permission prompt shown result=%s", trusted ? "granted" : "not granted");
    return trusted;
}

- (void)showAccessibilityOnboardingIfNeeded {
    if ([self accessibilityTrusted]) {
        [self dismissAccessibilityOnboardingAlertIfNeeded];
        return;
    }

    _accessibilityOnboardingShownThisLaunch = YES;
    [self requestAccessibilityTrustPrompt];

    if ([self accessibilityTrusted]) {
        [self refreshAccessibilityStatusForReason:@"onboarding prompt"
                                  promptIfMissing:NO
                                 updateLastAction:YES];
        return;
    }

    [self setLastClickResult:@"Permission Missing"];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"HoverClick Needs Accessibility Permission";
    alert.informativeText = @"HoverClick needs Accessibility permission to focus background windows before your original click is delivered. Click focus controls stay disabled until permission is granted.\n\nUse Permissions > Accessibility Settings if macOS does not show the permission prompt, then choose Refresh Status after enabling HoverClick.";
    alert.alertStyle = NSAlertStyleInformational;
    NSButton *okButton = [alert addButtonWithTitle:@"OK"];
    okButton.target = self;
    okButton.action = @selector(dismissAccessibilityOnboardingAlert:);
    self.accessibilityOnboardingAlert = alert;
    // The alert window is shown directly, not through runModal, so lay it out first:
    // without this the nib placeholders (the "<Do not show this message again>" checkbox
    // and the hidden extra buttons) stay visible and the texts are cut short.
    [alert layout];
    alert.window.delegate = self;
    [alert.window setReleasedWhenClosed:NO];
    [alert.window makeKeyAndOrderFront:nil];
    HoverClickLog("HoverClick: Accessibility onboarding shown while permission is missing");
    [self updateMenuTitles];
}

// Shows a feedback title on a menu row for 2 seconds, then runs completion and restores the
// row. Each call bumps *generation, so the timer of an earlier click leaves a newer feedback
// alone. generation points at an ivar of self, which the block keeps alive.
- (void)showTransientTitle:(NSString *)feedbackTitle
                    onItem:(NSMenuItem *)item
              restoreTitle:(NSString *)restoreTitle
                generation:(NSUInteger *)generation
                completion:(void (^)(void))completion {
    NSUInteger currentGeneration = ++(*generation);
    item.title = HoverClickMenuItemTitle(feedbackTitle);
    HoverClickSyncMenuRowView(item);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        (void)self;
        if (*generation != currentGeneration) {
            return;
        }
        if (completion != nil) {
            completion();
        }
        item.title = HoverClickMenuItemTitle(restoreTitle);
        HoverClickSyncMenuRowView(item);
    });
}

- (void)refreshAccessibilityStatus:(id)sender {
    BOOL userInitiated = (sender != nil);
    [self refreshAccessibilityStatusForReason:userInitiated ? @"manual refresh" : @"refresh"
                              promptIfMissing:userInitiated
                             updateLastAction:userInitiated];
    if (userInitiated) {
        _showRefreshStatusFeedback = YES;
        [self showTransientTitle:@"Refreshed"
                          onItem:self.permissionRefreshItem
                    restoreTitle:@"Refresh Status"
                      generation:&_refreshFeedbackGeneration
                      completion:^{
            _showRefreshStatusFeedback = NO;
        }];
    }
}

- (BOOL)isEventTapPortValid {
    return _eventTap != NULL && CFMachPortIsValid(_eventTap);
}

- (BOOL)isEventTapSourceValid {
    return _eventTapSource != NULL && CFRunLoopSourceIsValid(_eventTapSource);
}

- (void)updateEventTapLifecycleFlags {
    BOOL hasValidPort = [self isEventTapPortValid];
    BOOL hasValidSource = [self isEventTapSourceValid];
    _eventTapInstalled = (_eventTap != NULL && _eventTapSource != NULL && hasValidPort && hasValidSource);
    _eventTapEnabled = (_eventTapInstalled && CGEventTapIsEnabled(_eventTap));
}

- (NSString *)eventTapPortValidityDescription {
    if (_eventTap == NULL) {
        return @"not present";
    }

    return CFMachPortIsValid(_eventTap) ? @"valid" : @"invalid";
}

- (NSString *)eventTapSourceValidityDescription {
    if (_eventTapSource == NULL) {
        return @"not present";
    }

    return CFRunLoopSourceIsValid(_eventTapSource) ? @"valid" : @"invalid";
}

- (NSString *)eventTapDetectedEnabledDescription {
    if (_eventTap == NULL) {
        return @"not detectable (no tap)";
    }

    if (!CFMachPortIsValid(_eventTap)) {
        return @"not detectable (invalid tap)";
    }

    return CGEventTapIsEnabled(_eventTap) ? @"yes" : @"no";
}

- (void)recordEventTapCallbackWithType:(CGEventType)type event:(CGEventRef)event proxy:(CGEventTapProxy)proxy {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    _lastEventTapCallbackTime = HoverClickMonotonicSeconds();
    NSString *returnPolicy = event == NULL ?
        @"returnPolicy=NULL only because event input is NULL" :
        @"returnPolicy=original event unchanged for normal left/right mouse-down";
    _lastEventTapCallbackDescription = [NSString stringWithFormat:@"%@ at %@ (%@, %@, %@)",
                                        HoverClickEventTypeName(type),
                                        HoverClickDiagnosticTimestamp(now),
                                        event == NULL ? @"event=NULL" : @"event=present",
                                        proxy == NULL ? @"proxy=NULL" : @"proxy=present",
                                        returnPolicy];

    if (type == kCGEventLeftMouseDown) {
        _totalMouseCallbacksSeen++;
        _totalLeftMouseCallbacksSeen++;
        _lastLeftMouseDownSeenTime = now;
    } else if (type == kCGEventRightMouseDown) {
        _totalMouseCallbacksSeen++;
        _totalRightMouseCallbacksSeen++;
        _lastRightMouseDownSeenTime = now;
    } else if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        _eventTapEnabled = NO;
    }
}

- (void)handleEventTapCallbackWithMissingAccessibilityForType:(CGEventType)type {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    NSString *typeName = HoverClickEventTypeName(type);
    NSString *triggerLabel = type == kCGEventRightMouseDown ? @"right" : @"left";

    _permissionMissingPassThroughActive = YES;
    _eventTapPermissionMissingPassThroughCount++;
    _lastClickResult = @"Permission Missing Pass Through";
    _lastFocusDecisionDescription = [NSString stringWithFormat:@"%@ pass-through: Accessibility permission missing; original event returned unchanged",
                                                               triggerLabel];
    if (type == kCGEventRightMouseDown) {
        _lastRightClickFocusDecisionDescription = _lastFocusDecisionDescription;
    }
    _lastClickThroughInvestigationDescription = [NSString stringWithFormat:@"%@ pass-through: Accessibility permission missing; no AX target/focus attempt; original event returned unchanged; swallowed=no",
                                                                           triggerLabel];
    _lastPermissionMissingPassThroughDescription = [NSString stringWithFormat:@"%@ at %@ count=%llu",
                                                    typeName,
                                                    HoverClickDiagnosticTimestamp(now),
                                                    _eventTapPermissionMissingPassThroughCount];
    [self recordPermissionCheckResult:@"missing (click listener callback)"];

    if (_eventTapRemovalScheduledDueToMissingPermission) {
        return;
    }

    _eventTapRemovalScheduledDueToMissingPermission = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self accessibilityTrusted]) {
            _permissionMissingPassThroughActive = NO;
            _eventTapRemovalScheduledDueToMissingPermission = NO;
            [self recordPermissionCheckResult:@"granted (post-callback check)"];
            if (_userWantsEventTap) {
                [self installEventTap];
            } else {
                [self updateMenuTitles];
            }
            return;
        }

        [self removeEventTapDueToMissingAccessibilityWithReason:@"click listener callback"];
    });
}

- (void)recordFocusDecisionWithTrigger:(const char *)trigger sequenceID:(uint64_t)sequenceID decision:(NSString *)decision detail:(NSString *)detail {
    NSString *triggerLabel = HoverClickFocusTriggerLabel(trigger);
    NSString *summary = [NSString stringWithFormat:@"%@ #%llu %@%@%@",
                         triggerLabel,
                         sequenceID,
                         decision ?: @"unknown",
                         detail.length > 0 ? @": " : @"",
                         detail.length > 0 ? detail : @""];
    _lastFocusDecisionDescription = summary;
    if ([triggerLabel isEqualToString:@"right"]) {
        _lastRightClickFocusDecisionDescription = summary;
    }
    if ([decision isEqualToString:@"skipped"]) {
        _totalPolicySkips++;
        [self updateRecentDecisionForSequenceID:sequenceID key:@"policyDecision" value:@"skip"];
        [self updateRecentDecisionForSequenceID:sequenceID key:@"skipReason" value:detail ?: @"unknown"];
    } else if ([decision isEqualToString:@"eligible"] || [decision isEqualToString:@"focus attempt"]) {
        [self updateRecentDecisionForSequenceID:sequenceID key:@"policyDecision" value:@"attempt"];
    } else if (decision.length > 0) {
        [self updateRecentDecisionForSequenceID:sequenceID key:@"policyDecision" value:decision];
    }
}

- (void)recordBackgroundFocusAttemptWithTrigger:(const char *)trigger sequenceID:(uint64_t)sequenceID appName:(NSString *)appName pid:(pid_t)targetPid frontmostBefore:(NSString *)frontmostBefore {
    _lastBackgroundFocusAttemptTime = CFAbsoluteTimeGetCurrent();
    _lastBackgroundFocusSequence = sequenceID;
    _lastBackgroundFocusTrigger = HoverClickFocusTriggerLabel(trigger);
    _lastBackgroundFocusTargetApp = [NSString stringWithFormat:@"%@ pid=%d",
                                     appName ?: @"unknown",
                                     targetPid];
    _lastBackgroundFocusFrontmostBefore = frontmostBefore ?: @"unknown";
    _lastBackgroundFocusActivation = @"not attempted";
    _lastBackgroundFocusAXOperations = @"not attempted";
    _lastBackgroundFocusImmediateFrontmost = @"not checked";
    _lastBackgroundFocusDelayedVerification = @"not scheduled";
    _lastBackgroundFocusResult = @"attempting";
    _lastBackgroundFocusVerification = @"pending";
    _lastBackgroundFocusFailureReason = @"none";
}

- (void)recordBackgroundFocusResult:(NSString *)result verification:(NSString *)verification failureReason:(NSString *)failureReason {
    _lastBackgroundFocusResult = result ?: @"unknown";
    _lastBackgroundFocusVerification = verification ?: @"unknown";
    _lastBackgroundFocusFailureReason = failureReason ?: @"none";
    [self updateRecentDecisionForSequenceID:_lastBackgroundFocusSequence
                                        key:@"finalResult"
                                      value:[NSString stringWithFormat:@"%@ verification=%@ failure=%@",
                                             _lastBackgroundFocusResult,
                                             _lastBackgroundFocusVerification,
                                             _lastBackgroundFocusFailureReason]];
}

- (NSMutableDictionary<NSString *, NSString *> *)recentDecisionEntryForSequenceID:(uint64_t)sequenceID {
    NSNumber *key = @(sequenceID);
    NSMutableDictionary<NSString *, NSString *> *entry = _activeDecisionHistory[key];
    if (entry != nil) {
        return entry;
    }

    for (NSMutableDictionary<NSString *, NSString *> *candidate in _recentDecisionHistory) {
        if ((uint64_t)[candidate[@"sequence"] longLongValue] == sequenceID) {
            return candidate;
        }
    }

    return nil;
}

- (void)refreshLastRealBackgroundClickDecisionFromEntry:(NSDictionary<NSString *, NSString *> *)entry {
    if (![entry[@"includedInHistory"] isEqualToString:@"yes"]) {
        return;
    }

    NSString *summary = [NSString stringWithFormat:@"%@ #%@ at %@ trigger=%@ click=%@ sourceAppBefore=%@ frontmostBefore=%@ targetBundle=%@ targetIsChrome=%@ AX=%@ eligible=%@ policy=%@ skip=%@ passThrough=%@ browser=%@ final=%@",
                         entry[@"trigger"] ?: @"unknown",
                         entry[@"sequence"] ?: @"0",
                         entry[@"timestamp"] ?: @"unknown",
                         entry[@"trigger"] ?: @"unknown",
                         entry[@"clickLocation"] ?: @"unknown",
                         entry[@"sourceAppBefore"] ?: @"unknown",
                         entry[@"frontmostBefore"] ?: @"unknown",
                         entry[@"targetBundleID"] ?: @"unknown",
                         entry[@"targetIsChrome"] ?: @"unknown",
                         entry[@"axTarget"] ?: @"unknown",
                         entry[@"eligibleCandidate"] ?: @"unknown",
                         entry[@"policyDecision"] ?: @"unknown",
                         entry[@"skipReason"] ?: @"none",
                         entry[@"eventPassThrough"] ?: @"unknown",
                         entry[@"browserContentNote"] ?: @"not evaluated",
                         entry[@"finalResult"] ?: @"unknown"];
    _lastRealBackgroundClickDecisionDescription = summary;
    _lastRealBackgroundClickOverlayDescription = entry[@"topmostCGWindow"] ?: @"none";
    _lastRealBackgroundClickHitTestCandidateDescription = entry[@"eligibleCandidateDetail"] ?: @"none";
}

- (void)updateRecentDecisionForSequenceID:(uint64_t)sequenceID key:(NSString *)key value:(NSString *)value {
    if (key.length == 0) {
        return;
    }

    NSMutableDictionary<NSString *, NSString *> *entry = [self recentDecisionEntryForSequenceID:sequenceID];
    if (entry == nil) {
        return;
    }

    entry[key] = value ?: @"unknown";
    [self refreshLastRealBackgroundClickDecisionFromEntry:entry];
}

- (void)beginRecentDecisionWithTrigger:(const char *)trigger sequenceID:(uint64_t)sequenceID rawPoint:(CGPoint)rawPoint axPoint:(CGPoint)axPoint {
    NSString *triggerLabel = HoverClickFocusTriggerLabel(trigger);
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    NSRunningApplication *frontApp = [NSWorkspace sharedWorkspace].frontmostApplication;
    NSString *frontAppDescription = HoverClickRunningApplicationDescription(frontApp);
    NSMutableDictionary<NSString *, NSString *> *entry = [@{
        @"sequence": [NSString stringWithFormat:@"%llu", sequenceID],
        @"timestamp": HoverClickDiagnosticTimestamp(now),
        @"trigger": triggerLabel ?: @"unknown",
        @"clickLocation": [NSString stringWithFormat:@"raw=(%@) ax=(%@)",
                           HoverClickPointDescription(rawPoint),
                           HoverClickPointDescription(axPoint)],
        @"sourceAppBefore": frontAppDescription,
        @"frontmostBefore": frontAppDescription,
        @"topmostCGWindow": @"not captured",
        @"axTarget": @"not resolved",
        @"targetBundleID": @"not resolved",
        @"targetIsChrome": @"not resolved",
        @"targetWindowTitle": @"not resolved",
        @"targetAlreadyFrontmost": @"not checked",
        @"eligibleCandidate": @"no",
        @"eligibleCandidateDetail": @"none",
        @"policyDecision": @"pending",
        @"skipReason": @"none",
        @"overlayOrSystemUIInvolved": @"no",
        @"compactPopupInvolved": @"no",
        @"focusAttemptStarted": @"no",
        @"axOperations": @"not attempted",
        @"immediateVerification": @"not checked",
        @"delayedVerification": @"not scheduled",
        @"eventPassThrough": @"original event expected to be returned unchanged; swallowed=no",
        @"browserContentBaseNote": @"not evaluated",
        @"browserContentNote": @"not evaluated",
        @"finalResult": @"pending",
        @"includedInHistory": @"no"
    } mutableCopy];
    _activeDecisionHistory[@(sequenceID)] = entry;
    _lastClickThroughInvestigationDescription = [NSString stringWithFormat:@"%@ #%llu event tap saw mouseDown; sourceAppBefore=%@; target detection pending; original event expected to be returned unchanged",
                                                                           triggerLabel ?: @"unknown",
                                                                           sequenceID,
                                                                           frontAppDescription];
}

- (void)includeRecentDecisionInHistoryForSequenceID:(uint64_t)sequenceID {
    NSMutableDictionary<NSString *, NSString *> *entry = [self recentDecisionEntryForSequenceID:sequenceID];
    if (entry == nil || [entry[@"includedInHistory"] isEqualToString:@"yes"]) {
        return;
    }

    entry[@"includedInHistory"] = @"yes";
    [_recentDecisionHistory addObject:entry];
    _totalNonMenuMouseCallbacks++;

    while (_recentDecisionHistory.count > HoverClickRecentDecisionHistoryLimit) {
        [_recentDecisionHistory removeObjectAtIndex:0];
    }

    [self refreshLastRealBackgroundClickDecisionFromEntry:entry];
}

- (void)completeRecentDecisionForSequenceID:(uint64_t)sequenceID finalResult:(NSString *)finalResult keepActiveForDelayedVerification:(BOOL)keepActive {
    [self updateRecentDecisionForSequenceID:sequenceID key:@"finalResult" value:finalResult ?: @"unknown"];
    if (!keepActive) {
        [_activeDecisionHistory removeObjectForKey:@(sequenceID)];
    }
}

- (void)recordMenuStatusDecisionForSequenceID:(uint64_t)sequenceID finalResult:(NSString *)finalResult {
    _totalMenuStatusUISkips++;
    [self completeRecentDecisionForSequenceID:sequenceID
                                  finalResult:finalResult ?: @"menu/status UI skipped"
             keepActiveForDelayedVerification:NO];
}

- (NSString *)recentDecisionHistoryDescription {
    if (_recentDecisionHistory.count == 0) {
        return @"none";
    }

    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithCapacity:_recentDecisionHistory.count];
    for (NSMutableDictionary<NSString *, NSString *> *entry in [_recentDecisionHistory reverseObjectEnumerator]) {
        NSString *line = [NSString stringWithFormat:@"%@ #%@ at %@ click=%@ sourceAppBefore=%@ frontmostBefore=%@ topmost=[%@] AX=[%@] targetBundle=%@ targetIsChrome=%@ targetWindowTitle=%@ alreadyFrontmost=%@ eligible=%@ policy=%@ skip=%@ overlay/systemUI=%@ compactPopup=%@ focusAttempt=%@ AXOps=[%@] immediate=[%@] delayed=[%@] passThrough=[%@] browser=[%@] final=%@",
                          entry[@"trigger"] ?: @"unknown",
                          entry[@"sequence"] ?: @"0",
                          entry[@"timestamp"] ?: @"unknown",
                          entry[@"clickLocation"] ?: @"unknown",
                          entry[@"sourceAppBefore"] ?: @"unknown",
                          entry[@"frontmostBefore"] ?: @"unknown",
                          entry[@"topmostCGWindow"] ?: @"unknown",
                          entry[@"axTarget"] ?: @"unknown",
                          entry[@"targetBundleID"] ?: @"unknown",
                          entry[@"targetIsChrome"] ?: @"unknown",
                          entry[@"targetWindowTitle"] ?: @"unknown",
                          entry[@"targetAlreadyFrontmost"] ?: @"unknown",
                          entry[@"eligibleCandidate"] ?: @"unknown",
                          entry[@"policyDecision"] ?: @"unknown",
                          entry[@"skipReason"] ?: @"none",
                          entry[@"overlayOrSystemUIInvolved"] ?: @"unknown",
                          entry[@"compactPopupInvolved"] ?: @"unknown",
                          entry[@"focusAttemptStarted"] ?: @"unknown",
                          entry[@"axOperations"] ?: @"unknown",
                          entry[@"immediateVerification"] ?: @"unknown",
                          entry[@"delayedVerification"] ?: @"unknown",
                          entry[@"eventPassThrough"] ?: @"unknown",
                          entry[@"browserContentNote"] ?: @"not evaluated",
                          entry[@"finalResult"] ?: @"unknown"];
        [lines addObject:line];
    }

    return [lines componentsJoinedByString:@"\n- "];
}

- (BOOL)installEventTap {
    if (![self accessibilityTrusted]) {
        [self removeEventTapDueToMissingAccessibilityWithReason:@"install blocked"];
        return NO;
    }

    _permissionMissingPassThroughActive = NO;
    _eventTapRemovedDueToMissingPermission = NO;
    _eventTapRemovalScheduledDueToMissingPermission = NO;
    [self recordPermissionCheckResult:@"granted (install)"];

    if (_eventTap != NULL || _eventTapSource != NULL) {
        [self updateEventTapLifecycleFlags];
        if (_eventTapInstalled) {
            if (!_eventTapEnabled) {
                HoverClickLog("HoverClick: existing click listener installed but inactive; activating");
                CGEventTapEnable(_eventTap, true);
                [self updateEventTapLifecycleFlags];
                HoverClickLog("HoverClick: existing click listener activate result=%s", _eventTapEnabled ? "enabled" : "disabled");
            }

            if (_eventTapEnabled) {
                HoverClickLog("HoverClick: click listener already installed; skipping duplicate install");
                [self updateMenuTitles];
                return YES;
            }

            HoverClickLog("HoverClick: existing click listener could not be activated; recreating");
        } else {
            HoverClickLog("HoverClick: existing click listener objects are missing or invalid; recreating");
        }

        [self removeEventTap];
    }

    [self applyGlobalAccessibilityMessagingTimeout];

    CGEventMask mask = CGEventMaskBit(kCGEventLeftMouseDown) |
                       CGEventMaskBit(kCGEventRightMouseDown);
    HoverClickLog("HoverClick: click listener scope=0x%llx leftClick=YES rightClick=YES; mouse movement, scrolling and keyboard are never observed",
                  (unsigned long long)mask);
    _eventTap = CGEventTapCreate(kCGHIDEventTap,
                                 kCGHeadInsertEventTap,
                                 kCGEventTapOptionDefault,
                                 mask,
                                 HoverClickEventTapCallback,
                                 (__bridge void *)self);
    if (_eventTap == NULL) {
        _eventTapInstalled = NO;
        _eventTapEnabled = NO;
        HoverClickLog("HoverClick: failed to create click listener. Check Accessibility permission.");
        [self setLastClickResult:@"Event Tap Create Failed"];
        [self updateMenuTitles];
        return NO;
    }
    HoverClickLog("HoverClick: click listener created");

    _eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    if (_eventTapSource == NULL) {
        CFRelease(_eventTap);
        _eventTap = NULL;
        _eventTapInstalled = NO;
        _eventTapEnabled = NO;
        HoverClickLog("HoverClick: failed to create click listener run loop source.");
        [self setLastClickResult:@"Event Tap Source Failed"];
        [self updateMenuTitles];
        return NO;
    }

    CFRunLoopAddSource(CFRunLoopGetCurrent(), _eventTapSource, kCFRunLoopCommonModes);
    CGEventTapEnable(_eventTap, true);
    [self updateEventTapLifecycleFlags];
    HoverClickLog("HoverClick: click listener activate after install result=%s", _eventTapEnabled ? "enabled" : "disabled");

    if (!_eventTapEnabled) {
        [self setLastClickResult:@"Event Tap Enable Failed"];
        [self updateMenuTitles];
        return NO;
    }

    HoverClickLog("HoverClick: click listener installed; every click is delivered unchanged by default");
    [self updateMenuTitles];
    return YES;
}

- (void)removeEventTap {
    if (_eventTap == NULL && _eventTapSource == NULL && !_eventTapInstalled && !_eventTapEnabled) {
        HoverClickLog("HoverClick: click listener remove requested but none active");
        [self updateMenuTitles];
        return;
    }

    if (_eventTap != NULL) {
        if (CFMachPortIsValid(_eventTap)) {
            CGEventTapEnable(_eventTap, false);
            HoverClickLog("HoverClick: click listener deactivated");
        } else {
            HoverClickLog("HoverClick: click listener deactivate skipped because port is invalid");
        }
    }

    if (_eventTapSource != NULL) {
        if (CFRunLoopSourceIsValid(_eventTapSource)) {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _eventTapSource, kCFRunLoopCommonModes);
        }
        CFRelease(_eventTapSource);
        _eventTapSource = NULL;
    }

    if (_eventTap != NULL) {
        CFRelease(_eventTap);
        _eventTap = NULL;
    }

    if (_eventTapInstalled) {
        HoverClickLog("HoverClick: click listener removed");
    }

    _eventTapInstalled = NO;
    _eventTapEnabled = NO;
    [self updateMenuTitles];
}

- (void)handleEventTapDisabledWithReason:(NSString *)reason shouldReenable:(BOOL)shouldReenable {
    _lastEventTapRecoveryAttemptTime = CFAbsoluteTimeGetCurrent();
    [self updateEventTapLifecycleFlags];
    [self updateMenuTitles];

    if (!_userWantsEventTap) {
        _lastEventTapRecoveryResult = [NSString stringWithFormat:@"not re-enabled after %@: user disabled tap", reason];
        HoverClickLog("HoverClick: click listener paused by macOS reason=%s; user turned it off, staying off", reason.UTF8String);
        return;
    }

    if (![self accessibilityTrusted]) {
        _lastEventTapRecoveryResult = [NSString stringWithFormat:@"not re-enabled after %@: Accessibility permission missing", reason];
        [self removeEventTapDueToMissingAccessibilityWithReason:[NSString stringWithFormat:@"listener pause (%@)", reason]];
        return;
    }

    if (!shouldReenable) {
        _lastEventTapRecoveryResult = [NSString stringWithFormat:@"not re-enabled after %@: recovery disabled", reason];
        HoverClickLog("HoverClick: click listener paused by macOS reason=%s; not resuming", reason.UTF8String);
        return;
    }

    if ([self isEventTapPortValid] && [self isEventTapSourceValid]) {
        HoverClickLog("HoverClick: resuming click listener after %s", reason.UTF8String);
        CGEventTapEnable(_eventTap, true);
        [self updateEventTapLifecycleFlags];
        if (_eventTapEnabled) {
            _lastEventTapRecoveryResult = [NSString stringWithFormat:@"re-enabled existing tap after %@", reason];
            HoverClickLog("HoverClick: click listener resumed after %s", reason.UTF8String);
            [self updateMenuTitles];
            return;
        }

        HoverClickLog("HoverClick: click listener resume after %s failed; recreating", reason.UTF8String);
    } else {
        HoverClickLog("HoverClick: click listener paused by macOS reason=%s with invalid or missing port/source; recreating", reason.UTF8String);
    }

    [self removeEventTap];
    BOOL recovered = [self installEventTap];
    _lastEventTapRecoveryResult = recovered ?
        [NSString stringWithFormat:@"recreated tap after %@", reason] :
        [NSString stringWithFormat:@"recreate failed after %@", reason];
    HoverClickLog("HoverClick: click listener recovery after %s result=%s",
                  reason.UTF8String,
                  recovered ? "recreated" : "failed");
    [self updateMenuTitles];
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

- (void)toggleAutomaticUpdateChecks:(id)sender {
    (void)sender;
    SPUUpdater *updater = self.updaterController.updater;
    BOOL automaticChecksEnabled = !updater.automaticallyChecksForUpdates;
    updater.automaticallyChecksForUpdates = automaticChecksEnabled;
    updater.automaticallyDownloadsUpdates = NO;
    [[NSUserDefaults standardUserDefaults] synchronize];

    _lastAutomaticUpdateChecksChangeTime = CFAbsoluteTimeGetCurrent();
    _lastAutomaticUpdateChecksChangeDescription = [NSString stringWithFormat:@"automatic checks %@; automatic download/install disabled",
                                                   automaticChecksEnabled ? @"enabled" : @"disabled"];

    HoverClickLog("HoverClick: automatic update checks %s; automatic download/install disabled; automatic install allowed=%s",
                  automaticChecksEnabled ? "enabled" : "disabled",
                  updater.allowsAutomaticUpdates ? "yes" : "no");
    [self setLastClickResult:automaticChecksEnabled ? @"Automatic Update Checks Enabled" : @"Automatic Update Checks Disabled"];
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

- (void)offerLaunchAtLoginOnboardingIfNeeded {
#if HOVERCLICK_HAS_SERVICE_MANAGEMENT
    if (@available(macOS 13.0, *)) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults boolForKey:HoverClickLaunchAtLoginOnboardingPromptShownDefaultsKey]) {
            _lastLaunchAtLoginOnboardingDecision = @"previously offered";
            return;
        }

        SMAppService *service = SMAppService.mainAppService;
        SMAppServiceStatus status = service.status;
        NSString *statusDescription = [self launchAtLoginStatusDescription:status];

        if (status == SMAppServiceStatusEnabled) {
            _lastLaunchAtLoginOnboardingDecision = @"not offered (already enabled)";
            return;
        }

        if (status == SMAppServiceStatusRequiresApproval) {
            _lastLaunchAtLoginOnboardingDecision = @"not offered (requires approval)";
            return;
        }

        if (status != SMAppServiceStatusNotRegistered && status != SMAppServiceStatusNotFound) {
            _lastLaunchAtLoginOnboardingDecision = [NSString stringWithFormat:@"not offered (%@)", statusDescription];
            return;
        }

        _launchAtLoginOnboardingOfferedThisLaunch = YES;
        _lastLaunchAtLoginOnboardingDecision = @"offered";

        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Start HoverClick at Login?";
        alert.informativeText = @"HoverClick can start automatically after you log in, so click focus is available without launching the app manually. This only changes the login item setting.";
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"Enable Launch at Login"];
        [alert addButtonWithTitle:@"Not Now"];

        NSModalResponse response = [alert runModal];
        [defaults setBool:YES forKey:HoverClickLaunchAtLoginOnboardingPromptShownDefaultsKey];
        [defaults synchronize];

        if (response == NSAlertFirstButtonReturn) {
            NSError *error = nil;
            if ([service registerAndReturnError:&error]) {
                _lastLaunchAtLoginOnboardingDecision = @"accepted (enabled)";
                HoverClickLog("HoverClick: Launch at Login onboarding accepted; register succeeded");
            } else {
                _lastLaunchAtLoginOnboardingDecision = @"accepted (register failed)";
                [self logLaunchAtLoginErrorForOperation:@"onboarding register" error:error];
            }
        } else {
            _lastLaunchAtLoginOnboardingDecision = @"declined";
            HoverClickLog("HoverClick: Launch at Login onboarding declined");
        }

        [self updateMenuTitles];
        return;
    }
#endif

    _lastLaunchAtLoginOnboardingDecision = @"not offered (unavailable)";
}

- (void)toggleVerboseDiagnostics:(id)sender {
    (void)sender;
    _verboseDiagnostics = !_verboseDiagnostics;
    HoverClickLog("HoverClick: verbose diagnostics %s", _verboseDiagnostics ? "enabled" : "disabled");
    [self updateMenuTitles];
}

- (void)selectBypassKey:(id)sender {
    NSMenuItem *item = (NSMenuItem *)sender;
    NSInteger newKey = item.tag;
    if (newKey != HoverClickBypassKeyOff && newKey != HoverClickBypassKeyShift && newKey != HoverClickBypassKeyFn) {
        newKey = HoverClickBypassKeyOff;
    }
    _bypassKey = newKey;
    [[NSUserDefaults standardUserDefaults] setInteger:_bypassKey forKey:HoverClickBypassKeyDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    const char *keyName = _bypassKey == HoverClickBypassKeyShift ? "shift" :
                          _bypassKey == HoverClickBypassKeyFn ? "fn" : "off";
    HoverClickLog("HoverClick: skip key set to %s", keyName);
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
    [self updateEventTapLifecycleFlags];

    if (![self accessibilityTrusted]) {
        return _userWantsEventTap ? @"permission missing" : @"disabled";
    }

    if (!_userWantsEventTap) {
        return @"disabled";
    }

    if (_eventTapEnabled) {
        return @"active";
    }

    if (_eventTapInstalled) {
        return @"installed but disabled";
    }

    if (_eventTap != NULL || _eventTapSource != NULL) {
        return @"inactive (invalid tap objects)";
    }

    return @"inactive";
}

- (NSString *)diagnosticDescriptionForClickResult:(NSString *)clickResult {
    NSString *result = clickResult ?: @"None";
    if ([result isEqualToString:@"None"]) {
        return @"none recorded";
    }

    if ([result isEqualToString:@"Permission Missing"]) {
        return @"Accessibility permission missing";
    }

    if ([result isEqualToString:@"Permission Missing Pass Through"]) {
        return @"Accessibility permission missing; click passed through unchanged";
    }

    if ([result isEqualToString:@"Permission Granted"]) {
        return @"Accessibility permission granted";
    }

    if ([result isEqualToString:@"Event Tap Create Failed"]) {
        return @"click detection setup failed";
    }

    if ([result isEqualToString:@"Event Tap Source Failed"]) {
        return @"click detection source setup failed";
    }

    if ([result isEqualToString:@"Event Tap Enable Failed"]) {
        return @"click detection enable failed";
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

    if ([result isEqualToString:@"Ignored Non-Normal UI"]) {
        return @"topmost overlay or system UI click ignored";
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

    if ([result isEqualToString:@"Verify Pending"]) {
        return @"background focus delayed verification pending";
    }

    if ([result isEqualToString:@"Verify Failed"]) {
        return @"background focus verification failed";
    }

    if ([result isEqualToString:@"Succeeded"]) {
        return @"verified successful background focus";
    }

    if ([result isEqualToString:@"Finder Context Menu Pass Through"]) {
        return @"Finder context-menu follow-up click passed through";
    }

    return result;
}

- (NSString *)lastActionForDiagnostics {
    return [self diagnosticDescriptionForClickResult:_lastClickResult];
}

- (NSString *)lastNonMenuActionForDiagnostics {
    return [self diagnosticDescriptionForClickResult:_lastNonMenuClickResult];
}

- (NSString *)diagnosticsSummaryText {
    BOOL trusted = [self accessibilityTrusted];
    NSString *accessibilityStatus = trusted ? @"granted" : @"missing";
    NSString *clickFocusDisabledByPermission = trusted ? @"no" : @"yes";
    [self updateEventTapLifecycleFlags];

    NSString *lastAction = [self lastActionForDiagnostics];
    NSString *lastNonMenuAction = [self lastNonMenuActionForDiagnostics];
    NSString *lastBackgroundFocusAttempt = @"never";
    if (_lastBackgroundFocusAttemptTime > 0) {
        lastBackgroundFocusAttempt = [NSString stringWithFormat:@"%@ sequence=%llu",
                                      HoverClickDiagnosticTimestamp(_lastBackgroundFocusAttemptTime),
                                      _lastBackgroundFocusSequence];
    }

    NSString *lastSuccessfulBackgroundFocus = @"never";
    if (_lastSuccessfulBackgroundFocusTime > 0) {
        lastSuccessfulBackgroundFocus = [NSString stringWithFormat:@"%@ at %@",
                                         _lastSuccessfulBackgroundFocusDescription ?: @"success",
                                         HoverClickDiagnosticTimestamp(_lastSuccessfulBackgroundFocusTime)];
    }
    NSString *recentDecisionHistory = [self recentDecisionHistoryDescription];
    SPUUpdater *updater = self.updaterController.updater;
    NSString *automaticUpdateChecksStatus = updater.automaticallyChecksForUpdates ? @"enabled" : @"disabled";
    NSString *automaticDownloadInstallStatus = updater.automaticallyDownloadsUpdates ? @"enabled" : @"disabled";
    NSString *automaticDownloadInstallAllowed = updater.allowsAutomaticUpdates ? @"yes" : @"no";
    NSString *manualUpdateCheckAvailability = (self.checkForUpdatesItem.enabled && self.checkForUpdatesItem.target != nil) ? @"available" : @"unavailable";
    NSString *appcastURL = HoverClickInfoString(@"SUFeedURL", @"missing");
    NSString *publicKeyStatus = [HoverClickInfoString(@"SUPublicEDKey", @"") length] > 0 ? @"present" : @"missing";
    NSString *automaticChecksDefault = HoverClickInfoBoolStatus(@"SUEnableAutomaticChecks");
    NSString *automaticDownloadInstallDefault = HoverClickInfoBoolStatus(@"SUAutomaticallyUpdate");
    NSString *automaticInstallAllowedDefault = HoverClickInfoBoolStatus(@"SUAllowsAutomaticUpdates");
    NSString *lastAutomaticUpdateChecksChange = @"never";
    if (_lastAutomaticUpdateChecksChangeTime > 0) {
        lastAutomaticUpdateChecksChange = [NSString stringWithFormat:@"%@ at %@",
                                           _lastAutomaticUpdateChecksChangeDescription ?: @"changed",
                                           HoverClickDiagnosticTimestamp(_lastAutomaticUpdateChecksChangeTime)];
    }

    return [NSString stringWithFormat:
            @"HoverClick diagnostics\n"
             "App: %@\n"
             "Bundle Identifier: %@\n"
             "Accessibility permission: %@\n"
             "Accessibility onboarding shown this launch: %@\n"
             "Accessibility trust prompt requested this launch: %@\n"
             "Click focus disabled because Accessibility permission missing: %@\n"
             "Permission missing pass-through active: %@\n"
             "Event tap removed due to missing permission: %@\n"
             "Event tap removal scheduled due to missing permission: %@\n"
             "Event tap callback pass-through due to missing permission count: %llu\n"
             "Last permission refresh/check result: %@\n"
             "Last permission refresh/check time: %@\n"
             "Last permission missing pass-through: %@\n"
             "Launch at Login: %@\n"
             "Launch at Login onboarding: %@\n"
             "Manual update check: %@\n"
             "Updater appcast URL: %@\n"
             "Updater public key: %@\n"
             "Automatic update checks default: %@\n"
             "Automatic update checks: %@\n"
             "Last automatic update checks change: %@\n"
             "Automatic download/install default: %@\n"
             "Automatic download/install: %@\n"
             "Automatic install allowed default: %@\n"
             "Automatic download/install allowed: %@\n"
             "Updater safety: automatic checks only look for updates; downloads/installs remain user-visible and automatic install is disabled unless explicitly approved\n"
             "Click detection: %@\n"
             "Last handled action: %@\n"
             "Last focus action/skip: %@\n"
             "Last non-menu focus action/skip: %@\n"
             "Last focus decision detail: %@\n"
             "Last right-click focus decision: %@\n"
             "Last real/background click decision: %@\n"
             "Last real/background click overlay detail: %@\n"
             "Last real/background click eligible candidate: %@\n"
             "Last overlay/system UI skip reason: %@\n"
             "Last overlay/system UI candidate: %@\n"
             "Last eligible hit-test candidate: %@\n"
             "Last background focus attempt: %@\n"
             "Last background focus trigger: %@\n"
             "Last background focus target app: %@\n"
             "Last background focus frontmost before: %@\n"
             "Last background focus app activation: %@\n"
             "Last background focus AX operations: %@\n"
             "Last background focus immediate frontmost: %@\n"
             "Last background focus delayed verification: %@\n"
             "Last background focus result: %@\n"
             "Last background focus verification: %@\n"
             "Last background focus failure reason: %@\n"
             "Last verified successful background focus: %@\n"
             "Click-through investigation map: A event tap health=Event tap requested/object/source/enabled rows; B callback observation=Last event tap callback and mouse-down rows; C target detection=Recent AX/target rows; D focus attempt=Last background focus attempt/focusAttempt rows; E AX result=Last background focus AX operations; F verification=immediate/delayed/result rows; G pass-through=Original event pass-through row; H app/web-content handling=Last click-through investigation row\n"
             "Original event pass-through: normal left/right mouse-down events return the original event unchanged; swallowed=no; NULL only for null event input\n"
             "Last click-through investigation: %@\n"
             "Event tap requested: %@\n"
             "Event tap object exists: %@\n"
             "Event tap port valid: %@\n"
             "Event tap run loop source exists: %@\n"
             "Event tap run loop source valid: %@\n"
             "Event tap installed (believed): %@\n"
             "Event tap enabled (believed): %@\n"
             "Event tap enabled (detected): %@\n"
             "Last event tap callback: %@\n"
             "Last left mouse down seen: %@\n"
             "Last right mouse down seen: %@\n"
             "Last tap recovery attempt: %@\n"
             "Last tap recovery result: %@\n"
             "Counters: mouse callbacks=%llu left=%llu right=%llu non-menu decisions=%llu focus attempts=%llu successful verifications=%llu policy skips=%llu overlay/system UI skips=%llu compact-popup skips=%llu menu/status UI skips=%llu\n"
             "Recent non-menu mouse-down decisions (newest first):\n- %@\n"
             "Diagnostics copy/menu note: volatile last handled/focus fields may reflect the status/menu click used to copy diagnostics; stable real/background fields and recent non-menu history ignore HoverClick menu/status UI clicks.\n"
             "Left Click Focus: %@\n"
             "Right Click Focus: %@\n"
             "Bypass Key: %@\n"
             "Last bypass decision: %@\n"
             "Excluded Apps (built-in compatibility): %@\n"
             "Excluded Apps (user list): %@\n"
             "Verbose Diagnostics: %@\n"
             "Event tap mask: left mouse down + right mouse down only\n"
             "Safety note: HoverClick returns original click events unchanged; no synthetic clicks, event replay, or cursor movement\n"
             "Known limitations: Finder may show a right-click context-target highlight without changing actual selection; HoverClick does not force Finder selection.\n"
             "Known limitations: Background text first-drag may require a second drag in some apps because the first mouse-down can be activation-only.",
            HoverClickAppName(),
            HoverClickBundleIdentifier(),
            accessibilityStatus,
            _accessibilityOnboardingShownThisLaunch ? @"yes" : @"no",
            _accessibilityTrustPromptRequestedThisLaunch ? @"yes" : @"no",
            clickFocusDisabledByPermission,
            _permissionMissingPassThroughActive ? @"yes" : @"no",
            _eventTapRemovedDueToMissingPermission ? @"yes" : @"no",
            _eventTapRemovalScheduledDueToMissingPermission ? @"yes" : @"no",
            _eventTapPermissionMissingPassThroughCount,
            _lastPermissionCheckResult ?: @"not checked",
            HoverClickDiagnosticTimestamp(_lastPermissionCheckTime),
            _lastPermissionMissingPassThroughDescription ?: @"none",
            [self launchAtLoginStatusForDiagnostics],
            _lastLaunchAtLoginOnboardingDecision ?: @"not offered",
            manualUpdateCheckAvailability,
            appcastURL,
            publicKeyStatus,
            automaticChecksDefault,
            automaticUpdateChecksStatus,
            lastAutomaticUpdateChecksChange,
            automaticDownloadInstallDefault,
            automaticDownloadInstallStatus,
            automaticInstallAllowedDefault,
            automaticDownloadInstallAllowed,
            [self clickDetectionStatusForDiagnostics],
            lastAction,
            lastAction,
            lastNonMenuAction,
            _lastFocusDecisionDescription ?: @"none",
            _lastRightClickFocusDecisionDescription ?: @"none",
            _lastRealBackgroundClickDecisionDescription ?: @"none",
            _lastRealBackgroundClickOverlayDescription ?: @"none",
            _lastRealBackgroundClickHitTestCandidateDescription ?: @"none",
            _lastOverlaySkipReason ?: @"none",
            _lastOverlayCandidateDescription ?: @"none",
            _lastEligibleHitTestCandidateDescription ?: @"none",
            lastBackgroundFocusAttempt,
            _lastBackgroundFocusTrigger ?: @"none",
            _lastBackgroundFocusTargetApp ?: @"none",
            _lastBackgroundFocusFrontmostBefore ?: @"none",
            _lastBackgroundFocusActivation ?: @"not attempted",
            _lastBackgroundFocusAXOperations ?: @"not attempted",
            _lastBackgroundFocusImmediateFrontmost ?: @"not checked",
            _lastBackgroundFocusDelayedVerification ?: @"not scheduled",
            _lastBackgroundFocusResult ?: @"none",
            _lastBackgroundFocusVerification ?: @"not applicable",
            _lastBackgroundFocusFailureReason ?: @"none",
            lastSuccessfulBackgroundFocus,
            _lastClickThroughInvestigationDescription ?: @"none",
            _userWantsEventTap ? @"enabled" : @"disabled",
            _eventTap != NULL ? @"yes" : @"no",
            [self eventTapPortValidityDescription],
            _eventTapSource != NULL ? @"yes" : @"no",
            [self eventTapSourceValidityDescription],
            _eventTapInstalled ? @"yes" : @"no",
            _eventTapEnabled ? @"yes" : @"no",
            [self eventTapDetectedEnabledDescription],
            _lastEventTapCallbackDescription ?: @"none",
            HoverClickDiagnosticTimestamp(_lastLeftMouseDownSeenTime),
            HoverClickDiagnosticTimestamp(_lastRightMouseDownSeenTime),
            HoverClickDiagnosticTimestamp(_lastEventTapRecoveryAttemptTime),
            _lastEventTapRecoveryResult ?: @"none",
            _totalMouseCallbacksSeen,
            _totalLeftMouseCallbacksSeen,
            _totalRightMouseCallbacksSeen,
            _totalNonMenuMouseCallbacks,
            _totalFocusAttempts,
            _totalSuccessfulFocusVerifications,
            _totalPolicySkips,
            _totalOverlaySystemUISkips,
            _totalCompactPopupSkips,
            _totalMenuStatusUISkips,
            recentDecisionHistory,
            _clickToFocusEnabled ? @"enabled" : @"disabled",
            _rightClickFocusEnabled ? @"enabled" : @"disabled",
            _bypassKey == HoverClickBypassKeyShift ? @"shift" : _bypassKey == HoverClickBypassKeyFn ? @"fn" : @"off",
            _lastBypassDecision ?: @"none",
            ({
                NSURL *maccyURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:HoverClickMaccyBundleID];
                [NSString stringWithFormat:@"Maccy (%@) %@", HoverClickMaccyBundleID, maccyURL != nil ? @"installed" : @"not installed"];
            }),
            ({
                NSArray<NSString *> *ids = [self userExcludedBundleIDs];
                ids.count == 0 ? @"0 apps (none added)" : [NSString stringWithFormat:@"%lu app(s): %@", (unsigned long)ids.count, [ids componentsJoinedByString:@", "]];
            }),
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

    if (self.diagnosticsCopyItem != nil) {
        [self showTransientTitle:@"Copied"
                          onItem:self.diagnosticsCopyItem
                    restoreTitle:@"Copy Summary"
                      generation:&_copyFeedbackGeneration
                      completion:nil];
    }
}

- (void)showAboutHoverClick:(id)sender {
    (void)sender;

    NSString *message = [NSString stringWithFormat:
                         @"Version %@\n"
                          "Build %@\n"
                          "Bundle ID: %@\n\n"
                          "Windows-like click focus for macOS.",
                         HoverClickDisplayVersion(),
                         HoverClickBuildVersion(),
                         HoverClickBundleIdentifier()];
    [self showInformationalAlertWithTitle:@"HoverClick" message:message];
}

- (void)openURLString:(NSString *)urlString label:(NSString *)label {
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil) {
        HoverClickLog("HoverClick: failed to create %s URL", (label ?: @"link").UTF8String);
        return;
    }

    if (![[NSWorkspace sharedWorkspace] openURL:url]) {
        HoverClickLog("HoverClick: failed to open %s URL", (label ?: @"link").UTF8String);
    }
}

- (void)openGitHub:(id)sender {
    (void)sender;
    [self openURLString:@"https://github.com/gergoterek/HoverClick"
                  label:@"GitHub"];
}

- (void)openContact:(id)sender {
    (void)sender;
    [self openURLString:@"mailto:mushikalabs@gmail.com"
                  label:@"Contact"];
}

- (void)openReleaseNotes:(id)sender {
    (void)sender;
    [self openURLString:@"https://github.com/gergoterek/HoverClick/releases"
                  label:@"Release Notes"];
}

- (void)showUninstallInstructions:(id)sender {
    (void)sender;
    [self showInformationalAlertWithTitle:@"Uninstall HoverClick"
                                  message:@"To uninstall HoverClick, turn off Launch at Login, quit HoverClick, then move HoverClick.app to the Trash."];
}

- (void)updateMenuTitles {
    BOOL trusted = [self accessibilityTrusted];
    self.permissionItem.title = HoverClickMenuItemTitle(trusted ? @"Accessibility: Granted" : @"Accessibility: Required");
    self.permissionItem.state = trusted ? NSControlStateValueOn : NSControlStateValueOff;
    self.permissionItem.toolTip = trusted ? HoverClickAccessibilityStatusHelp : @"HoverClick needs Accessibility permission before click focus can work.";
    HoverClickSyncMenuRowView(self.permissionItem);

    if (!_showRefreshStatusFeedback) {
        self.permissionRefreshItem.title = HoverClickMenuItemTitle(@"Refresh Status");
        self.permissionRefreshItem.enabled = YES;
        self.permissionRefreshItem.state = NSControlStateValueOff;
        self.permissionRefreshItem.toolTip = HoverClickRefreshAccessibilityHelp;
        HoverClickSyncMenuRowView(self.permissionRefreshItem);
    }

    self.clickToFocusItem.title = HoverClickMenuItemTitle(@"Left Click Focus");
    self.clickToFocusItem.enabled = trusted;
    self.clickToFocusItem.state = _clickToFocusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.clickToFocusItem.toolTip = trusted ? HoverClickLeftClickFocusHelp : @"Requires Accessibility permission.";
    HoverClickSyncMenuRowView(self.clickToFocusItem);
    self.rightClickFocusItem.title = HoverClickMenuItemTitle(@"Right Click Focus");
    self.rightClickFocusItem.enabled = trusted;
    self.rightClickFocusItem.state = _rightClickFocusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.rightClickFocusItem.toolTip = trusted ? HoverClickRightClickFocusHelp : @"Requires Accessibility permission.";
    HoverClickSyncMenuRowView(self.rightClickFocusItem);
    [self updateLaunchAtLoginMenuItem];
    self.verboseItem.title = HoverClickMenuItemTitle(@"Verbose Mode");
    self.verboseItem.state = _verboseDiagnostics ? NSControlStateValueOn : NSControlStateValueOff;
    HoverClickSyncMenuRowView(self.verboseItem);
    self.checkForUpdatesItem.title = HoverClickMenuItemTitle(@"Check Now...");
    self.checkForUpdatesItem.enabled = YES;
    self.checkForUpdatesItem.state = NSControlStateValueOff;
    self.checkForUpdatesItem.toolTip = HoverClickCheckForUpdatesHelp;
    self.automaticUpdateChecksItem.title = HoverClickMenuItemTitle(@"Auto Check Updates");
    self.automaticUpdateChecksItem.enabled = YES;
    self.automaticUpdateChecksItem.state = self.updaterController.updater.automaticallyChecksForUpdates ? NSControlStateValueOn : NSControlStateValueOff;
    self.automaticUpdateChecksItem.toolTip = HoverClickAutomaticUpdateChecksHelp;
    HoverClickSyncMenuRowView(self.automaticUpdateChecksItem);

    if (self.bypassKeyItem != nil && self.bypassKeyItem.submenu != nil) {
        for (NSMenuItem *bypassItem in self.bypassKeyItem.submenu.itemArray) {
            if (bypassItem.isSeparatorItem) continue;
            bypassItem.state = (bypassItem.tag == _bypassKey) ? NSControlStateValueOn : NSControlStateValueOff;
            HoverClickSyncMenuRowView(bypassItem);
        }
    }
}

// Click-path setter: no menu row shows the last click result, and menuWillOpen: refreshes the
// menu, so this must not call updateMenuTitles (it runs inside the event tap callback).
- (void)setLastClickResult:(NSString *)result {
    _lastClickResult = result ?: @"None";
    if ([self shouldPreserveAsLastNonMenuClickResult:_lastClickResult]) {
        _lastNonMenuClickResult = _lastClickResult;
    }
}

- (BOOL)shouldPreserveAsLastNonMenuClickResult:(NSString *)result {
    if (result.length == 0 || [result isEqualToString:@"None"]) {
        return NO;
    }

    static NSSet<NSString *> *volatileMenuOrSetupResults;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        volatileMenuOrSetupResults = [NSSet setWithArray:@[
            @"Permission Missing",
            @"Permission Missing Pass Through",
            @"Permission Granted",
            @"Event Tap Create Failed",
            @"Event Tap Source Failed",
            @"Event Tap Enable Failed",
            @"Event Tap Disabled",
            @"Diagnostics Summary Copied",
            @"Ignored Own App",
            @"Ignored Menu/UI",
            @"Ignored Non-Normal UI",
            @"Ignored Transient UI",
            @"Left Click Focus Enabled",
            @"Left Click Focus Disabled",
            @"Right Click Focus Enabled",
            @"Right Click Focus Disabled",
            @"Right Click Disabled",
            @"Automatic Update Checks Enabled",
            @"Automatic Update Checks Disabled"
        ]];
    });

    return ![volatileMenuOrSetupResults containsObject:result];
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

// The budget starts at the tap callback entry, recorded by recordEventTapCallbackWithType:.
- (NSTimeInterval)callbackElapsed {
    return HoverClickMonotonicSeconds() - _lastEventTapCallbackTime;
}

- (NSTimeInterval)callbackBudgetRemaining {
    NSTimeInterval remaining = HoverClickCallbackBudgetSeconds - [self callbackElapsed];
    return remaining > 0.0 ? remaining : 0.0;
}

// YES when the callback has spent its budget. Logged once per stage so the log shows where a
// slow click was cut off; the caller passes the original event through unchanged.
- (BOOL)callbackBudgetExhaustedForSequenceID:(uint64_t)sequenceID trigger:(const char *)trigger stage:(const char *)stage {
    NSTimeInterval elapsed = [self callbackElapsed];
    if (elapsed < HoverClickCallbackBudgetSeconds) {
        return NO;
    }
    HoverClickLog("HoverClick: %s #%llu callback budget exhausted stage=%s elapsed=%.0fms budget=%.0fms",
                  trigger,
                  sequenceID,
                  stage,
                  elapsed * 1000.0,
                  HoverClickCallbackBudgetSeconds * 1000.0);
    return YES;
}

- (void)applyAccessibilityMessagingTimeoutToElement:(AXUIElementRef)element {
    if (element == NULL) {
        return;
    }
    AXError error = AXUIElementSetMessagingTimeout(element, HoverClickAXMessagingTimeoutSeconds);
    if (error != kAXErrorSuccess) {
        [self diagnosticLog:"HoverClick: AX messaging timeout not applied error=%s", HoverClickAXErrorName(error)];
    }
}

// Setting the timeout on the system-wide element makes it the default for every element this
// process creates afterwards (AXUIElement.h, AXUIElementSetMessagingTimeout).
- (void)applyGlobalAccessibilityMessagingTimeout {
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    if (systemWide == NULL) {
        HoverClickLog("HoverClick: AX messaging timeout not applied: no system-wide element");
        return;
    }
    AXError error = AXUIElementSetMessagingTimeout(systemWide, HoverClickAXMessagingTimeoutSeconds);
    CFRelease(systemWide);
    HoverClickLog("HoverClick: AX messaging timeout=%.0fms callbackBudget=%.0fms result=%s",
                  HoverClickAXMessagingTimeoutSeconds * 1000.0,
                  HoverClickCallbackBudgetSeconds * 1000.0,
                  HoverClickAXErrorName(error));
}

- (BOOL)isChromeApplication:(NSRunningApplication *)app {
    return [app.bundleIdentifier isEqualToString:HoverClickChromeBundleID];
}

- (NSArray<NSString *> *)userExcludedBundleIDs {
    NSArray *raw = [[NSUserDefaults standardUserDefaults] arrayForKey:HoverClickExcludedAppsDefaultsKey];
    if (raw == nil) return @[];
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (id entry in raw) {
        if ([entry isKindOfClass:[NSString class]] && [(NSString *)entry length] > 0) {
            [result addObject:(NSString *)entry];
        }
    }
    return [result copy];
}

- (void)buildExcludedAppsSubmenu {
    NSMenu *submenu = self.excludedAppsItem.submenu;
    if (submenu == nil) return;

    [submenu removeAllItems];

    NSArray<NSString *> *userIDs = [self userExcludedBundleIDs];
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *entries =
        [NSMutableArray arrayWithCapacity:userIDs.count];
    for (NSString *bundleID in userIDs) {
        NSString *displayName = [self displayNameForExcludedBundleID:bundleID];
        [entries addObject:@{@"bundleID": bundleID, @"displayName": displayName}];
    }
    [entries sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"displayName"] compare:b[@"displayName"]
                                  options:NSCaseInsensitiveSearch];
    }];

    // Check whether Maccy is installed so a non-removable automatic row can be shown.
    // Maccy is never stored in excludedAppBundleIDs; the built-in bypass is always active.
    NSURL *maccyURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:HoverClickMaccyBundleID];
    BOOL maccyInstalled = (maccyURL != nil);
    NSString *maccyDisplayName = maccyInstalled ? [self displayNameForExcludedBundleID:HoverClickMaccyBundleID] : nil;

    // Width is driven by icon-slot rows: "Add App Exclusion...", "No added exclusions", and user
    // display names. Section headers and the Maccy automatic row use separate width-aware layouts.
    NSMutableArray<NSString *> *widthTitles = [NSMutableArray arrayWithArray:@[@"Add App Exclusion...", @"No added exclusions"]];
    for (NSDictionary *entry in entries) {
        [widthTitles addObject:entry[@"displayName"]];
    }
    CGFloat submenuWidth = HoverClickCalculatedSubmenuWidth(widthTitles);

    // Auto-added section: only shown when Maccy is installed/resolvable.
    if (maccyInstalled) {
        [submenu addItem:HoverClickCreateSubmenuSectionHeader(@"Auto-added", submenuWidth)];
        NSMenuItem *maccyItem = HoverClickCreateAutomaticEntryItem(maccyDisplayName, submenuWidth);
        maccyItem.toolTip = @"Maccy is handled automatically by HoverClick for clipboard compatibility.";
        [submenu addItem:maccyItem];
        [submenu addItem:[NSMenuItem separatorItem]];
    }

    // User-added exclusions section.
    [submenu addItem:HoverClickCreateSubmenuSectionHeader(@"Added exclusions", submenuWidth)];

    if (entries.count == 0) {
        NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"No added exclusions")
                                                           action:nil
                                                    keyEquivalent:@""];
        emptyItem.enabled = NO;
        HoverClickUseClosingSubmenuRow(emptyItem, nil, nil, submenuWidth);
        [submenu addItem:emptyItem];
    } else {
        for (NSDictionary<NSString *, NSString *> *entry in entries) {
            NSString *bundleID = entry[@"bundleID"];
            NSString *displayName = entry[@"displayName"];
            NSMenuItem *entryItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(displayName)
                                                               action:@selector(removeExcludedApp:)
                                                        keyEquivalent:@""];
            entryItem.target = self;
            entryItem.enabled = YES;
            entryItem.representedObject = bundleID;
            entryItem.toolTip = [NSString stringWithFormat:@"Click to remove %@ (%@) from the excluded apps list.", displayName, bundleID];
            HoverClickUseClosingSubmenuRow(entryItem, @"minus.circle", @"xmark.circle", submenuWidth);
            [submenu addItem:entryItem];
        }
    }

    [submenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *chooseItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Add App Exclusion...")
                                                        action:@selector(chooseExcludedApp:)
                                                 keyEquivalent:@""];
    chooseItem.target = self;
    chooseItem.enabled = YES;
    chooseItem.toolTip = HoverClickChooseExcludedAppHelp;
    HoverClickUseClosingSubmenuRow(chooseItem, @"plus.circle", @"plus", submenuWidth);
    [submenu addItem:chooseItem];
}

// Enumerates installed apps from the standard application locations only (no full-disk scan,
// no deep recursion). Returns dictionaries with keys "bundleID", "name", and optional "icon",
// deduplicated by bundle ID and sorted by display name.
- (NSArray<NSDictionary<NSString *, id> *> *)installedApplicationsForSelector {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSArray<NSString *> *searchDirectories = @[
        @"/Applications",
        @"/Applications/Utilities",
        @"/System/Applications",
        @"/System/Applications/Utilities",
        [NSHomeDirectory() stringByAppendingPathComponent:@"Applications"]
    ];

    NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *byBundleID = [NSMutableDictionary dictionary];
    for (NSString *directory in searchDirectories) {
        NSArray<NSString *> *entries = [fileManager contentsOfDirectoryAtPath:directory error:NULL];
        for (NSString *entry in entries) {
            if (![entry.pathExtension.lowercaseString isEqualToString:@"app"]) {
                continue;
            }
            NSString *fullPath = [directory stringByAppendingPathComponent:entry];
            NSURL *url = [NSURL fileURLWithPath:fullPath isDirectory:YES];
            NSBundle *bundle = [NSBundle bundleWithURL:url];
            NSString *bundleID = bundle.bundleIdentifier;
            if (bundleID.length == 0 || byBundleID[bundleID] != nil) {
                continue;
            }

            NSString *name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
            if (name.length == 0) {
                name = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
            }
            if (name.length == 0) {
                name = [entry stringByDeletingPathExtension];
            }

            NSMutableDictionary<NSString *, id> *info = [NSMutableDictionary dictionaryWithDictionary:@{
                @"bundleID": bundleID,
                @"name": name ?: bundleID
            }];
            NSImage *icon = [workspace iconForFile:fullPath];
            if (icon != nil) {
                NSImage *sized = [icon copy];
                sized.size = NSMakeSize(HoverClickMenuImageSize, HoverClickMenuImageSize);
                info[@"icon"] = sized;
            }
            byBundleID[bundleID] = info;
        }
    }

    return [byBundleID.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [(NSString *)a[@"name"] localizedCaseInsensitiveCompare:(NSString *)b[@"name"]];
    }];
}

// Resolves a stored bundle ID to a friendly display name from the installed app, or returns
// the bundle ID unchanged if the app cannot be resolved.
- (NSString *)displayNameForExcludedBundleID:(NSString *)bundleID {
    if (bundleID.length == 0) {
        return @"";
    }
    NSURL *url = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:bundleID];
    if (url == nil) {
        return bundleID;
    }
    NSBundle *bundle = [NSBundle bundleWithURL:url];
    NSString *name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (name.length == 0) {
        name = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
    }
    if (name.length == 0) {
        name = [url.lastPathComponent stringByDeletingPathExtension];
    }
    return name.length > 0 ? name : bundleID;
}

// Opens a dedicated app selector list (NSAlert + NSPopUpButton), LinearMouse-style: the user
// picks an installed application by name/icon rather than browsing the file system or typing
// a bundle ID. The selected app's bundle ID is stored internally.
- (void)chooseExcludedApp:(id)sender {
    (void)sender;
    // Defer to the next run-loop turn so the status-bar menu finishes dismissing before the
    // modal alert appears. Presenting runModal while NSMenu is still tracking produces an
    // overlapping, unclickable selector window.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray<NSDictionary<NSString *, id> *> *apps = [self installedApplicationsForSelector];
        if (apps.count == 0) {
            [self showInformationalAlertWithTitle:@"No Applications Found"
                                          message:@"HoverClick could not find any installed applications to exclude."];
            return;
        }

        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Exclude an Application";
        alert.informativeText = @"Pick an application to exclude from HoverClick focus behavior.";
        alert.alertStyle = NSAlertStyleInformational;
        [alert addButtonWithTitle:@"Exclude"];
        [alert addButtonWithTitle:@"Cancel"];

        NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 300.0, 26.0)
                                                          pullsDown:NO];
        for (NSDictionary<NSString *, id> *app in apps) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(app[@"name"])
                                                          action:nil
                                                   keyEquivalent:@""];
            item.representedObject = app[@"bundleID"];
            NSImage *icon = app[@"icon"];
            if (icon != nil) {
                item.image = icon;
            }
            [popup.menu addItem:item];
        }
        alert.accessoryView = popup;
        alert.window.initialFirstResponder = popup;

        NSModalResponse response = [alert runModal];
        if (response != NSAlertFirstButtonReturn) {
            return;
        }

        NSString *bundleID = popup.selectedItem.representedObject;
        if (bundleID.length == 0) {
            return;
        }

        HoverClickLog("HoverClick: excluded app chosen from selector bundleID=%s", bundleID.UTF8String);
        [self addExcludedBundleID:bundleID];
    });
}

// Shared validate-and-save path for the app selector. Returns YES if the bundle ID was added,
// NO if it was rejected (an alert is shown for rejections).
- (BOOL)addExcludedBundleID:(NSString *)candidate {
    NSString *normalized = [candidate stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (normalized.length == 0) {
        [self showInformationalAlertWithTitle:@"Could Not Add Application"
                                      message:@"The selected application does not report a bundle identifier and cannot be excluded."];
        return NO;
    }

    if ([normalized isEqualToString:HoverClickMaccyBundleID]) {
        [self showInformationalAlertWithTitle:@"Already Handled Automatically"
                                      message:@"Maccy is already handled automatically by HoverClick for clipboard compatibility, so it does not need to be added."];
        return NO;
    }

    NSArray<NSString *> *existing = [self userExcludedBundleIDs];
    if ([existing containsObject:normalized]) {
        NSString *displayName = [self displayNameForExcludedBundleID:normalized];
        [self showInformationalAlertWithTitle:@"Already Excluded"
                                      message:[NSString stringWithFormat:@"%@ is already in the excluded apps list.", displayName]];
        return NO;
    }

    NSMutableArray<NSString *> *updated = [existing mutableCopy];
    [updated addObject:normalized];
    [[NSUserDefaults standardUserDefaults] setObject:[updated copy] forKey:HoverClickExcludedAppsDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    HoverClickLog("HoverClick: excluded app added bundleID=%s userListCount=%lu", normalized.UTF8String, (unsigned long)updated.count);
    [self buildExcludedAppsSubmenu];
    return YES;
}

- (void)showInformationalAlertWithTitle:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title ?: @"";
    alert.informativeText = message ?: @"";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)removeExcludedApp:(id)sender {
    NSString *bundleID = nil;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        bundleID = [(NSMenuItem *)sender representedObject];
    }
    if (bundleID.length == 0) return;

    NSArray<NSString *> *existing = [self userExcludedBundleIDs];
    NSMutableArray<NSString *> *updated = [existing mutableCopy];
    [updated removeObject:bundleID];
    [[NSUserDefaults standardUserDefaults] setObject:[updated copy] forKey:HoverClickExcludedAppsDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    HoverClickLog("HoverClick: excluded app removed bundleID=%s userListCount=%lu", bundleID.UTF8String, (unsigned long)updated.count);
    [self buildExcludedAppsSubmenu];
}

// Built-in compatibility bypass — always active; Maccy is the only built-in entry.
// Maccy is a clipboard manager: clicking a history item must paste into the previously
// active app, so focus-steal would break that paste.
- (BOOL)isBuiltInCompatibilityBypassApplication:(NSRunningApplication *)app {
    NSString *bundleID = app.bundleIdentifier;
    if (bundleID.length > 0) {
        if ([bundleID isEqualToString:HoverClickMaccyBundleID]) return YES;
    } else {
        // Name fallback for apps that report an empty bundle ID at click time.
        if ([app.localizedName isEqualToString:@"Maccy"]) return YES;
    }
    return NO;
}

- (NSString *)browserContentDiagnosticNoteForTargetApp:(NSRunningApplication *)targetApp
                                               appName:(NSString *)appName
                                                  role:(NSString *)role
                                               subrole:(NSString *)subrole
                                          elementTitle:(NSString *)elementTitle
                                            windowRole:(NSString *)windowRole
                                           windowTitle:(NSString *)windowTitle
                                           focusStatus:(NSString *)focusStatus {
    NSString *bundleID = targetApp.bundleIdentifier ?: @"unknown";
    BOOL isChrome = [self isChromeApplication:targetApp];
    NSString *safeRole = HoverClickDiagnosticValue(role, @"unknown");
    NSString *safeSubrole = HoverClickDiagnosticValue(subrole, @"none");
    NSString *safeElementTitle = HoverClickTruncatedDiagnosticString(HoverClickDiagnosticValue(elementTitle, @"untitled"), 120);
    NSString *safeWindowRole = HoverClickDiagnosticValue(windowRole, @"unknown");
    NSString *safeWindowTitle = HoverClickTruncatedDiagnosticString(HoverClickDiagnosticValue(windowTitle, @"untitled"), 160);
    NSString *safeFocusStatus = HoverClickDiagnosticValue(focusStatus, @"not checked");

    if (!isChrome) {
        return [NSString stringWithFormat:@"targetIsChrome=no bundleID=%@; focusStatus=%@; app/web-content click handling not Chrome-specific",
                                          bundleID,
                                          safeFocusStatus];
    }

    NSString *combinedAXText = [NSString stringWithFormat:@"%@ %@ %@ %@",
                                safeRole,
                                safeSubrole,
                                safeElementTitle,
                                safeWindowTitle];
    BOOL googleDocsHint = HoverClickStringContainsCaseInsensitive(combinedAXText, @"Google Docs") ||
                          HoverClickStringContainsCaseInsensitive(combinedAXText, @"docs.google");
    BOOL browserWebContentHint = HoverClickStringContainsCaseInsensitive(safeRole, @"web") ||
                                 HoverClickStringContainsCaseInsensitive(safeSubrole, @"web") ||
                                 googleDocsHint;

    return [NSString stringWithFormat:@"targetIsChrome=yes bundleID=%@ googleDocsHint=%@ browserWebContentHint=%@ AX role=%@ subrole=%@ elementTitle=%@ windowRole=%@ windowTitle=%@; focusStatus=%@; HoverClick can verify app focus and original-event pass-through, not DOM/web-app click or hover handling",
                                      bundleID,
                                      googleDocsHint ? @"yes" : @"no",
                                      browserWebContentHint ? @"yes" : @"no",
                                      safeRole,
                                      safeSubrole,
                                      safeElementTitle,
                                      safeWindowRole,
                                      safeWindowTitle,
                                      safeFocusStatus];
}

- (void)recordClickThroughInvestigationForSequenceID:(uint64_t)sequenceID
                                         focusStatus:(NSString *)focusStatus
                                           finalNote:(NSString *)finalNote {
    NSMutableDictionary<NSString *, NSString *> *entry = [self recentDecisionEntryForSequenceID:sequenceID];
    NSString *browserNote = entry[@"browserContentBaseNote"] ?: entry[@"browserContentNote"] ?: @"not evaluated";
    NSString *passThrough = entry[@"eventPassThrough"] ?: @"original event returned unchanged; swallowed=no";
    NSString *targetBundleID = entry[@"targetBundleID"] ?: @"unknown";
    NSString *targetIsChrome = entry[@"targetIsChrome"] ?: @"unknown";
    NSString *alreadyFrontmost = entry[@"targetAlreadyFrontmost"] ?: @"unknown";
    NSString *safeFocusStatus = focusStatus ?: @"not checked";

    NSString *summary = [NSString stringWithFormat:@"sequence=%llu focusStatus=%@ targetBundle=%@ targetIsChrome=%@ targetAlreadyFrontmost=%@ passThrough=%@; %@%@%@",
                         sequenceID,
                         safeFocusStatus,
                         targetBundleID,
                         targetIsChrome,
                         alreadyFrontmost,
                         passThrough,
                         browserNote,
                         finalNote.length > 0 ? @"; " : @"",
                         finalNote.length > 0 ? finalNote : @""];
    _lastClickThroughInvestigationDescription = summary;
    [self updateRecentDecisionForSequenceID:sequenceID key:@"browserContentNote" value:summary];
}

// YES when the configured skip key is held for this mouse-down. clickLabel is "left" or "right"
// and only names the click in the log line.
- (BOOL)skipKeyHeldForEvent:(CGEventRef)event clickLabel:(const char *)clickLabel {
    if (_bypassKey == HoverClickBypassKeyShift || _bypassKey == HoverClickBypassKeyFn) {
        CGEventFlags flags = CGEventGetFlags(event);
        BOOL bypass = (_bypassKey == HoverClickBypassKeyShift && (flags & kCGEventFlagMaskShift) != 0) ||
                      (_bypassKey == HoverClickBypassKeyFn && (flags & kCGEventFlagMaskSecondaryFn) != 0);
        if (bypass) {
            _lastBypassDecision = (_bypassKey == HoverClickBypassKeyShift) ? @"bypassed-by-shift" : @"bypassed-by-fn";
            HoverClickLog("HoverClick: %s click skipped: skip key held (%s); original event returned unchanged",
                          clickLabel,
                          _bypassKey == HoverClickBypassKeyShift ? "shift" : "fn");
            return YES;
        }
        _lastBypassDecision = @"not-bypassed";
    }
    return NO;
}

// Records a click that is skipped after its recent decision began, for the skip paths that also
// record a click-through investigation. -passThroughUnresolvedClickForTopmostWindowInfo: records
// no investigation and intentionally does not use it.
- (void)finishSkippedClickWithSequenceID:(uint64_t)sequenceID
                                 trigger:(const char *)trigger
                                  detail:(NSString *)detail
                             focusStatus:(NSString *)focusStatus
                               finalNote:(NSString *)finalNote
                             finalResult:(NSString *)finalResult
                             clickResult:(NSString *)clickResult {
    [self recordFocusDecisionWithTrigger:trigger
                              sequenceID:sequenceID
                                decision:@"skipped"
                                  detail:detail];
    [self recordClickThroughInvestigationForSequenceID:sequenceID
                                           focusStatus:focusStatus
                                             finalNote:finalNote];
    [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
    [self completeRecentDecisionForSequenceID:sequenceID
                                  finalResult:finalResult
             keepActiveForDelayedVerification:NO];
    [self setLastClickResult:clickResult];
}

- (void)handleLeftMouseDown:(CGEventRef)event {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime sinceLastLeftMouseDown = now - _lastMouseDownLogTime;
    // A negative interval means the wall clock stepped backward. Let the click through instead of
    // dropping every click until the clock catches up.
    if (sinceLastLeftMouseDown >= 0.0 && sinceLastLeftMouseDown < 0.02) {
        return;
    }
    _lastMouseDownLogTime = now;

    if ([self skipKeyHeldForEvent:event clickLabel:"left"]) {
        return;
    }

    _clickSequence++;
    uint64_t clickID = _clickSequence;

    CGPoint rawPoint = CGEventGetLocation(event);
    CGPoint axPoint = [self accessibilityPointForEventPoint:rawPoint];
    [self beginRecentDecisionWithTrigger:"click" sequenceID:clickID rawPoint:rawPoint axPoint:axPoint];
    [self diagnosticLog:"HoverClick: click #%llu leftClickFocus=%s screenPoint=(%.1f,%.1f) axPoint=(%.1f,%.1f)",
                        clickID,
                        _clickToFocusEnabled ? "ON" : "OFF",
                        rawPoint.x,
                        rawPoint.y,
                        axPoint.x,
                        axPoint.y];

    if (!_clickToFocusEnabled) {
        HoverClickLog("HoverClick: click #%llu left click focus disabled; event passed through", clickID);
        [self finishSkippedClickWithSequenceID:clickID
                                       trigger:"click"
                                        detail:@"Left Click Focus disabled; original event passed through unchanged"
                                   focusStatus:@"skipped before target detection: Left Click Focus disabled"
                                     finalNote:@"original left mouse-down returned unchanged; swallowed=no"
                                   finalResult:@"skipped: Left Click Focus disabled"
                                   clickResult:@"Disabled"];
        return;
    }

    if ([self passThroughRecentFinderRightClickFollowUpForClickID:clickID]) {
        return;
    }

    NSDictionary *topmostWindowInfo = [self topmostWindowInfoAtPoint:axPoint];
    [self logTopmostWindowInfo:topmostWindowInfo atPoint:axPoint sequenceID:clickID trigger:"click"];
    [self updateRecentDecisionForSequenceID:clickID
                                        key:@"topmostCGWindow"
                                      value:[self compactWindowInfoDescription:topmostWindowInfo]];

    AXUIElementRef element = [self copyElementAtAccessibilityPoint:axPoint];
    if (element == NULL) {
        if ([self passThroughUnresolvedClickForTopmostWindowInfo:topmostWindowInfo
                                                         axPoint:axPoint
                                                      sequenceID:clickID
                                                         trigger:"click"]) {
            return;
        }

        HoverClickLog("HoverClick: click #%llu AX element not found at x=%.1f, y=%.1f; event passed through", clickID, axPoint.x, axPoint.y);
        [self finishSkippedClickWithSequenceID:clickID
                                       trigger:"click"
                                        detail:@"AX element not found; original event passed through unchanged"
                                   focusStatus:@"target detection failed: AX element not found"
                                     finalNote:@"original left mouse-down returned unchanged; swallowed=no"
                                   finalResult:@"skipped: AX element not found"
                                   clickResult:@"No AX Element"];
        return;
    }

    [self handleResolvedElement:element rawPoint:rawPoint axPoint:axPoint sequenceID:clickID trigger:"click" topmostWindowInfo:topmostWindowInfo];
    CFRelease(element);
}

- (void)handleRightMouseDown:(CGEventRef)event {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime sinceLastRightMouseDown = now - _lastRightMouseDownLogTime;
    // A negative interval means the wall clock stepped backward. Let the click through instead of
    // dropping every click until the clock catches up.
    if (sinceLastRightMouseDown >= 0.0 && sinceLastRightMouseDown < 0.02) {
        return;
    }
    _lastRightMouseDownLogTime = now;

    if ([self skipKeyHeldForEvent:event clickLabel:"right"]) {
        return;
    }

    _clickSequence++;
    uint64_t clickID = _clickSequence;

    CGPoint rawPoint = CGEventGetLocation(event);
    CGPoint axPoint = [self accessibilityPointForEventPoint:rawPoint];
    [self beginRecentDecisionWithTrigger:"right-click" sequenceID:clickID rawPoint:rawPoint axPoint:axPoint];
    [self diagnosticLog:"HoverClick: right-click #%llu rightClickFocus=%s leftClickFocus=%s screenPoint=(%.1f,%.1f) axPoint=(%.1f,%.1f)",
                        clickID,
                        _rightClickFocusEnabled ? "ON" : "OFF",
                        _clickToFocusEnabled ? "ON" : "OFF",
                        rawPoint.x,
                        rawPoint.y,
                        axPoint.x,
                        axPoint.y];

    if (!_rightClickFocusEnabled) {
        HoverClickLog("HoverClick: right-click #%llu right click focus disabled; event passed through", clickID);
        [self finishSkippedClickWithSequenceID:clickID
                                       trigger:"right-click"
                                        detail:@"Right Click Focus disabled; right mouse down observed and original event passed through unchanged"
                                   focusStatus:@"skipped before target detection: Right Click Focus disabled"
                                     finalNote:@"original right mouse-down returned unchanged; swallowed=no"
                                   finalResult:@"skipped: Right Click Focus disabled"
                                   clickResult:@"Right Click Disabled"];
        return;
    }

    [self recordFocusDecisionWithTrigger:"right-click"
                              sequenceID:clickID
                                decision:@"observed"
                                  detail:@"Right Click Focus enabled; resolving target window/app"];

    NSDictionary *topmostWindowInfo = [self topmostWindowInfoAtPoint:axPoint];
    [self logTopmostWindowInfo:topmostWindowInfo atPoint:axPoint sequenceID:clickID trigger:"right-click"];
    [self updateRecentDecisionForSequenceID:clickID
                                        key:@"topmostCGWindow"
                                      value:[self compactWindowInfoDescription:topmostWindowInfo]];

    AXUIElementRef element = [self copyElementAtAccessibilityPoint:axPoint];
    if (element == NULL) {
        if ([self passThroughUnresolvedClickForTopmostWindowInfo:topmostWindowInfo
                                                         axPoint:axPoint
                                                      sequenceID:clickID
                                                         trigger:"right-click"]) {
            return;
        }

        HoverClickLog("HoverClick: right-click #%llu AX element not found at x=%.1f, y=%.1f; event passed through", clickID, axPoint.x, axPoint.y);
        [self finishSkippedClickWithSequenceID:clickID
                                       trigger:"right-click"
                                        detail:@"AX element not found; original event passed through unchanged"
                                   focusStatus:@"target detection failed: AX element not found"
                                     finalNote:@"original right mouse-down returned unchanged; swallowed=no"
                                   finalResult:@"skipped: AX element not found"
                                   clickResult:@"No AX Element"];
        return;
    }

    [self handleResolvedElement:element rawPoint:rawPoint axPoint:axPoint sequenceID:clickID trigger:"right-click" topmostWindowInfo:topmostWindowInfo];
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
    [self applyAccessibilityMessagingTimeoutToElement:systemWide];

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

- (void)handleResolvedElement:(AXUIElementRef)element rawPoint:(CGPoint)rawPoint axPoint:(CGPoint)axPoint clickID:(uint64_t)clickID topmostWindowInfo:(NSDictionary *)topmostWindowInfo {
    [self handleResolvedElement:element rawPoint:rawPoint axPoint:axPoint sequenceID:clickID trigger:"click" topmostWindowInfo:topmostWindowInfo];
}

- (void)handleResolvedElement:(AXUIElementRef)element rawPoint:(CGPoint)rawPoint axPoint:(CGPoint)axPoint sequenceID:(uint64_t)sequenceID trigger:(const char *)trigger topmostWindowInfo:(NSDictionary *)topmostWindowInfo {
    NSString *role = [self stringAttribute:kAXRoleAttribute fromElement:element] ?: @"unknown";
    NSString *subrole = [self stringAttribute:kAXSubroleAttribute fromElement:element] ?: @"";
    NSString *elementTitle = [self stringAttribute:kAXTitleAttribute fromElement:element] ?: @"";
    [self updateRecentDecisionForSequenceID:sequenceID
                                        key:@"axTarget"
                                      value:[NSString stringWithFormat:@"elementRole=%@ elementSubrole=%@ title=%@",
                                             role,
                                             subrole.length > 0 ? subrole : @"none",
                                             elementTitle.length > 0 ? elementTitle : @"untitled"]];
    [self diagnosticLog:"HoverClick: %s #%llu AX element found role=%s subrole=%s title=%s",
                        trigger,
                        sequenceID,
                        role.UTF8String,
                        subrole.UTF8String,
                        elementTitle.UTF8String];

    if ([self callbackBudgetExhaustedForSequenceID:sequenceID trigger:trigger stage:"element-attributes"]) {
        [self passThroughForExhaustedBudgetWithSequenceID:sequenceID trigger:trigger stage:@"element attributes"];
        return;
    }

    pid_t targetPid = 0;
    AXError pidError = AXUIElementGetPid(element, &targetPid);
    if (pidError != kAXErrorSuccess || targetPid <= 0) {
        HoverClickLog("HoverClick: %s #%llu target pid unresolved error=%s; event passed through", trigger, sequenceID, HoverClickAXErrorName(pidError));
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"skipped"
                                      detail:[NSString stringWithFormat:@"target pid unresolved error=%s; original event passed through unchanged",
                                                                        HoverClickAXErrorName(pidError)]];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"target detection failed: target pid unresolved"
                                                 finalNote:@"original event passed through before focus attempt"];
        [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:@"skipped: target pid unresolved"
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"No Target PID"];
        return;
    }

    NSRunningApplication *targetApp = [NSRunningApplication runningApplicationWithProcessIdentifier:targetPid];
    if (targetApp == nil) {
        HoverClickLog("HoverClick: %s #%llu target app unresolved pid=%d; event passed through", trigger, sequenceID, targetPid);
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"skipped"
                                      detail:[NSString stringWithFormat:@"target app unresolved pid=%d; original event passed through unchanged", targetPid]];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"target detection failed: target app unresolved"
                                                 finalNote:@"original event passed through before focus attempt"];
        [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:@"skipped: target app unresolved"
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"No Target App"];
        return;
    }

    NSString *appName = targetApp.localizedName ?: [NSString stringWithFormat:@"pid %d", targetPid];
    NSString *targetBundleID = targetApp.bundleIdentifier ?: @"unknown";
    BOOL targetIsChrome = [self isChromeApplication:targetApp];
    HoverClickLog("HoverClick: %s #%llu target pid=%d app=%s", trigger, sequenceID, targetPid, appName.UTF8String);
    [self updateRecentDecisionForSequenceID:sequenceID key:@"targetBundleID" value:targetBundleID];
    [self updateRecentDecisionForSequenceID:sequenceID key:@"targetIsChrome" value:targetIsChrome ? @"yes" : @"no"];

    if ([self isBuiltInCompatibilityBypassApplication:targetApp]) {
        _lastBypassDecision = @"bypassed-maccy";
        HoverClickLog("HoverClick: %s #%llu excluded app Maccy bundleID=%s; skipping focus/raise/activate; original event returned unchanged",
                      trigger, sequenceID, targetBundleID.UTF8String);
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"skipped"
                                      detail:@"excluded app: Maccy (built-in); HoverClick skipped focus/raise/activate; original event returned unchanged"];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"skipped before focus attempt: excluded app (Maccy, built-in)"
                                                 finalNote:@"original event returned unchanged; swallowed=no"];
        [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:@"skipped: excluded app (Maccy, built-in)"
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"Excluded App (Maccy)"];
        return;
    }

    if ([[self userExcludedBundleIDs] containsObject:targetBundleID]) {
        _lastBypassDecision = [NSString stringWithFormat:@"excluded-app:%@", targetBundleID];
        HoverClickLog("HoverClick: %s #%llu excluded app bundleID=%s; skipping focus/raise/activate; original event returned unchanged",
                      trigger, sequenceID, targetBundleID.UTF8String);
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"skipped"
                                      detail:[NSString stringWithFormat:@"excluded app: %@; HoverClick skipped focus/raise/activate; original event returned unchanged", targetBundleID]];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:[NSString stringWithFormat:@"skipped before focus attempt: excluded app (%@)", targetBundleID]
                                                 finalNote:@"original event returned unchanged; swallowed=no"];
        [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:[NSString stringWithFormat:@"skipped: excluded app (%@)", targetBundleID]
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:[NSString stringWithFormat:@"Excluded App (%@)", targetBundleID]];
        return;
    }
    [self updateRecentDecisionForSequenceID:sequenceID
                                        key:@"eventPassThrough"
                                      value:@"original event returned unchanged by callback; swallowed=no"];
    [self updateRecentDecisionForSequenceID:sequenceID
                                        key:@"axTarget"
                                      value:[NSString stringWithFormat:@"app=%@ pid=%d bundleID=%@ elementRole=%@ elementSubrole=%@",
                                             appName,
                                             targetPid,
                                             targetBundleID,
                                             role,
                                             subrole.length > 0 ? subrole : @"none"]];
    NSString *initialBrowserNote = [self browserContentDiagnosticNoteForTargetApp:targetApp
                                                                          appName:appName
                                                                             role:role
                                                                          subrole:subrole
                                                                     elementTitle:elementTitle
                                                                       windowRole:@"not resolved"
                                                                      windowTitle:@"not resolved"
                                                                      focusStatus:@"target app resolved; target window pending"];
    [self updateRecentDecisionForSequenceID:sequenceID key:@"browserContentBaseNote" value:initialBrowserNote];
    [self updateRecentDecisionForSequenceID:sequenceID key:@"browserContentNote" value:initialBrowserNote];
    [self recordClickThroughInvestigationForSequenceID:sequenceID
                                           focusStatus:@"target app resolved; target window pending"
                                             finalNote:nil];

    if (targetPid == getpid()) {
        [self recordOverlaySkipWithReason:@"HoverClick status/menu UI"
                            topmostWindow:topmostWindowInfo
                                      role:role
                                   subrole:subrole
                                   appName:appName
                                 targetPid:targetPid];
        HoverClickLog("HoverClick: %s #%llu ignored reason=own-app; event passed through", trigger, sequenceID);
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"skipped"
                                      detail:@"HoverClick status/menu UI; original event passed through unchanged"];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"skipped before focus attempt: HoverClick status/menu UI"
                                                 finalNote:@"original event passed through unchanged"];
        [self recordMenuStatusDecisionForSequenceID:sequenceID
                                        finalResult:@"skipped: HoverClick status/menu UI"];
        [self setLastClickResult:@"Ignored Own App"];
        return;
    }

    if (strcmp(trigger, "right-click") == 0) {
        [self recordRecentFinderRightClickForApp:targetApp pid:targetPid sequenceID:sequenceID];
    }

    if ([self shouldIgnoreRole:role subrole:subrole appName:appName targetPid:targetPid point:axPoint]) {
        [self recordOverlaySkipWithReason:@"AX role/subrole is menu, status item, popover, system UI, or HoverClick"
                            topmostWindow:topmostWindowInfo
                                      role:role
                                   subrole:subrole
                                   appName:appName
                                 targetPid:targetPid];
        HoverClickLog("HoverClick: %s #%llu ignored reason=menu-role role=%s subrole=%s app=%s; event passed through", trigger, sequenceID, role.UTF8String, subrole.UTF8String, appName.UTF8String);
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"skipped"
                                      detail:[NSString stringWithFormat:@"ineligible menu/system UI role=%@ subrole=%@ app=%@; original event passed through unchanged",
                                                                        role,
                                                                        subrole.length > 0 ? subrole : @"none",
                                                                        appName]];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"skipped before focus attempt: menu/status/system UI role"
                                                 finalNote:@"overlay/menu/system UI classification passed the original event through"];
        [self recordMenuStatusDecisionForSequenceID:sequenceID
                                        finalResult:@"skipped: menu/status/system UI role"];
        [self setLastClickResult:@"Ignored Menu/UI"];
        return;
    }

    NSString *nonNormalSkipReason = [self nonNormalTopWindowSkipReasonForWindowInfo:topmostWindowInfo
                                                                          targetPid:targetPid
                                                                            appName:appName
                                                                               role:role
                                                                            subrole:subrole
                                                                              point:axPoint];
    if (nonNormalSkipReason.length > 0) {
        [self recordOverlaySkipWithReason:nonNormalSkipReason
                            topmostWindow:topmostWindowInfo
                                      role:role
                                   subrole:subrole
                                   appName:appName
                                 targetPid:targetPid];
        HoverClickLog("HoverClick: %s #%llu ignored reason=non-normal-top-window %s; event passed through before focus attempt",
                      trigger,
                      sequenceID,
                      _lastOverlayCandidateDescription.UTF8String);
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"skipped"
                                      detail:[NSString stringWithFormat:@"%@; original event passed through before focus attempt",
                                                                        nonNormalSkipReason]];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"skipped before focus attempt: non-normal top window"
                                                 finalNote:nonNormalSkipReason];
        [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:[NSString stringWithFormat:@"skipped: %@", nonNormalSkipReason]
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"Ignored Non-Normal UI"];
        return;
    }

    [self recordNonNormalTopWindowDidNotBlockForWindowInfo:topmostWindowInfo
                                                      role:role
                                                   subrole:subrole
                                                   appName:appName
                                                 targetPid:targetPid
                                                     point:axPoint
                                                sequenceID:sequenceID
                                                   trigger:trigger];

    NSRunningApplication *frontApp = [NSWorkspace sharedWorkspace].frontmostApplication;
    BOOL targetIsFrontmost = frontApp != nil && frontApp.processIdentifier == targetPid;
    // A click on the frontmost application's own background window (two Google Docs windows side
    // by side, the key one on the right, the click on the left one) used to be passed through
    // here untouched. Chrome then makes that window key and delivers the click in one go, and
    // Google Docs drops the click while it handles the focus change: measured 2026-09-21, clicks
    // #52 to #63, every one of them needed a second click. Such a click now gets the same focus
    // treatment as a click on a background application: the window is focused first, the click
    // arrives afterwards. Clicks on the key window itself still pass through untouched.
    BOOL clickedWindowBehindSibling = targetIsFrontmost && [self clickedWindowOfElement:element isBehindSiblingOfPid:targetPid topmostWindowInfo:topmostWindowInfo];
    if (targetIsFrontmost && !clickedWindowBehindSibling &&
        [self callbackBudgetExhaustedForSequenceID:sequenceID trigger:trigger stage:"window-resolution"]) {
        [self passThroughForExhaustedBudgetWithSequenceID:sequenceID trigger:trigger stage:@"window resolution"];
        return;
    }
    [self updateRecentDecisionForSequenceID:sequenceID
                                        key:@"targetAlreadyFrontmost"
                                      value:targetIsFrontmost ? (clickedWindowBehindSibling ? @"yes-sibling-window" : @"yes") : @"no"];
    if (clickedWindowBehindSibling) {
        HoverClickLog("HoverClick: %s #%llu frontmost app pid=%d but the clicked window is behind a sibling window; focus attempt continues",
                      trigger,
                      sequenceID,
                      targetPid);
    }
    if (targetIsFrontmost && !clickedWindowBehindSibling) {
        BOOL afterRecentRightClickFocus = (strcmp(trigger, "click") == 0 &&
                                           _lastRightClickFocusPid == targetPid &&
                                           CFAbsoluteTimeGetCurrent() - _lastRightClickFocusTime < 5.0);
        HoverClickLog("HoverClick: %s #%llu ignored reason=already-frontmost pid=%d app=%s recentRightClickFocus=%s; event passed through",
                      trigger,
                      sequenceID,
                      targetPid,
                      appName.UTF8String,
                      afterRecentRightClickFocus ? "YES" : "NO");
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"skipped"
                                      detail:[NSString stringWithFormat:@"target already frontmost app=%@ pid=%d recentRightClickFocus=%@; original event passed through unchanged",
                                                                        appName,
                                                                        targetPid,
                                                                        afterRecentRightClickFocus ? @"yes" : @"no"]];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"target already frontmost; no background focus attempt needed"
                                                 finalNote:@"if Chrome or Google Docs missed the click here, HoverClick only observed pass-through and cannot observe DOM/web-app handling"];
        [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:@"skipped: target already frontmost"
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"Already Frontmost"];
        return;
    }

    AXUIElementRef targetWindow = [self copyWindowForElement:element];
    if (targetWindow == NULL) {
        if ([self callbackBudgetExhaustedForSequenceID:sequenceID trigger:trigger stage:"window-resolution"]) {
            [self passThroughForExhaustedBudgetWithSequenceID:sequenceID trigger:trigger stage:@"window resolution"];
            return;
        }
        HoverClickLog("HoverClick: %s #%llu AX window not found for pid=%d app=%s; event passed through", trigger, sequenceID, targetPid, appName.UTF8String);
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"skipped"
                                      detail:[NSString stringWithFormat:@"AX window not found for app=%@ pid=%d; original event passed through unchanged",
                                                                        appName,
                                                                        targetPid]];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"target detection failed: AX window not found"
                                                 finalNote:@"original event passed through before focus attempt"];
        [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:@"skipped: AX window not found"
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"No Target Window"];
        return;
    }

    NSString *windowRole = [self stringAttribute:kAXRoleAttribute fromElement:targetWindow] ?: @"unknown";
    NSString *windowTitle = [self stringAttribute:kAXTitleAttribute fromElement:targetWindow] ?: @"";
    HoverClickLog("HoverClick: %s #%llu target window role=%s title=%s", trigger, sequenceID, windowRole.UTF8String, windowTitle.UTF8String);
    [self updateRecentDecisionForSequenceID:sequenceID
                                        key:@"targetWindowTitle"
                                      value:HoverClickTruncatedDiagnosticString(HoverClickDiagnosticValue(windowTitle, @"untitled"), 160)];
    NSString *resolvedBrowserNote = [self browserContentDiagnosticNoteForTargetApp:targetApp
                                                                           appName:appName
                                                                              role:role
                                                                           subrole:subrole
                                                                      elementTitle:elementTitle
                                                                        windowRole:windowRole
                                                                       windowTitle:windowTitle
                                                                       focusStatus:@"target window resolved; policy checks pending"];
    [self updateRecentDecisionForSequenceID:sequenceID key:@"browserContentBaseNote" value:resolvedBrowserNote];
    [self updateRecentDecisionForSequenceID:sequenceID key:@"browserContentNote" value:resolvedBrowserNote];

    if ([self shouldIgnoreWindowRole:windowRole targetPid:targetPid]) {
        [self recordOverlaySkipWithReason:@"AX window role is transient UI for the current front app"
                            topmostWindow:topmostWindowInfo
                                      role:windowRole
                                   subrole:subrole
                                   appName:appName
                                 targetPid:targetPid];
        HoverClickLog("HoverClick: %s #%llu ignored reason=transient-window role=%s app=%s; event passed through", trigger, sequenceID, windowRole.UTF8String, appName.UTF8String);
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"skipped"
                                      detail:[NSString stringWithFormat:@"transient window role=%@ app=%@; original event passed through unchanged",
                                                                        windowRole,
                                                                        appName]];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"skipped before focus attempt: transient window role"
                                                 finalNote:@"overlay/menu/system UI classification passed the original event through"];
        [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:@"skipped: transient window role"
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"Ignored Transient UI"];
        CFRelease(targetWindow);
        return;
    }

    if ([self callbackBudgetExhaustedForSequenceID:sequenceID trigger:trigger stage:"before-focus-attempt"]) {
        [self passThroughForExhaustedBudgetWithSequenceID:sequenceID trigger:trigger stage:@"before focus attempt"];
        CFRelease(targetWindow);
        return;
    }

    _lastEligibleHitTestCandidateDescription = [NSString stringWithFormat:@"trigger=%s sequence=%llu app=%@ pid=%d elementRole=%@ elementSubrole=%@ windowRole=%@ windowTitle=%@",
                                                trigger,
                                                sequenceID,
                                                appName,
                                                targetPid,
                                                role,
                                                subrole.length > 0 ? subrole : @"none",
                                                windowRole,
                                                windowTitle.length > 0 ? windowTitle : @"untitled"];
    [self updateRecentDecisionForSequenceID:sequenceID key:@"eligibleCandidate" value:@"yes"];
    [self updateRecentDecisionForSequenceID:sequenceID
                                        key:@"eligibleCandidateDetail"
                                      value:_lastEligibleHitTestCandidateDescription];
    [self updateRecentDecisionForSequenceID:sequenceID
                                        key:@"axTarget"
                                      value:[NSString stringWithFormat:@"app=%@ pid=%d bundleID=%@ elementRole=%@ elementSubrole=%@ windowRole=%@ windowTitle=%@",
                                             appName,
                                             targetPid,
                                             targetBundleID,
                                             role,
                                             subrole.length > 0 ? subrole : @"none",
                                             windowRole,
                                             windowTitle.length > 0 ? windowTitle : @"untitled"]];
    [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
    [self recordFocusDecisionWithTrigger:trigger
                              sequenceID:sequenceID
                                decision:@"eligible"
                                  detail:[NSString stringWithFormat:@"target app=%@ pid=%d windowRole=%@; starting focus attempt",
                                                                    appName,
                                                                    targetPid,
                                                                    windowRole]];
    [self recordClickThroughInvestigationForSequenceID:sequenceID
                                           focusStatus:@"eligible target resolved; starting background focus attempt"
                                             finalNote:nil];

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

// Bookkeeping for a click that ran out of callback budget: the original event is returned
// unchanged by the caller, nothing was raised or activated.
- (void)passThroughForExhaustedBudgetWithSequenceID:(uint64_t)sequenceID trigger:(const char *)trigger stage:(NSString *)stage {
    NSString *detail = [NSString stringWithFormat:@"callback budget exhausted at %@ (elapsed %.0f ms); original event passed through before focus attempt",
                        stage,
                        [self callbackElapsed] * 1000.0];
    [self recordFocusDecisionWithTrigger:trigger
                              sequenceID:sequenceID
                                decision:@"skipped"
                                  detail:detail];
    [self recordClickThroughInvestigationForSequenceID:sequenceID
                                           focusStatus:@"skipped before focus attempt: callback budget exhausted"
                                             finalNote:detail];
    [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
    [self completeRecentDecisionForSequenceID:sequenceID
                                  finalResult:[NSString stringWithFormat:@"skipped: callback budget exhausted at %@", stage]
             keepActiveForDelayedVerification:NO];
    [self setLastClickResult:@"Budget Exhausted"];
}

- (void)recordRecentFinderRightClickForApp:(NSRunningApplication *)targetApp pid:(pid_t)targetPid sequenceID:(uint64_t)sequenceID {
    NSString *bundleID = targetApp.bundleIdentifier ?: @"";
    if (![bundleID isEqualToString:HoverClickFinderBundleID]) {
        return;
    }

    _lastFinderRightClickPid = targetPid;
    _lastFinderRightClickTime = CFAbsoluteTimeGetCurrent();
    [self diagnosticLog:"HoverClick: right-click #%llu recorded Finder follow-up pass-through state pid=%d",
                        sequenceID,
                        targetPid];
}

- (void)clearRecentFinderRightClick {
    _lastFinderRightClickPid = 0;
    _lastFinderRightClickTime = 0;
}

- (BOOL)passThroughRecentFinderRightClickFollowUpForClickID:(uint64_t)clickID {
    if (_lastFinderRightClickPid <= 0 || _lastFinderRightClickTime <= 0) {
        return NO;
    }

    CFAbsoluteTime elapsed = CFAbsoluteTimeGetCurrent() - _lastFinderRightClickTime;
    if (elapsed > 5.0) {
        [self clearRecentFinderRightClick];
        return NO;
    }

    NSRunningApplication *frontApp = [NSWorkspace sharedWorkspace].frontmostApplication;
    pid_t frontPid = frontApp.processIdentifier;
    NSString *bundleID = frontApp.bundleIdentifier ?: @"";
    BOOL frontmostFinderMatchesRightClick = (frontApp != nil &&
                                             frontPid == _lastFinderRightClickPid &&
                                             [bundleID isEqualToString:HoverClickFinderBundleID]);

    [self clearRecentFinderRightClick];

    if (!frontmostFinderMatchesRightClick) {
        return NO;
    }

    HoverClickLog("HoverClick: click #%llu ignored reason=recent-finder-right-click-context-menu pid=%d; event passed through before AX lookup",
                  clickID,
                  frontPid);
    [self recordFocusDecisionWithTrigger:"click"
                              sequenceID:clickID
                                decision:@"skipped"
                                  detail:@"recent Finder right-click context menu follow-up; original left click passed through before AX lookup"];
    [self recordClickThroughInvestigationForSequenceID:clickID
                                           focusStatus:@"skipped before AX lookup: recent Finder right-click context menu follow-up"
                                             finalNote:@"original left mouse-down returned unchanged; swallowed=no"];
    [self includeRecentDecisionInHistoryForSequenceID:clickID];
    [self completeRecentDecisionForSequenceID:clickID
                                  finalResult:@"skipped: recent Finder right-click context menu follow-up"
             keepActiveForDelayedVerification:NO];
    [self setLastClickResult:@"Finder Context Menu Pass Through"];
    return YES;
}

- (NSDictionary *)topmostWindowInfoAtPoint:(CGPoint)point {
    NSArray *windowList = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly,
                                                                       kCGNullWindowID));
    for (NSDictionary *windowInfo in windowList) {
        NSNumber *alphaNumber = windowInfo[(__bridge NSString *)kCGWindowAlpha];
        if (alphaNumber != nil && alphaNumber.doubleValue <= 0.0) {
            continue;
        }

        NSDictionary *boundsDictionary = windowInfo[(__bridge NSString *)kCGWindowBounds];
        if (![boundsDictionary isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        CGRect bounds = CGRectNull;
        if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)boundsDictionary, &bounds) ||
            CGRectIsEmpty(bounds)) {
            continue;
        }

        if (CGRectContainsPoint(bounds, point)) {
            return [windowInfo copy];
        }
    }

    return nil;
}

// Answers whether the clicked AX window is the topmost on-screen normal-level window of its own
// application, matched by frame. Activation only carries the main and key windows forward, and
// the key window is whatever the application had in front before the click; when that is the
// clicked window itself, activation cannot raise a sibling. On success the CG window number is
// returned through outWindowID so the caller can wait for that window to reach the front.
// Reads the on-screen bounds of an AX window: two AX reads.
- (BOOL)readBounds:(CGRect *)outBounds ofAXWindow:(AXUIElementRef)window {
    if (window == NULL || outBounds == NULL) {
        return NO;
    }
    CGPoint position = CGPointZero;
    CFTypeRef positionValue = NULL;
    if (AXUIElementCopyAttributeValue(window, kAXPositionAttribute, &positionValue) != kAXErrorSuccess || positionValue == NULL) {
        return NO;
    }
    BOOL positionRead = (CFGetTypeID(positionValue) == AXValueGetTypeID() &&
                         AXValueGetValue((AXValueRef)positionValue, kAXValueTypeCGPoint, &position));
    CFRelease(positionValue);

    CGSize size = CGSizeZero;
    CFTypeRef sizeValue = NULL;
    if (AXUIElementCopyAttributeValue(window, kAXSizeAttribute, &sizeValue) != kAXErrorSuccess || sizeValue == NULL) {
        return NO;
    }
    BOOL sizeRead = (CFGetTypeID(sizeValue) == AXValueGetTypeID() &&
                     AXValueGetValue((AXValueRef)sizeValue, kAXValueTypeCGSize, &size));
    CFRelease(sizeValue);
    if (!positionRead || !sizeRead) {
        return NO;
    }
    *outBounds = CGRectMake(position.x, position.y, size.width, size.height);
    return YES;
}

// YES when the first on-screen normal-level window of pid in front-to-back order (the
// application's own topmost window) has these bounds. One window-list read, no AX call.
- (BOOL)areBounds:(CGRect)axBounds frontWindowOfPid:(pid_t)pid outWindowID:(CGWindowID *)outWindowID {
    NSArray *windowList = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
                                                                       kCGNullWindowID));
    for (NSDictionary *windowInfo in windowList) {
        if ([self layerForWindowInfo:windowInfo] != 0 || [self ownerPidForWindowInfo:windowInfo] != pid) {
            continue;
        }
        NSNumber *alphaNumber = windowInfo[(__bridge NSString *)kCGWindowAlpha];
        if (alphaNumber != nil && alphaNumber.doubleValue <= 0.0) {
            continue;
        }
        CGRect bounds = CGRectNull;
        NSDictionary *boundsDictionary = windowInfo[(__bridge NSString *)kCGWindowBounds];
        if (![boundsDictionary isKindOfClass:[NSDictionary class]] ||
            !CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)boundsDictionary, &bounds) ||
            bounds.size.width < 50.0 || bounds.size.height < 50.0) {
            continue;
        }

        // First normal window of this process in front-to-back order: the application's topmost.
        BOOL matches = (fabs(bounds.origin.x - axBounds.origin.x) <= 2.0 &&
                        fabs(bounds.origin.y - axBounds.origin.y) <= 2.0 &&
                        fabs(bounds.size.width - axBounds.size.width) <= 2.0 &&
                        fabs(bounds.size.height - axBounds.size.height) <= 2.0);
        if (matches && outWindowID != NULL) {
            NSNumber *windowNumber = windowInfo[(__bridge NSString *)kCGWindowNumber];
            *outWindowID = (CGWindowID)windowNumber.unsignedIntValue;
        }
        return matches;
    }
    return NO;
}

- (BOOL)isWindow:(AXUIElementRef)window topmostWindowOfPid:(pid_t)pid outWindowID:(CGWindowID *)outWindowID {
    CGRect bounds = CGRectNull;
    if (![self readBounds:&bounds ofAXWindow:window]) {
        return NO;
    }
    return [self areBounds:bounds frontWindowOfPid:pid outWindowID:outWindowID];
}

// YES when the element's window resolves and is not the application's own topmost window, that
// is, a background sibling of the key window. A non-normal-layer window of pid that is itself the
// window under the cursor is not a sibling. Three AX reads and one window-list read; used only
// for clicks on the frontmost application.
- (BOOL)clickedWindowOfElement:(AXUIElementRef)element isBehindSiblingOfPid:(pid_t)pid topmostWindowInfo:(NSDictionary *)topmostWindowInfo {
    if (element == NULL || [self callbackBudgetRemaining] <= 0.0) {
        return NO;
    }
    AXUIElementRef window = [self copyWindowForElement:element];
    if (window == NULL) {
        return NO;
    }
    [self applyAccessibilityMessagingTimeoutToElement:window];
    CGRect bounds = CGRectNull;
    BOOL boundsRead = [self readBounds:&bounds ofAXWindow:window];
    CFRelease(window);
    if (!boundsRead) {
        return NO;
    }
    // A floating panel, inspector or palette of the application itself (window layer != 0) can
    // never be the process's front layer-0 window, yet it is in front of every document window:
    // clicking it is not a click behind a sibling. Only when the clicked AX window is that very
    // window under the cursor, so a target-owned overlay above a real sibling still counts.
    if (topmostWindowInfo != nil &&
        [self layerForWindowInfo:topmostWindowInfo] != 0 &&
        [self ownerPidForWindowInfo:topmostWindowInfo] == pid) {
        CGRect panelBounds = [self boundsForWindowInfo:topmostWindowInfo];
        if (!CGRectIsNull(panelBounds) &&
            fabs(panelBounds.origin.x - bounds.origin.x) <= 2.0 &&
            fabs(panelBounds.origin.y - bounds.origin.y) <= 2.0 &&
            fabs(panelBounds.size.width - bounds.size.width) <= 2.0 &&
            fabs(panelBounds.size.height - bounds.size.height) <= 2.0) {
            return NO;
        }
    }
    return ![self areBounds:bounds frontWindowOfPid:pid outWindowID:NULL];
}

// After a successful AX raise the window server reorders the application's windows
// asynchronously: 12 ms after the raise the clicked window was still not the process's front
// window (click #89, 2026-09-21). Polls the window list until it is, at most
// HoverClickRaiseSettleTimeout or what is left of the callback budget. Two AX reads once, then
// window-list reads only. Returns the elapsed time; sets *reached and *outWindowID.
- (NSTimeInterval)waitForWindow:(AXUIElementRef)window
        toBecomeFrontWindowOfPid:(pid_t)pid
                     outWindowID:(CGWindowID *)outWindowID
                         reached:(BOOL *)reached {
    NSTimeInterval start = HoverClickMonotonicSeconds();
    NSTimeInterval cap = MIN(HoverClickRaiseSettleTimeout, [self callbackBudgetRemaining]);
    BOOL done = NO;
    CGRect bounds = CGRectNull;
    if ([self readBounds:&bounds ofAXWindow:window]) {
        while (!done) {
            done = [self areBounds:bounds frontWindowOfPid:pid outWindowID:outWindowID];
            if (done || HoverClickMonotonicSeconds() - start >= cap) {
                break;
            }
            usleep(HoverClickActivationWaitPollMicroseconds);
        }
    }
    if (reached != NULL) {
        *reached = done;
    }
    return HoverClickMonotonicSeconds() - start;
}

// Activates the process so that only its front window comes forward. -activateWithOptions:
// brings the application's key window with it, and the key window stays whatever the
// application had in front before the click (measured 2026-09-14), which is how a sibling window
// rose above the covering window. SetFrontProcessWithOptions with kSetFrontProcessFrontWindowOnly
// is public HIServices API (deprecated since 10.9, still exported); it raises the process's front
// window alone, which after the AX raise is the clicked window. No event is created or posted.
- (BOOL)activateFrontWindowOnlyOfPid:(pid_t)pid {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    ProcessSerialNumber psn = {0, kNoProcess};
    if (GetProcessForPID(pid, &psn) != noErr) {
        return NO;
    }
    return SetFrontProcessWithOptions(&psn, kSetFrontProcessFrontWindowOnly) == noErr;
#pragma clang diagnostic pop
}

// Waits until the application's focused UI element, as its accessibility tree reports it, lies
// in the clicked window. For Chrome this is the renderer's answer, so it lands only after the
// page has processed the focus change; the window list cannot see that. Two AX reads per poll,
// at most HoverClickActivationWaitTimeout minus the time the activation wait already took.
- (NSTimeInterval)waitForFocusedElementOfApp:(AXUIElementRef)appElement
                                  toBeInWindow:(AXUIElementRef)window
                                           cap:(NSTimeInterval)requestedCap
                                       reached:(BOOL *)reached {
    NSTimeInterval start = HoverClickMonotonicSeconds();
    NSTimeInterval cap = MIN(requestedCap, [self callbackBudgetRemaining]);
    BOOL done = NO;
    while (appElement != NULL && window != NULL && cap > 0.0) {
        CFTypeRef focusedElement = NULL;
        if (AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute, &focusedElement) == kAXErrorSuccess &&
            focusedElement != NULL) {
            if (CFGetTypeID(focusedElement) == AXUIElementGetTypeID()) {
                [self applyAccessibilityMessagingTimeoutToElement:(AXUIElementRef)focusedElement];
                CFTypeRef focusedWindow = NULL;
                if (AXUIElementCopyAttributeValue((AXUIElementRef)focusedElement, kAXWindowAttribute, &focusedWindow) == kAXErrorSuccess &&
                    focusedWindow != NULL) {
                    done = CFEqual(focusedWindow, window);
                    CFRelease(focusedWindow);
                }
            }
            CFRelease(focusedElement);
        }
        if (done || HoverClickMonotonicSeconds() - start >= cap) {
            break;
        }
        usleep(HoverClickActivationWaitPollMicroseconds);
    }
    if (reached != NULL) {
        *reached = done;
    }
    return HoverClickMonotonicSeconds() - start;
}

// Blocks the tap callback until windowID is the topmost on-screen normal-level window, or until
// HoverClickActivationWaitTimeout passes. The cap never grows; it shrinks to what is left of the
// callback budget. Returns the elapsed time; sets *reachedFront.
- (NSTimeInterval)waitForWindowIDToReachFront:(CGWindowID)windowID reachedFront:(BOOL *)reachedFront {
    NSTimeInterval start = HoverClickMonotonicSeconds();
    NSTimeInterval cap = MIN(HoverClickActivationWaitTimeout, [self callbackBudgetRemaining]);
    BOOL reached = NO;
    while (!reached) {
        NSArray *windowList = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
                                                                           kCGNullWindowID));
        for (NSDictionary *windowInfo in windowList) {
            if ([self layerForWindowInfo:windowInfo] != 0) {
                continue;
            }
            NSNumber *alphaNumber = windowInfo[(__bridge NSString *)kCGWindowAlpha];
            if (alphaNumber != nil && alphaNumber.doubleValue <= 0.0) {
                continue;
            }
            NSNumber *windowNumber = windowInfo[(__bridge NSString *)kCGWindowNumber];
            reached = ((CGWindowID)windowNumber.unsignedIntValue == windowID);
            break;
        }
        if (reached || HoverClickMonotonicSeconds() - start >= cap) {
            break;
        }
        usleep(HoverClickActivationWaitPollMicroseconds);
    }
    if (reachedFront != NULL) {
        *reachedFront = reached;
    }
    return HoverClickMonotonicSeconds() - start;
}

- (void)logTopmostWindowInfo:(NSDictionary *)windowInfo atPoint:(CGPoint)point sequenceID:(uint64_t)sequenceID trigger:(const char *)trigger {
    // Every line below is verbose-only; skip building the window description when it is off.
    if (!_verboseDiagnostics) {
        return;
    }

    if (windowInfo == nil) {
        [self diagnosticLog:"HoverClick: %s #%llu topmost CG window not found at x=%.1f y=%.1f",
                            trigger,
                            sequenceID,
                            point.x,
                            point.y];
        return;
    }

    NSInteger layer = [self layerForWindowInfo:windowInfo];
    if (layer == 0) {
        [self diagnosticLog:"HoverClick: %s #%llu topmost CG window normal %s", trigger, sequenceID, [self compactWindowInfoDescription:windowInfo].UTF8String];
    } else {
        [self diagnosticLog:"HoverClick: %s #%llu topmost CG window non-normal %s", trigger, sequenceID, [self compactWindowInfoDescription:windowInfo].UTF8String];
    }
}

- (BOOL)passThroughUnresolvedClickForTopmostWindowInfo:(NSDictionary *)windowInfo axPoint:(CGPoint)axPoint sequenceID:(uint64_t)sequenceID trigger:(const char *)trigger {
    if ([self layerForWindowInfo:windowInfo] == 0) {
        return NO;
    }

    NSString *reason = @"non-normal top window and AX hit-test did not resolve a target element";
    [self recordOverlaySkipWithReason:reason
                        topmostWindow:windowInfo
                                  role:@"unresolved"
                               subrole:@""
                               appName:@"unresolved"
                             targetPid:0];
    HoverClickLog("HoverClick: %s #%llu ignored reason=non-normal-top-window-no-ax x=%.1f y=%.1f %s; event passed through before focus attempt",
                  trigger,
                  sequenceID,
                  axPoint.x,
                  axPoint.y,
                  _lastOverlayCandidateDescription.UTF8String);
    [self recordFocusDecisionWithTrigger:trigger
                              sequenceID:sequenceID
                                decision:@"skipped"
                                  detail:@"non-normal top window and unresolved AX hit-test; original event passed through before focus attempt"];
    [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
    [self completeRecentDecisionForSequenceID:sequenceID
                                  finalResult:@"skipped: non-normal top window and unresolved AX hit-test"
             keepActiveForDelayedVerification:NO];
    [self setLastClickResult:@"Ignored Non-Normal UI"];
    return YES;
}

- (NSString *)nonNormalTopWindowSkipReasonForWindowInfo:(NSDictionary *)windowInfo targetPid:(pid_t)targetPid appName:(NSString *)appName role:(NSString *)role subrole:(NSString *)subrole point:(CGPoint)point {
    if ([self layerForWindowInfo:windowInfo] == 0) {
        return nil;
    }

    pid_t ownerPid = [self ownerPidForWindowInfo:windowInfo];
    if (ownerPid == getpid()) {
        return @"topmost non-normal window belongs to HoverClick";
    }

    if ([self roleLooksLikeProtectedSystemUI:role subrole:subrole appName:appName]) {
        return @"AX hit-test target is menu, status item, popover, system UI, or HoverClick";
    }

    if ([self windowInfoOwnerLooksLikeMenuBarOrSystemUI:windowInfo] &&
        [self windowInfoLooksLikeMenuBarOrCompactOverlay:windowInfo]) {
        return @"topmost non-normal owner is menu bar, status, Control Center, Dock, or Bartender UI";
    }

    if (ownerPid == targetPid && [self windowInfoLooksLikeCompactOverlay:windowInfo]) {
        return @"target app owns a compact non-normal popup or overlay at the click point";
    }

    if ([self windowInfoLooksLikePassThroughWindowServerPointerSurface:windowInfo
                                                                 point:point
                                                               appName:appName
                                                                  role:role
                                                               subrole:subrole]) {
        return nil;
    }

    if ([self windowInfoLooksLikePopupLayer:windowInfo] &&
        [self windowInfoLooksLikeCompactOverlay:windowInfo]) {
        return @"topmost non-normal popup/menu layer is compact and likely interactive";
    }

    return nil;
}

- (void)recordOverlaySkipWithReason:(NSString *)reason topmostWindow:(NSDictionary *)windowInfo role:(NSString *)role subrole:(NSString *)subrole appName:(NSString *)appName targetPid:(pid_t)targetPid {
    _lastOverlaySkipReason = reason ?: @"unknown";
    _lastOverlayCandidateDescription = [NSString stringWithFormat:@"%@; AX target app=%@ pid=%d role=%@ subrole=%@",
                                        [self compactWindowInfoDescription:windowInfo],
                                        appName ?: @"unknown",
                                        targetPid,
                                        role ?: @"unknown",
                                        subrole.length > 0 ? subrole : @"none"];
    BOOL compactInvolved = [self windowInfoLooksLikeCompactOverlay:windowInfo] ||
                           [_lastOverlaySkipReason rangeOfString:@"compact" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                           [_lastOverlaySkipReason rangeOfString:@"popup" options:NSCaseInsensitiveSearch].location != NSNotFound;
    BOOL hoverClickMenuStatusSkip = [_lastOverlaySkipReason isEqualToString:@"HoverClick status/menu UI"];
    if (!hoverClickMenuStatusSkip) {
        _totalOverlaySystemUISkips++;
    }
    if (!hoverClickMenuStatusSkip && compactInvolved) {
        _totalCompactPopupSkips++;
    }
    [self updateRecentDecisionForSequenceID:_clickSequence key:@"overlayOrSystemUIInvolved" value:@"yes"];
    [self updateRecentDecisionForSequenceID:_clickSequence key:@"compactPopupInvolved" value:compactInvolved ? @"yes" : @"no"];
    [self updateRecentDecisionForSequenceID:_clickSequence key:@"topmostCGWindow" value:_lastOverlayCandidateDescription];
}

- (void)recordNonNormalTopWindowDidNotBlockForWindowInfo:(NSDictionary *)windowInfo role:(NSString *)role subrole:(NSString *)subrole appName:(NSString *)appName targetPid:(pid_t)targetPid point:(CGPoint)point sequenceID:(uint64_t)sequenceID trigger:(const char *)trigger {
    if ([self layerForWindowInfo:windowInfo] == 0) {
        return;
    }

    BOOL passThroughWindowServerSurface = [self windowInfoLooksLikePassThroughWindowServerPointerSurface:windowInfo
                                                                                                  point:point
                                                                                                appName:appName
                                                                                                   role:role
                                                                                                subrole:subrole];
    _lastOverlaySkipReason = passThroughWindowServerSurface ?
        @"not skipped: compact Window Server pointer-like surface ignored as pass-through over normal AX target" :
        @"not skipped: AX hit-test resolved a normal eligible app/window candidate";
    _lastOverlayCandidateDescription = [NSString stringWithFormat:@"%@; AX target app=%@ pid=%d role=%@ subrole=%@",
                                        [self compactWindowInfoDescription:windowInfo],
                                        appName ?: @"unknown",
                                        targetPid,
                                        role ?: @"unknown",
                                        subrole.length > 0 ? subrole : @"none"];
    [self updateRecentDecisionForSequenceID:sequenceID
                                        key:@"overlayOrSystemUIInvolved"
                                      value:passThroughWindowServerSurface ? @"yes (Window Server pass-through surface ignored)" : @"yes (did not block)"];
    if (passThroughWindowServerSurface) {
        [self updateRecentDecisionForSequenceID:sequenceID key:@"compactPopupInvolved" value:@"ignored pass-through Window Server surface"];
    }
    [self updateRecentDecisionForSequenceID:sequenceID key:@"topmostCGWindow" value:_lastOverlayCandidateDescription];
    [self diagnosticLog:"HoverClick: %s #%llu non-normal top window did not block focus candidate %s",
                        trigger,
                        sequenceID,
                        _lastOverlayCandidateDescription.UTF8String];
}

- (NSInteger)layerForWindowInfo:(NSDictionary *)windowInfo {
    NSNumber *layerNumber = windowInfo[(__bridge NSString *)kCGWindowLayer];
    return layerNumber != nil ? layerNumber.integerValue : 0;
}

- (pid_t)ownerPidForWindowInfo:(NSDictionary *)windowInfo {
    NSNumber *ownerPidNumber = windowInfo[(__bridge NSString *)kCGWindowOwnerPID];
    return ownerPidNumber != nil ? ownerPidNumber.intValue : 0;
}

- (CGRect)boundsForWindowInfo:(NSDictionary *)windowInfo {
    NSDictionary *boundsDictionary = windowInfo[(__bridge NSString *)kCGWindowBounds];
    if (![boundsDictionary isKindOfClass:[NSDictionary class]]) {
        return CGRectNull;
    }

    CGRect bounds = CGRectNull;
    if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)boundsDictionary, &bounds)) {
        return CGRectNull;
    }

    return bounds;
}

- (NSString *)compactWindowInfoDescription:(NSDictionary *)windowInfo {
    if (windowInfo == nil) {
        return @"topmostWindow=none";
    }

    NSInteger layer = [self layerForWindowInfo:windowInfo];
    pid_t ownerPid = [self ownerPidForWindowInfo:windowInfo];
    NSString *ownerName = windowInfo[(__bridge NSString *)kCGWindowOwnerName] ?: @"unknown";
    NSString *ownerBundleID = @"";
    NSRunningApplication *ownerApp = ownerPid > 0 ? [NSRunningApplication runningApplicationWithProcessIdentifier:ownerPid] : nil;
    if (ownerApp.bundleIdentifier.length > 0) {
        ownerBundleID = ownerApp.bundleIdentifier;
    }
    NSNumber *windowNumber = windowInfo[(__bridge NSString *)kCGWindowNumber] ?: @(0);
    NSString *windowTitle = windowInfo[(__bridge NSString *)kCGWindowName] ?: @"";
    CGRect bounds = [self boundsForWindowInfo:windowInfo];
    NSString *boundsDescription = CGRectIsNull(bounds) ?
        @"unknown" :
        [NSString stringWithFormat:@"x=%.0f y=%.0f w=%.0f h=%.0f", bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height];

    return [NSString stringWithFormat:@"topmostWindow layer=%ld ownerPid=%d owner=%@ ownerBundle=%@ windowNumber=%lld title=%@ bounds=%@",
                                      (long)layer,
                                      ownerPid,
                                      ownerName,
                                      ownerBundleID.length > 0 ? ownerBundleID : @"unknown",
                                      windowNumber.longLongValue,
                                      windowTitle.length > 0 ? windowTitle : @"untitled",
                                      boundsDescription];
}

- (BOOL)roleLooksLikeProtectedSystemUI:(NSString *)role subrole:(NSString *)subrole appName:(NSString *)appName {
    if ([role rangeOfString:@"Menu" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [subrole rangeOfString:@"Menu" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [subrole rangeOfString:@"Status" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    }

    if ([role isEqualToString:@"AXStatusItem"] ||
        [role isEqualToString:@"AXSystemWide"] ||
        [role isEqualToString:@"AXPopover"] ||
        [subrole isEqualToString:@"AXStatusItem"] ||
        [subrole isEqualToString:@"AXSystemWide"] ||
        [subrole isEqualToString:@"AXPopover"]) {
        return YES;
    }

    return [appName isEqualToString:@"HoverClick"];
}

- (BOOL)windowInfoOwnerLooksLikeMenuBarOrSystemUI:(NSDictionary *)windowInfo {
    pid_t ownerPid = [self ownerPidForWindowInfo:windowInfo];
    if (ownerPid == getpid()) {
        return YES;
    }

    NSString *ownerName = windowInfo[(__bridge NSString *)kCGWindowOwnerName] ?: @"";
    NSString *ownerNameLower = ownerName.lowercaseString;
    NSRunningApplication *ownerApp = ownerPid > 0 ? [NSRunningApplication runningApplicationWithProcessIdentifier:ownerPid] : nil;
    NSString *bundleID = ownerApp.bundleIdentifier ?: @"";

    if ([bundleID isEqualToString:@"com.apple.systemuiserver"] ||
        [bundleID isEqualToString:@"com.apple.controlcenter"] ||
        [bundleID isEqualToString:@"com.apple.dock"] ||
        [bundleID isEqualToString:@"com.apple.notificationcenterui"] ||
        [bundleID rangeOfString:@"bartender" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    }

    return [ownerNameLower containsString:@"systemuiserver"] ||
           [ownerNameLower containsString:@"control center"] ||
           [ownerNameLower containsString:@"notification center"] ||
           [ownerNameLower containsString:@"bartender"];
}

- (BOOL)windowInfoLooksLikeMenuBarOrCompactOverlay:(NSDictionary *)windowInfo {
    CGRect bounds = [self boundsForWindowInfo:windowInfo];
    if (CGRectIsNull(bounds) || CGRectIsEmpty(bounds)) {
        return YES;
    }

    return bounds.size.height <= 180.0 || [self windowInfoLooksLikeCompactOverlay:windowInfo];
}

- (BOOL)windowInfoLooksLikeCompactOverlay:(NSDictionary *)windowInfo {
    CGRect bounds = [self boundsForWindowInfo:windowInfo];
    if (CGRectIsNull(bounds) || CGRectIsEmpty(bounds)) {
        return YES;
    }

    CGFloat area = bounds.size.width * bounds.size.height;
    return bounds.size.height <= 360.0 && bounds.size.width <= 1800.0 && area <= 500000.0;
}

- (BOOL)windowInfoLooksLikePopupLayer:(NSDictionary *)windowInfo {
    NSInteger layer = [self layerForWindowInfo:windowInfo];
    NSInteger mainMenuLayer = CGWindowLevelForKey(kCGMainMenuWindowLevelKey);
    NSInteger popUpLayer = CGWindowLevelForKey(kCGPopUpMenuWindowLevelKey);
    NSInteger statusLayer = CGWindowLevelForKey(kCGStatusWindowLevelKey);
    return layer >= MIN(mainMenuLayer, MIN(popUpLayer, statusLayer));
}

- (BOOL)windowInfoLooksLikePassThroughWindowServerPointerSurface:(NSDictionary *)windowInfo point:(CGPoint)point appName:(NSString *)appName role:(NSString *)role subrole:(NSString *)subrole {
    if (windowInfo == nil || [self layerForWindowInfo:windowInfo] == 0) {
        return NO;
    }

    NSString *ownerName = windowInfo[(__bridge NSString *)kCGWindowOwnerName] ?: @"";
    if (![ownerName isEqualToString:@"Window Server"]) {
        return NO;
    }

    pid_t ownerPid = [self ownerPidForWindowInfo:windowInfo];
    NSRunningApplication *ownerApp = ownerPid > 0 ? [NSRunningApplication runningApplicationWithProcessIdentifier:ownerPid] : nil;
    if (ownerApp.bundleIdentifier.length > 0) {
        return NO;
    }

    NSString *windowTitle = windowInfo[(__bridge NSString *)kCGWindowName] ?: @"";
    if (windowTitle.length > 0 && ![windowTitle.lowercaseString isEqualToString:@"untitled"]) {
        return NO;
    }

    if (![self windowInfoLooksLikePopupLayer:windowInfo]) {
        return NO;
    }

    CGRect bounds = [self boundsForWindowInfo:windowInfo];
    if (CGRectIsNull(bounds) || CGRectIsEmpty(bounds)) {
        return NO;
    }

    CGFloat area = bounds.size.width * bounds.size.height;
    BOOL cursorSized = bounds.size.width <= 96.0 && bounds.size.height <= 128.0 && area <= 12000.0;
    if (!cursorSized) {
        return NO;
    }

    CGRect tolerantBounds = CGRectInset(bounds, -8.0, -8.0);
    if (!CGRectContainsPoint(tolerantBounds, point)) {
        return NO;
    }

    if ([self roleLooksLikeProtectedSystemUI:role subrole:subrole appName:appName]) {
        return NO;
    }

    return appName.length > 0 && ![appName isEqualToString:@"HoverClick"];
}

- (BOOL)shouldIgnoreRole:(NSString *)role subrole:(NSString *)subrole appName:(NSString *)appName targetPid:(pid_t)targetPid point:(CGPoint)point {
    (void)point;
    (void)targetPid;

    return [self roleLooksLikeProtectedSystemUI:role subrole:subrole appName:appName];
}

- (BOOL)shouldIgnoreWindowRole:(NSString *)role targetPid:(pid_t)targetPid {
    NSRunningApplication *frontApp = [NSWorkspace sharedWorkspace].frontmostApplication;
    BOOL belongsToFrontApp = frontApp != nil && frontApp.processIdentifier == targetPid;

    if (([role isEqualToString:@"AXSheet"] || [role isEqualToString:@"AXDialog"]) && belongsToFrontApp) {
        return YES;
    }

    return NO;
}

- (void)recordSuccessfulBackgroundFocusWithTriggerLabel:(NSString *)triggerLabel sequenceID:(uint64_t)sequenceID appName:(NSString *)appName pid:(pid_t)targetPid {
    CFAbsoluteTime focusTime = CFAbsoluteTimeGetCurrent();
    NSString *successDescription = [NSString stringWithFormat:@"%@ #%llu target=%@ pid=%d",
                                    triggerLabel ?: @"unknown",
                                    sequenceID,
                                    appName ?: @"unknown",
                                    targetPid];
    _lastSuccessfulBackgroundFocusTime = focusTime;
    _lastSuccessfulBackgroundFocusDescription = successDescription;
    _totalSuccessfulFocusVerifications++;
    if ([triggerLabel isEqualToString:@"right"]) {
        _lastRightClickFocusPid = targetPid;
        _lastRightClickFocusTime = focusTime;
    }
}

// The topmost on-screen normal-level window, by the same filter as waitForWindowIDToReachFront:.
// One window-list read, no wait: the delayed check runs on the main queue. kCGNullWindowID when
// no window matches.
- (CGWindowID)frontmostNormalWindowID {
    NSArray *windowList = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
                                                                       kCGNullWindowID));
    for (NSDictionary *windowInfo in windowList) {
        if ([self layerForWindowInfo:windowInfo] != 0) {
            continue;
        }
        NSNumber *alphaNumber = windowInfo[(__bridge NSString *)kCGWindowAlpha];
        if (alphaNumber != nil && alphaNumber.doubleValue <= 0.0) {
            continue;
        }
        NSNumber *windowNumber = windowInfo[(__bridge NSString *)kCGWindowNumber];
        return (CGWindowID)windowNumber.unsignedIntValue;
    }
    return kCGNullWindowID;
}

- (void)completeDelayedBackgroundFocusVerification:(NSDictionary *)context {
    NSNumber *sequenceNumber = context[@"sequenceID"];
    NSNumber *targetPidNumber = context[@"targetPid"];
    NSNumber *delayNumber = context[@"delay"];
    NSString *appName = context[@"appName"] ?: @"unknown";
    NSString *triggerLabel = context[@"triggerLabel"] ?: @"unknown";
    BOOL appWasFrontBefore = [context[@"appWasFrontBefore"] boolValue];
    CGWindowID clickedWindowID = (CGWindowID)[context[@"clickedWindowID"] unsignedIntValue];
    BOOL immediatePassed = [context[@"immediatePassed"] boolValue];
    uint64_t sequenceID = sequenceNumber.unsignedLongLongValue;
    pid_t targetPid = targetPidNumber.intValue;
    NSTimeInterval delay = delayNumber.doubleValue;

    if (sequenceID == 0 || targetPid <= 0) {
        return;
    }

    if (_lastBackgroundFocusSequence != sequenceID) {
        [self diagnosticLog:"HoverClick: %s #%llu delayed verify skipped reason=stale currentSequence=%llu",
                            triggerLabel.UTF8String,
                            sequenceID,
                            _lastBackgroundFocusSequence];
        [self updateRecentDecisionForSequenceID:sequenceID
                                            key:@"delayedVerification"
                                          value:[NSString stringWithFormat:@"skipped as stale; currentSequence=%llu",
                                                                         _lastBackgroundFocusSequence]];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"delayed verification skipped as stale"
                                                 finalNote:@"a newer focus attempt replaced this diagnostic context"];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:@"stale: delayed verification skipped after newer attempt"
                 keepActiveForDelayedVerification:NO];
        return;
    }

    NSRunningApplication *frontDelayed = [NSWorkspace sharedWorkspace].frontmostApplication;
    BOOL frontAppMatches = (frontDelayed != nil && frontDelayed.processIdentifier == targetPid);
    // A sibling click starts with the target application already in front, so the pid alone
    // proves nothing there; the clicked window itself has to be the front window.
    BOOL windowCheckApplies = appWasFrontBefore;
    BOOL clickedWindowFront = windowCheckApplies && clickedWindowID != kCGNullWindowID && [self frontmostNormalWindowID] == clickedWindowID;
    BOOL verified = frontAppMatches && (!windowCheckApplies || clickedWindowFront);
    NSString *frontDelayedDescription = HoverClickRunningApplicationDescription(frontDelayed);
    _lastBackgroundFocusDelayedVerification = [NSString stringWithFormat:@"%@ after %.2fs frontmost=%@",
                                               verified ? @"passed" : @"failed",
                                               delay,
                                               frontDelayedDescription];
    [self updateRecentDecisionForSequenceID:sequenceID key:@"delayedVerification" value:_lastBackgroundFocusDelayedVerification];

    HoverClickLog("HoverClick: %s #%llu delayed verify after %.2fs frontApp=%s current=%s clickedWindowFront=%s",
                  triggerLabel.UTF8String,
                  sequenceID,
                  delay,
                  frontAppMatches ? "YES" : "NO",
                  frontDelayedDescription.UTF8String,
                  windowCheckApplies ? (clickedWindowFront ? "YES" : "NO") : "not-applicable");

    NSString *failureReason = verified ?
        @"none" :
        (frontAppMatches ?
         [NSString stringWithFormat:@"clicked window %u was not the front window after delayed check; frontmost=%@", clickedWindowID, frontDelayedDescription] :
         [NSString stringWithFormat:@"frontmost after delayed check was %@", frontDelayedDescription]);
    [self recordBackgroundFocusResult:verified ? @"success" : @"verification failed"
                          verification:verified ? @"delayed passed" : @"delayed failed"
                        failureReason:failureReason];
    [self recordFocusDecisionWithTrigger:[triggerLabel isEqualToString:@"right"] ? "right-click" : "click"
                              sequenceID:sequenceID
                                decision:verified ? @"success" : @"verification failed"
                                  detail:[NSString stringWithFormat:@"delayed verification %@ after %.2fs; target=%@ pid=%d; frontmost=%@",
                                                                    verified ? @"passed" : @"failed",
                                                                    delay,
                                                                    appName,
                                                                    targetPid,
                                                                    frontDelayedDescription]];

    // An attempt that passed the immediate check was counted there already.
    if (verified && !immediatePassed) {
        [self recordSuccessfulBackgroundFocusWithTriggerLabel:triggerLabel
                                                   sequenceID:sequenceID
                                                      appName:appName
                                                          pid:targetPid];
    }
    [self recordClickThroughInvestigationForSequenceID:sequenceID
                                           focusStatus:verified ? @"delayed verification passed" : @"delayed verification failed"
                                             finalNote:verified ? @"focus succeeded; any remaining missed click is likely app/web-content-level and outside HoverClick observation" : @"focus verification failed; investigate focus path before app/web-content handling"];
    [self completeRecentDecisionForSequenceID:sequenceID
                                  finalResult:verified ? @"success: delayed verification passed" : @"failed: delayed verification failed"
             keepActiveForDelayedVerification:NO];

    if ([_lastClickResult isEqualToString:@"Verify Pending"]) {
        [self setLastClickResult:verified ? @"Succeeded" : @"Verify Failed"];
    }
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
    BOOL appWasFrontBefore = (frontBeforePid == targetPid);
    NSString *frontBeforeDescription = HoverClickRunningApplicationDescription(frontBefore);

    [self recordBackgroundFocusAttemptWithTrigger:trigger
                                      sequenceID:sequenceID
                                         appName:appName
                                             pid:targetPid
                                 frontmostBefore:frontBeforeDescription];

    // Same rule as the first gate: the frontmost application's key window passes through, its
    // background sibling window gets the focus treatment.
    if (frontBeforePid == targetPid && [self isWindow:targetWindow topmostWindowOfPid:targetPid outWindowID:NULL]) {
        HoverClickLog("HoverClick: %s #%llu ignored reason=already-frontmost pid=%d app=%s; event passed through", trigger, sequenceID, targetPid, appName.UTF8String);
        [self recordBackgroundFocusResult:@"skipped"
                              verification:@"not applicable"
                            failureReason:@"target already frontmost before focus attempt"];
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"skipped"
                                      detail:[NSString stringWithFormat:@"target already frontmost before focus attempt app=%@ pid=%d; original event passed through unchanged",
                                                                        appName,
                                                                        targetPid]];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"target already frontmost before focus attempt"
                                                 finalNote:@"if Chrome or Google Docs missed the click here, HoverClick only observed pass-through and cannot observe DOM/web-app handling"];
        [self includeRecentDecisionInHistoryForSequenceID:sequenceID];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:@"skipped: target already frontmost before focus attempt"
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"Already Frontmost"];
        return;
    }

    HoverClickLog("HoverClick: %s #%llu %s-to-focus started target=%s pid=%d frontBefore=%s",
                  trigger,
                  sequenceID,
                  trigger,
                  appName.UTF8String,
                  targetPid,
                  frontBeforeDescription.UTF8String);
    [self recordFocusDecisionWithTrigger:trigger
                              sequenceID:sequenceID
                                decision:@"focus attempt"
                                  detail:[NSString stringWithFormat:@"target=%@ pid=%d frontBefore=%@",
                                                                    appName,
                                                                    targetPid,
                                                                    frontBeforeDescription]];
    _totalFocusAttempts++;
    [self updateRecentDecisionForSequenceID:sequenceID key:@"focusAttemptStarted" value:@"yes"];
    [self recordClickThroughInvestigationForSequenceID:sequenceID
                                           focusStatus:@"background focus attempt started"
                                             finalNote:nil];

    if (_verboseDiagnostics && [self callbackBudgetRemaining] > 0.0) {
        // Three AX reads for a log line; skipped when the line would be dropped anyway or the
        // callback budget is spent, and cut short at the first read that times out.
        [self diagnosticLog:"HoverClick: %s #%llu clicked window %s",
                            trigger,
                            sequenceID,
                            HoverClickAXWindowIdentity(targetWindow, _lastEventTapCallbackTime + HoverClickCallbackBudgetSeconds).UTF8String];
    }

    // Window first, application second. -activateWithOptions: carries the application's own main
    // window forward with it. While that main window is still the sibling the user focused earlier,
    // activating first drags the sibling in front of whatever was on top, which is the multi-window
    // symptom. Pointing the application at the clicked window before activation makes the clicked
    // window the one activation carries, and the sibling keeps its z-order position.
    AXUIElementRef appElement = AXUIElementCreateApplication(targetPid);
    [self applyAccessibilityMessagingTimeoutToElement:appElement];
    [self applyAccessibilityMessagingTimeoutToElement:targetWindow];
    BOOL appElementCreated = (appElement != NULL);
    BOOL focusedWindowAttempted = NO;
    BOOL raiseAttempted = NO;
    BOOL mainWindowAttempted = NO;
    BOOL focusedAttrAttempted = NO;
    AXError focusedWindowError = kAXErrorIllegalArgument;
    AXError raiseError = kAXErrorIllegalArgument;
    AXError mainWindowError = kAXErrorIllegalArgument;
    AXError focusedAttrError = kAXErrorIllegalArgument;
    // kAXErrorCannotComplete means the application did not answer within the messaging timeout.
    // The remaining operations would block the same way, so the attempt stops at the first one:
    // nothing else is written, the application is not activated, the click is passed through.
    const char *abandonedAfter = NULL;
    if (appElement != NULL) {
        // kAXFrontmostAttribute is deliberately not set on the application element. It raises the
        // whole application, which carries every other window of the same process forward with it.
        // Measured against two Chrome windows with a third application in front: with the attribute
        // set the sibling window came forward as well, without it only the clicked window did.
        // Focus is directed at the clicked window alone, through kAXFocusedWindowAttribute below
        // and the window-level operations that follow.
        focusedWindowAttempted = YES;
        focusedWindowError = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute, targetWindow);
        if (focusedWindowError == kAXErrorCannotComplete) {
            abandonedAfter = "focusedWindow";
        }
        // appElement is released after the focused-window readback below.
    }

    if (abandonedAfter == NULL) {
        raiseAttempted = YES;
        raiseError = AXUIElementPerformAction(targetWindow, kAXRaiseAction);
        if (raiseError == kAXErrorCannotComplete) {
            abandonedAfter = "raise";
        }
    }
    HoverClickLog("HoverClick: %s #%llu AXRaise %s", trigger, sequenceID, raiseAttempted ? HoverClickAXErrorName(raiseError) : "skipped");

    if (abandonedAfter == NULL) {
        mainWindowAttempted = YES;
        mainWindowError = AXUIElementSetAttributeValue(targetWindow, kAXMainAttribute, kCFBooleanTrue);
        if (mainWindowError == kAXErrorCannotComplete) {
            abandonedAfter = "mainWindow";
        }
    }
    if (abandonedAfter == NULL) {
        focusedAttrAttempted = YES;
        focusedAttrError = AXUIElementSetAttributeValue(targetWindow, kAXFocusedAttribute, kCFBooleanTrue);
        if (focusedAttrError == kAXErrorCannotComplete) {
            abandonedAfter = "focused";
        }
    }

    NSUInteger axFailures = (focusedWindowAttempted && focusedWindowError != kAXErrorSuccess ? 1 : 0) +
                            (raiseAttempted && raiseError != kAXErrorSuccess ? 1 : 0) +
                            (mainWindowAttempted && mainWindowError != kAXErrorSuccess ? 1 : 0) +
                            (focusedAttrAttempted && focusedAttrError != kAXErrorSuccess ? 1 : 0);
    if (abandonedAfter != NULL) {
        HoverClickLog("HoverClick: %s #%llu focus attempt abandoned reason=ax-timeout operation=%s elapsed=%.0fms",
                      trigger,
                      sequenceID,
                      abandonedAfter,
                      [self callbackElapsed] * 1000.0);
    }

    _lastBackgroundFocusAXOperations = [NSString stringWithFormat:@"appElement=%@ focusedWindow=%@ raise=%@ mainWindow=%@ focused=%@ failures=%lu abandonedAfter=%s",
                                        appElementCreated ? @"yes" : @"no",
                                        HoverClickAXAttemptSummary(focusedWindowAttempted, focusedWindowError),
                                        HoverClickAXAttemptSummary(raiseAttempted, raiseError),
                                        HoverClickAXAttemptSummary(mainWindowAttempted, mainWindowError),
                                        HoverClickAXAttemptSummary(focusedAttrAttempted, focusedAttrError),
                                        (unsigned long)axFailures,
                                        abandonedAfter != NULL ? abandonedAfter : "none"];
    [self updateRecentDecisionForSequenceID:sequenceID key:@"axOperations" value:_lastBackgroundFocusAXOperations];
    [self recordClickThroughInvestigationForSequenceID:sequenceID
                                           focusStatus:@"AX operations attempted"
                                             finalNote:_lastBackgroundFocusAXOperations];

    HoverClickLog("HoverClick: %s #%llu AX focusedWindow set %s", trigger, sequenceID, focusedWindowAttempted ? HoverClickAXErrorName(focusedWindowError) : "skipped");
    [self diagnosticLog:"HoverClick: %s #%llu AX mainWindow set %s", trigger, sequenceID, mainWindowAttempted ? HoverClickAXErrorName(mainWindowError) : "skipped"];
    [self diagnosticLog:"HoverClick: %s #%llu AX focused attribute set %s", trigger, sequenceID, focusedAttrAttempted ? HoverClickAXErrorName(focusedAttrError) : "skipped"];

    // Activation is conditional. -activateWithOptions: carries the main and the key window forward,
    // and the key window stays whatever the application had in front before the click: the AX
    // operations above do not change it (measured 2026-09-14, Chrome: the sibling rose above the
    // covering window in 6 of 8 clicks on a window that was not Chrome's topmost, 0 of 25 clicks
    // on its topmost window). So the application is activated only when the clicked window is
    // already its topmost window; otherwise the user's own click activates it with that one window.
    // NSApplicationActivateAllWindows is deliberately not passed.
    //
    // When activation is requested, the callback waits for it to land before the click is passed
    // on, because activation is asynchronous: without the wait the click reached the application
    // 60 to 120 ms before it became frontmost in 147 of 147 measured attempts.
    CGWindowID clickedWindowID = kCGNullWindowID;
    BOOL budgetLeft = ([self callbackBudgetRemaining] > 0.0);
    BOOL clickedIsTopmost = (abandonedAfter == NULL && budgetLeft) ?
        [self isWindow:targetWindow topmostWindowOfPid:targetPid outWindowID:&clickedWindowID] : NO;
    // A window that is not the application's topmost used to skip activation altogether, which
    // left the application in the background and the click became its activating click: for
    // Google Docs that click is lost (clicks #84 and #89 on 2026-09-21). The raise above makes the
    // clicked window the process's front window a few milliseconds later; once it is, the process
    // is activated with only that front window (see activateFrontWindowOnlyOfPid:), so the sibling
    // stays where it was.
    BOOL frontWindowOnlyActivation = NO;
    NSTimeInterval raiseSettleWait = 0.0;
    if (!clickedIsTopmost && abandonedAfter == NULL && budgetLeft && raiseAttempted && raiseError == kAXErrorSuccess) {
        BOOL settled = NO;
        raiseSettleWait = [self waitForWindow:targetWindow toBecomeFrontWindowOfPid:targetPid outWindowID:&clickedWindowID reached:&settled];
        if (settled) {
            clickedIsTopmost = YES;
            frontWindowOnlyActivation = YES;
        }
    }
    BOOL activateAttempted = (targetApp != nil && clickedIsTopmost);
    BOOL activateResult = NO;
    BOOL activationReachedFront = NO;
    NSTimeInterval activationWait = 0.0;
    if (activateAttempted) {
        activateResult = frontWindowOnlyActivation ?
            [self activateFrontWindowOnlyOfPid:targetPid] :
            [targetApp activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        if (activateResult) {
            activationWait = [self waitForWindowIDToReachFront:clickedWindowID reachedFront:&activationReachedFront];
        }
    }
    const char *activationMode = activateAttempted ? (frontWindowOnlyActivation ? "front-window-only" : "application") : "none";
    const char *activationSkipReason = activateAttempted ? "none" :
        (targetApp == nil ? "no-running-application" :
         (abandonedAfter != NULL ? "ax-operation-timeout" :
          (!budgetLeft ? "callback-budget-exhausted" :
           (raiseAttempted && raiseError == kAXErrorSuccess ? "clicked-window-not-front-of-app-after-raise" : "clicked-window-not-topmost-of-app"))));
    HoverClickLog("HoverClick: %s #%llu activation decision clickedWindowTopmostOfApp=%s mode=%s skipReason=%s raiseSettle=%.0fms wait=%.0fms reachedFront=%s",
                  trigger,
                  sequenceID,
                  clickedIsTopmost ? "YES" : "NO",
                  activationMode,
                  activationSkipReason,
                  raiseSettleWait * 1000.0,
                  activationWait * 1000.0,
                  activateAttempted ? (activationReachedFront ? "YES" : "NO") : "not-applicable");
    _lastBackgroundFocusActivation = [NSString stringWithFormat:@"attempted=%@ mode=%s returnValue=%@ skipReason=%s raiseSettle=%.0fms wait=%.0fms reachedFront=%@",
                                      activateAttempted ? @"yes" : @"no",
                                      activationMode,
                                      activateAttempted ? (activateResult ? @"yes" : @"no") : @"not-applicable",
                                      activationSkipReason,
                                      raiseSettleWait * 1000.0,
                                      activationWait * 1000.0,
                                      activateAttempted ? (activationReachedFront ? @"yes" : @"no") : @"not-applicable"];
    [self updateRecentDecisionForSequenceID:sequenceID
                                        key:@"finalResult"
                                      value:[NSString stringWithFormat:@"focus attempt started; activation %@",
                                             _lastBackgroundFocusActivation]];
    HoverClickLog("HoverClick: %s #%llu app activation attempted=%s result=%s",
                  trigger,
                  sequenceID,
                  activateAttempted ? "YES" : "NO",
                  activateResult ? "YES" : "NO");

    // Readback after activation: does the application now treat the clicked window as its focused
    // window? The frontmost-process verification further down cannot observe this. Up to four AX
    // reads, so only when the line is kept and the attempt was not already cut short. Each read is
    // skipped once the callback budget is spent; the identity stops at the first timed-out read.
    if (_verboseDiagnostics && abandonedAfter == NULL && [self callbackBudgetRemaining] > 0.0) {
        [self diagnosticLog:"HoverClick: %s #%llu focused window readback %s",
                            trigger,
                            sequenceID,
                            HoverClickFocusedWindowComparison(appElement, targetWindow, _lastEventTapCallbackTime + HoverClickCallbackBudgetSeconds).UTF8String];
    }
    // The window list says the clicked window is in front; it cannot say whether the page inside
    // has taken focus. For Chrome the focused UI element comes from the renderer, so waiting for
    // it to lie in the clicked window gives the page time to finish its focus change before the
    // click arrives. Bounded by what is left of the activation wait cap and the callback budget.
    NSTimeInterval focusWait = 0.0;
    BOOL focusedElementInWindow = NO;
    if (activateAttempted && activateResult && appElement != NULL && abandonedAfter == NULL) {
        focusWait = [self waitForFocusedElementOfApp:appElement
                                        toBeInWindow:targetWindow
                                                 cap:MAX(0.0, HoverClickActivationWaitTimeout - activationWait)
                                             reached:&focusedElementInWindow];
    }
    HoverClickLog("HoverClick: %s #%llu focus wait=%.0fms focusedElementInClickedWindow=%s",
                  trigger,
                  sequenceID,
                  focusWait * 1000.0,
                  activateAttempted ? (focusedElementInWindow ? "YES" : "NO") : "not-applicable");
    if (appElement != NULL) {
        CFRelease(appElement);
        appElement = NULL;
    }

    // Immediate verification. NSWorkspace.frontmostApplication is refreshed on the main run loop,
    // which this callback blocks; it passed in 0 of 170 attempts across the c700de2 and 65c130f
    // builds. Two signals that do not go through the run loop replace it: the window list read by
    // the wait (the clicked window reached the front) and the focused application as the
    // Accessibility server reports it. Both are logged so a later measurement can compare them.
    pid_t focusedAppPid = ([self callbackBudgetRemaining] > 0.0) ? HoverClickAXFocusedApplicationPid() : 0;
    BOOL frontImmediate = (activateAttempted && activationReachedFront) || (focusedAppPid > 0 && focusedAppPid == targetPid);
    // For a sibling click the target was already the focused application, so the pid clause
    // proves nothing; only the clicked window reaching the front counts.
    BOOL immediatePassed = appWasFrontBefore ? (activateAttempted && activationReachedFront) : frontImmediate;
    NSString *focusedAppDescription = focusedAppPid > 0 ?
        HoverClickRunningApplicationDescription([NSRunningApplication runningApplicationWithProcessIdentifier:focusedAppPid]) :
        @"not-read";
    _lastBackgroundFocusImmediateFrontmost = [NSString stringWithFormat:@"%@ (windowList=%@ focusedAppAX=%@ pid=%d)",
                                              frontImmediate ? @"yes" : @"no",
                                              activateAttempted ? (activationReachedFront ? @"reached" : @"not-reached") : @"not-applicable",
                                              focusedAppDescription,
                                              focusedAppPid];
    [self updateRecentDecisionForSequenceID:sequenceID key:@"immediateVerification" value:_lastBackgroundFocusImmediateFrontmost];
    HoverClickLog("HoverClick: %s #%llu %s-to-focus immediate verify frontApp=%s windowList=%s focusedAppAX=%s elapsed=%.0fms",
                  trigger,
                  sequenceID,
                  trigger,
                  frontImmediate ? "YES" : "NO",
                  activateAttempted ? (activationReachedFront ? "reached" : "not-reached") : "not-applicable",
                  focusedAppDescription.UTF8String,
                  [self callbackElapsed] * 1000.0);
    NSString *frontAfterDescription = focusedAppDescription;

    NSString *triggerLabel = HoverClickFocusTriggerLabel(trigger);
    if (immediatePassed) {
        _lastBackgroundFocusDelayedVerification = [NSString stringWithFormat:@"scheduled after %.2fs (immediate verification passed)",
                                                   HoverClickDelayedVerificationDelay];
        [self setLastClickResult:@"Succeeded"];
        [self recordBackgroundFocusResult:@"success"
                              verification:@"immediate passed"
                            failureReason:@"none"];
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"success"
                                      detail:[NSString stringWithFormat:@"immediate verification passed; target=%@ pid=%d; original event passed through unchanged",
                                                                        appName,
                                                                        targetPid]];
        [self recordSuccessfulBackgroundFocusWithTriggerLabel:triggerLabel
                                                   sequenceID:sequenceID
                                                      appName:appName
                                                          pid:targetPid];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"immediate verification passed"
                                                 finalNote:@"focus succeeded; any remaining missed click is likely app/web-content-level and outside HoverClick observation"];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:@"success: immediate verification passed"
                 keepActiveForDelayedVerification:YES];
    } else {
        NSString *verificationFailureReason = abandonedAfter != NULL ?
            [NSString stringWithFormat:@"AX operation %s timed out; focus attempt abandoned", abandonedAfter] :
            (appWasFrontBefore ?
             [NSString stringWithFormat:@"sibling window of the frontmost application did not reach the front (windowList=%s)",
                                        activateAttempted ? (activationReachedFront ? "reached" : "not-reached") : "not-applicable"] :
             [NSString stringWithFormat:@"focused application after immediate check was %@", frontAfterDescription]);
        _lastBackgroundFocusDelayedVerification = [NSString stringWithFormat:@"scheduled after %.2fs",
                                                   HoverClickDelayedVerificationDelay];
        [self updateRecentDecisionForSequenceID:sequenceID key:@"delayedVerification" value:_lastBackgroundFocusDelayedVerification];
        [self setLastClickResult:@"Verify Pending"];
        [self recordBackgroundFocusResult:@"immediate verification failed; delayed verification pending"
                              verification:@"immediate failed; delayed pending"
                            failureReason:verificationFailureReason];
        [self recordFocusDecisionWithTrigger:trigger
                                  sequenceID:sequenceID
                                    decision:@"verification pending"
                                      detail:[NSString stringWithFormat:@"immediate verification failed; delayed check scheduled after %.2fs; %@",
                                                                        HoverClickDelayedVerificationDelay,
                                                                        verificationFailureReason]];
        [self completeRecentDecisionForSequenceID:sequenceID
                                      finalResult:@"pending: delayed verification scheduled"
                 keepActiveForDelayedVerification:YES];
        [self recordClickThroughInvestigationForSequenceID:sequenceID
                                               focusStatus:@"immediate verification failed; delayed verification scheduled"
                                                 finalNote:verificationFailureReason];
    }

    // The delayed check runs on the main queue after the callback has returned, where
    // NSWorkspace is current again. It is the working signal of every measurement so far
    // (156 of 162 and 6 of 8 YES), so it runs after every attempt, passed or not.
    NSDictionary *verificationContext = @{
        @"sequenceID": @(sequenceID),
        @"targetPid": @(targetPid),
        @"appName": appName ?: @"unknown",
        @"triggerLabel": triggerLabel ?: @"unknown",
        @"delay": @(HoverClickDelayedVerificationDelay),
        @"appWasFrontBefore": @(appWasFrontBefore),
        @"clickedWindowID": @((unsigned int)clickedWindowID),
        @"immediatePassed": @(immediatePassed)
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(HoverClickDelayedVerificationDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self completeDelayedBackgroundFocusVerification:verificationContext];
    });
    HoverClickLog("HoverClick: %s #%llu event passed through elapsed=%.0fms", trigger, sequenceID, [self callbackElapsed] * 1000.0);
}

- (AXUIElementRef)copyWindowForElement:(AXUIElementRef)element {
    AXUIElementRef current = (AXUIElementRef)CFRetain(element);

    for (NSInteger depth = 0; depth < 10 && current != NULL; depth++) {
        if ([self callbackBudgetRemaining] <= 0.0) {
            [self diagnosticLog:"HoverClick: window search stopped depth=%ld reason=callback-budget", (long)depth];
            CFRelease(current);
            return NULL;
        }
        AXError roleError = kAXErrorSuccess;
        NSString *role = [self stringAttribute:kAXRoleAttribute fromElement:current error:&roleError] ?: @"unknown";
        [self diagnosticLog:"HoverClick: window search depth=%ld role=%s", (long)depth, role.UTF8String];
        // Same rule as the focus attempt: an application that did not answer one read blocks the
        // next one the same way, so the search stops at the first timed-out read.
        if (roleError == kAXErrorCannotComplete) {
            HoverClickLog("HoverClick: window search abandoned depth=%ld reason=ax-timeout attribute=role elapsed=%.0fms", (long)depth, [self callbackElapsed] * 1000.0);
            CFRelease(current);
            return NULL;
        }

        if ([self roleLooksLikeWindow:role]) {
            return current;
        }

        if ([self callbackBudgetRemaining] <= 0.0) {
            [self diagnosticLog:"HoverClick: window search stopped depth=%ld reason=callback-budget", (long)depth];
            CFRelease(current);
            return NULL;
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
        if (windowError == kAXErrorCannotComplete) {
            HoverClickLog("HoverClick: window search abandoned depth=%ld reason=ax-timeout attribute=window elapsed=%.0fms", (long)depth, [self callbackElapsed] * 1000.0);
            CFRelease(current);
            return NULL;
        }

        if ([self callbackBudgetRemaining] <= 0.0) {
            [self diagnosticLog:"HoverClick: window search stopped depth=%ld reason=callback-budget", (long)depth];
            CFRelease(current);
            return NULL;
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
    return [self stringAttribute:attribute fromElement:element error:NULL];
}

// *outError is the AX read's error, or kAXErrorSuccess when no read was made.
- (NSString *)stringAttribute:(CFStringRef)attribute fromElement:(AXUIElementRef)element error:(AXError *)outError {
    if (outError != NULL) {
        *outError = kAXErrorSuccess;
    }
    if (element == NULL || [self callbackBudgetRemaining] <= 0.0) {
        return nil;
    }

    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
    if (error != kAXErrorSuccess || value == NULL) {
        if (outError != NULL) {
            *outError = error;
        }
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
    [self openURLString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                  label:@"Accessibility settings"];
}

- (void)quitApplication:(id)sender {
    [NSApp terminate:sender];
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
