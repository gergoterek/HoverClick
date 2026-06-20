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
static const CGFloat HoverClickStatusItemLength = 23.0;
static const CGFloat HoverClickStatusIconPointSize = 16.0;
static const CGFloat HoverClickMenuContentWidth = 286.0;
static const CGFloat HoverClickSubmenuContentWidth = 240.0;
static const CGFloat HoverClickMenuLeadingInset = 14.0;
static const CGFloat HoverClickMenuTrailingInset = 8.0;
static const CGFloat HoverClickMenuIconTitleSpacing = 8.0;
static const CGFloat HoverClickMenuRightAccessoryWidth = 14.0;
static const CGFloat HoverClickMenuImagePointSize = 13.0;
static const CGFloat HoverClickMenuImageSize = 16.0;
static const CGFloat HoverClickMenuRightAccessoryX = HoverClickMenuContentWidth - HoverClickMenuTrailingInset - HoverClickMenuRightAccessoryWidth;
static const CGFloat HoverClickHeaderWidth = HoverClickMenuContentWidth;
static const CGFloat HoverClickHeaderHeight = 24.0;
static const CGFloat HoverClickHeaderStatusDotSize = 8.0;
static const CGFloat HoverClickHeaderStatusDotX = HoverClickMenuLeadingInset + (HoverClickMenuImageSize - HoverClickHeaderStatusDotSize) / 2.0;
static const CGFloat HoverClickHeaderTextX = HoverClickHeaderStatusDotX + HoverClickHeaderStatusDotSize + HoverClickMenuIconTitleSpacing;
static const CGFloat HoverClickHeaderVersionWidth = 72.0;
static const CGFloat HoverClickHeaderVersionX = HoverClickMenuRightAccessoryX + HoverClickMenuRightAccessoryWidth - HoverClickHeaderVersionWidth;
static const CGFloat HoverClickHeaderLabelY = 4.0;
static const CGFloat HoverClickHeaderLabelHeight = 18.0;
static const CGFloat HoverClickMenuRowWidth = HoverClickMenuContentWidth;
static const CGFloat HoverClickMenuRowHeight = 22.0;
static const CGFloat HoverClickMenuRowIconX = HoverClickMenuLeadingInset;
static const CGFloat HoverClickMenuRowTextX = HoverClickMenuRowIconX + HoverClickMenuImageSize + HoverClickMenuIconTitleSpacing;
static const CGFloat HoverClickMenuRowStateSize = 13.0;
static const CGFloat HoverClickMenuRowStateX = HoverClickMenuRightAccessoryX + ((HoverClickMenuRightAccessoryWidth - HoverClickMenuRowStateSize) / 2.0);
static const CGFloat HoverClickSectionHeaderHeight = 18.0;
static const CGFloat HoverClickSectionHeaderLeadingInset = HoverClickMenuLeadingInset;
static const CGFloat HoverClickSectionHeaderLabelY = 2.0;
static const CGFloat HoverClickSectionHeaderLabelHeight = 15.0;
static const CGFloat HoverClickSectionHeaderFontSize = 11.0;
static const NSTimeInterval HoverClickDelayedVerificationDelay = 0.20;
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

static NSString *HoverClickHeaderVersion(void) {
    return [NSString stringWithFormat:@"v%@", HoverClickDisplayVersion()];
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

static NSString *HoverClickFrontmostVerificationDescription(NSRunningApplication *frontApp, pid_t targetPid) {
    BOOL verified = (frontApp != nil && frontApp.processIdentifier == targetPid);
    return [NSString stringWithFormat:@"%@ verified=%@",
                                      HoverClickRunningApplicationDescription(frontApp),
                                      verified ? @"yes" : @"no"];
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

static NSString *HoverClickTruncatedDiagnosticString(NSString *value, NSUInteger maxLength) {
    if (value.length == 0 || value.length <= maxLength || maxLength <= 3) {
        return value ?: @"";
    }

    return [[value substringToIndex:maxLength - 3] stringByAppendingString:@"..."];
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
        NSImage *image = [NSImage imageWithSystemSymbolName:symbolName
                                   accessibilityDescription:nil];
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

static void HoverClickSetMenuItemImage(NSMenuItem *item, NSString *symbolName, NSString *fallbackSymbolName) {
    item.image = HoverClickMenuSystemImage(symbolName, fallbackSymbolName);
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
    CGFloat rightAccessoryX = rowWidth - HoverClickMenuTrailingInset - HoverClickMenuRightAccessoryWidth;
    self = [super initWithFrame:NSMakeRect(0.0, 0.0, rowWidth, HoverClickMenuRowHeight)];
    if (self == nil) {
        return nil;
    }

    _menuItem = menuItem;
    _actionTarget = menuItem.target;
    _actionSelector = menuItem.action;
    _rowEnabled = menuItem.enabled;

    CGFloat titleX = HoverClickMenuLeadingInset;
    if (image != nil) {
        _iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(HoverClickMenuRowIconX,
                                                                  3.0,
                                                                  HoverClickMenuImageSize,
                                                                  HoverClickMenuImageSize)];
        _iconView.image = image;
        _iconView.imageScaling = NSImageScaleProportionallyDown;
        [self addSubview:_iconView];
        titleX = HoverClickMenuRowTextX;
    }

    _titleField = [NSTextField labelWithString:menuItem.title ?: @""];
    _titleField.frame = NSMakeRect(titleX,
                                   2.0,
                                   rightAccessoryX - titleX - HoverClickMenuIconTitleSpacing,
                                   18.0);
    _titleField.font = [NSFont menuFontOfSize:0.0];
    _titleField.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_titleField];

    if (accessoryTitle.length > 0) {
        _accessoryField = [NSTextField labelWithString:accessoryTitle];
        _accessoryField.frame = NSMakeRect(rightAccessoryX - 36.0,
                                           2.0,
                                           HoverClickMenuRightAccessoryWidth + 36.0,
                                           18.0);
        _accessoryField.alignment = NSTextAlignmentRight;
        _accessoryField.font = [NSFont menuFontOfSize:0.0];
        _accessoryField.lineBreakMode = NSLineBreakByClipping;
        [self addSubview:_accessoryField];
    }

    _stateField = [NSTextField labelWithString:@""];
    _stateField.frame = NSMakeRect(rightAccessoryX - 36.0,
                                   2.0,
                                   HoverClickMenuRightAccessoryWidth + 36.0,
                                   18.0);
    _stateField.alignment = NSTextAlignmentRight;
    _stateField.font = [NSFont menuFontOfSize:0.0];
    _stateField.lineBreakMode = NSLineBreakByClipping;
    _stateField.hidden = !showsStateView;
    [self addSubview:_stateField];

    [self syncFromMenuItem];
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)setHighlighted:(BOOL)highlighted {
    _highlighted = highlighted;
    [self setNeedsDisplay:YES];
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
    self.accessoryField.textColor = textColor;

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

static void HoverClickUseCustomMenuRow(NSMenuItem *item,
                                       NSString *symbolName,
                                       NSString *fallbackSymbolName,
                                       NSString *accessoryTitle,
                                       BOOL showsStateView,
                                       BOOL closesMenuAfterAction) {
    NSImage *image = HoverClickMenuSystemImage(symbolName, fallbackSymbolName);
    HoverClickMenuRowView *rowView = [[HoverClickMenuRowView alloc] initWithMenuItem:item
                                                                               image:image
                                                                      accessoryTitle:accessoryTitle
                                                                      showsStateView:showsStateView];
    rowView.closesMenuAfterAction = closesMenuAfterAction;
    item.view = rowView;
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

static void HoverClickUseCustomSubmenuRow(NSMenuItem *item,
                                           NSString *symbolName,
                                           NSString *fallbackSymbolName,
                                           NSString *accessoryTitle,
                                           BOOL showsStateView,
                                           BOOL closesMenuAfterAction) {
    NSImage *image = HoverClickMenuSystemImage(symbolName, fallbackSymbolName);
    HoverClickMenuRowView *rowView = [[HoverClickMenuRowView alloc] initWithMenuItem:item
                                                                               image:image
                                                                      accessoryTitle:accessoryTitle
                                                                      showsStateView:showsStateView
                                                                            rowWidth:HoverClickSubmenuContentWidth];
    rowView.closesMenuAfterAction = closesMenuAfterAction;
    item.view = rowView;
}

static void HoverClickUseClosingSubmenuRow(NSMenuItem *item, NSString *symbolName, NSString *fallbackSymbolName) {
    HoverClickUseCustomSubmenuRow(item, symbolName, fallbackSymbolName, nil, NO, YES);
}

static void HoverClickUseNonClosingSubmenuRow(NSMenuItem *item, NSString *symbolName, NSString *fallbackSymbolName, BOOL showsStateView) {
    HoverClickUseCustomSubmenuRow(item, symbolName, fallbackSymbolName, nil, showsStateView, NO);
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

static NSImage *HoverClickStatusDotImage(void) {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(HoverClickHeaderStatusDotSize, HoverClickHeaderStatusDotSize)
                                    flipped:NO
                             drawingHandler:^BOOL(NSRect dstRect) {
        [[NSColor systemGreenColor] setFill];
        NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:dstRect];
        [path fill];
        return YES;
    }];
    image.size = NSMakeSize(HoverClickHeaderStatusDotSize, HoverClickHeaderStatusDotSize);
    return image;
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
    NSTextField *label = [NSTextField labelWithString:HoverClickMenuItemTitle(title)];
    label.frame = NSMakeRect(HoverClickSectionHeaderLeadingInset,
                             HoverClickSectionHeaderLabelY,
                             HoverClickMenuContentWidth - HoverClickSectionHeaderLeadingInset - HoverClickMenuTrailingInset,
                             HoverClickSectionHeaderLabelHeight);
    label.font = [NSFont systemFontOfSize:HoverClickSectionHeaderFontSize
                                   weight:NSFontWeightRegular];
    label.textColor = [NSColor disabledControlTextColor];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    [headerView addSubview:label];
    headerItem.view = headerView;
    return headerItem;
}

static NSMenuItem *HoverClickCreateHeaderMenuItem(void) {
    NSString *headerVersion = HoverClickHeaderVersion();
    NSRect headerFrame = NSMakeRect(0.0, 0.0, HoverClickHeaderWidth, HoverClickHeaderHeight);
    NSView *headerView = [[NSView alloc] initWithFrame:headerFrame];
    headerView.toolTip = HoverClickStableHelp;

    NSImageView *statusDotView = [[NSImageView alloc] initWithFrame:NSMakeRect(HoverClickHeaderStatusDotX,
                                                                               8.0,
                                                                               HoverClickHeaderStatusDotSize,
                                                                               HoverClickHeaderStatusDotSize)];
    statusDotView.image = HoverClickStatusDotImage();
    statusDotView.imageScaling = NSImageScaleProportionallyDown;
    statusDotView.toolTip = HoverClickStableHelp;
    [headerView addSubview:statusDotView];

    NSTextField *statusLabel = [NSTextField labelWithString:@"HoverClick is running"];
    statusLabel.frame = NSMakeRect(HoverClickHeaderTextX,
                                   HoverClickHeaderLabelY,
                                   HoverClickHeaderVersionX - HoverClickHeaderTextX - HoverClickMenuIconTitleSpacing,
                                   HoverClickHeaderLabelHeight);
    statusLabel.font = [NSFont menuFontOfSize:0.0];
    statusLabel.textColor = [NSColor disabledControlTextColor];
    statusLabel.toolTip = HoverClickStableHelp;
    [headerView addSubview:statusLabel];

    NSTextField *versionLabel = [NSTextField labelWithString:headerVersion];
    versionLabel.frame = NSMakeRect(HoverClickHeaderVersionX,
                                    HoverClickHeaderLabelY,
                                    HoverClickHeaderVersionWidth,
                                    HoverClickHeaderLabelHeight);
    versionLabel.alignment = NSTextAlignmentRight;
    versionLabel.font = [NSFont menuFontOfSize:0.0];
    versionLabel.textColor = [NSColor disabledControlTextColor];
    versionLabel.toolTip = HoverClickStableHelp;
    [headerView addSubview:versionLabel];

    NSMenuItem *headerItem = [[NSMenuItem alloc] initWithTitle:@""
                                                        action:nil
                                                 keyEquivalent:@""];
    headerItem.enabled = NO;
    headerItem.indentationLevel = 0;
    headerItem.state = NSControlStateValueOff;
    headerItem.view = headerView;
    headerItem.toolTip = HoverClickStableHelp;
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

static NSString *HoverClickAXAttemptSummary(BOOL attempted, AXError error) {
    if (!attempted) {
        return @"not-attempted";
    }

    return [NSString stringWithFormat:@"attempted:%s", HoverClickAXErrorName(error)];
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
- (BOOL)isChromeApplication:(NSRunningApplication *)app;
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
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _eventTapSource;
    CFAbsoluteTime _lastMouseDownLogTime;
    CFAbsoluteTime _lastRightMouseDownLogTime;
    CFAbsoluteTime _lastLeftMouseDownSeenTime;
    CFAbsoluteTime _lastRightMouseDownSeenTime;
    CFAbsoluteTime _lastEventTapCallbackTime;
    CFAbsoluteTime _lastEventTapRecoveryAttemptTime;
    CFAbsoluteTime _lastBackgroundFocusAttemptTime;
    CFAbsoluteTime _lastSuccessfulBackgroundFocusTime;
    CFAbsoluteTime _lastSuccessfulFocusTime;
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
    NSString *_lastSuccessfulFocusDescription;
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
        HoverClickLog("HoverClick: event tap disabled by timeout");
        [controller handleEventTapDisabledWithReason:@"timeout" shouldReenable:YES];
        return event;
    }

    if (type == kCGEventTapDisabledByUserInput) {
        HoverClickLog("HoverClick: event tap disabled by user input");
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
    _lastSuccessfulFocusTime = 0;
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
    _lastSuccessfulFocusDescription = @"never";
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

    [menu addItem:HoverClickCreateHeaderMenuItem()];

    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:HoverClickCreateSectionHeaderMenuItem(@"Functions")];

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

    self.permissionItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Accessibility: Required")
                                                     action:@selector(refreshAccessibilityStatus:)
                                              keyEquivalent:@""];
    self.permissionItem.target = self;
    self.permissionItem.enabled = YES;
    self.permissionItem.indentationLevel = 0;
    self.permissionItem.state = NSControlStateValueOff;
    self.permissionItem.toolTip = HoverClickAccessibilityStatusHelp;
    HoverClickUseNonClosingSubmenuRow(self.permissionItem, @"accessibility", @"person.crop.circle.badge.checkmark", YES);
    [permissionsMenu addItem:self.permissionItem];

    self.launchAtLoginItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Launch at Login")
                                                        action:@selector(toggleLaunchAtLogin:)
                                                 keyEquivalent:@""];
    self.launchAtLoginItem.target = self;
    self.launchAtLoginItem.enabled = YES;
    self.launchAtLoginItem.indentationLevel = 0;
    self.launchAtLoginItem.toolTip = HoverClickLaunchAtLoginHelp;
    HoverClickUseNonClosingSubmenuRow(self.launchAtLoginItem, @"power", @"arrow.clockwise.circle", YES);
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
    HoverClickUseNonClosingSubmenuRow(self.permissionRefreshItem, @"arrow.clockwise", @"arrow.clockwise.circle", NO);
    [permissionsMenu addItem:self.permissionRefreshItem];

    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Accessibility Settings")
                                                          action:@selector(openAccessibilitySettings:)
                                                   keyEquivalent:@""];
    settingsItem.target = self;
    settingsItem.enabled = YES;
    settingsItem.indentationLevel = 0;
    settingsItem.state = NSControlStateValueOff;
    settingsItem.toolTip = HoverClickOpenAccessibilitySettingsHelp;
    HoverClickUseClosingSubmenuRow(settingsItem, @"gearshape", @"accessibility");
    [permissionsMenu addItem:settingsItem];

    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:HoverClickCreateSectionHeaderMenuItem(@"Updates")];

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

    [menu addItem:HoverClickCreateSectionHeaderMenuItem(@"Info")];

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

    NSMenuItem *githubItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"GitHub")
                                                        action:@selector(openGitHub:)
                                                 keyEquivalent:@""];
    githubItem.target = self;
    githubItem.enabled = YES;
    githubItem.indentationLevel = 0;
    githubItem.state = NSControlStateValueOff;
    githubItem.toolTip = HoverClickGitHubHelp;
    HoverClickUseClosingSubmenuRow(githubItem, @"link", @"globe");
    [helpMenu addItem:githubItem];

    NSMenuItem *contactItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Contact")
                                                         action:@selector(openContact:)
                                                  keyEquivalent:@""];
    contactItem.target = self;
    contactItem.enabled = YES;
    contactItem.indentationLevel = 0;
    contactItem.state = NSControlStateValueOff;
    contactItem.toolTip = HoverClickContactHelp;
    HoverClickUseClosingSubmenuRow(contactItem, @"envelope", @"at");
    [helpMenu addItem:contactItem];

    NSMenuItem *releaseNotesItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Release Notes")
                                                              action:@selector(openReleaseNotes:)
                                                       keyEquivalent:@""];
    releaseNotesItem.target = self;
    releaseNotesItem.enabled = YES;
    releaseNotesItem.indentationLevel = 0;
    releaseNotesItem.state = NSControlStateValueOff;
    releaseNotesItem.toolTip = HoverClickReleaseNotesHelp;
    HoverClickUseClosingSubmenuRow(releaseNotesItem, @"doc.text", @"doc");
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
    HoverClickUseClosingSubmenuRow(uninstallItem, @"trash", @"xmark.circle");
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

    self.diagnosticsCopyItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Copy Summary")
                                                         action:@selector(copyDiagnosticsSummary:)
                                                  keyEquivalent:@""];
    self.diagnosticsCopyItem.target = self;
    self.diagnosticsCopyItem.enabled = YES;
    self.diagnosticsCopyItem.indentationLevel = 0;
    self.diagnosticsCopyItem.state = NSControlStateValueOff;
    self.diagnosticsCopyItem.toolTip = HoverClickCopyDiagnosticsSummaryHelp;
    HoverClickUseNonClosingSubmenuRow(self.diagnosticsCopyItem, @"doc.on.doc", @"doc.text", NO);
    [diagnosticsMenu addItem:self.diagnosticsCopyItem];

    self.verboseItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Verbose Mode")
                                                  action:@selector(toggleVerboseDiagnostics:)
                                           keyEquivalent:@""];
    self.verboseItem.target = self;
    self.verboseItem.enabled = YES;
    self.verboseItem.indentationLevel = 0;
    self.verboseItem.toolTip = HoverClickVerboseDiagnosticsHelp;
    HoverClickUseNonClosingSubmenuRow(self.verboseItem, @"list.bullet.rectangle", @"list.bullet", YES);
    [diagnosticsMenu addItem:self.verboseItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"About")
                                                       action:@selector(showAboutHoverClick:)
                                                keyEquivalent:@""];
    aboutItem.target = self;
    aboutItem.enabled = YES;
    aboutItem.indentationLevel = 0;
    aboutItem.state = NSControlStateValueOff;
    aboutItem.toolTip = HoverClickAboutHelp;
    HoverClickUseClosingPlainMenuRow(aboutItem, nil);
    [menu addItem:aboutItem];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:HoverClickMenuItemTitle(@"Quit")
                                                      action:@selector(quitApplication:)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    quitItem.enabled = YES;
    quitItem.indentationLevel = 0;
    quitItem.state = NSControlStateValueOff;
    quitItem.toolTip = HoverClickQuitHelp;
    HoverClickUseClosingPlainMenuRow(quitItem, @"\u2318Q");
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
    [self updateMenuTitles];
}

- (void)menuWillOpen:(NSMenu *)menu {
    if (menu != self.statusItem.menu) {
        return;
    }

    [self refreshAccessibilityStatusForReason:@"menu open"
                              promptIfMissing:NO
                             updateLastAction:NO];
}

- (void)printLaunchStatus {
    BOOL trusted = [self accessibilityTrusted];
    HoverClickLog("HoverClick: bundle id = %s", HoverClickBundleID.UTF8String);
    HoverClickLog("HoverClick: version = %s", HoverClickDisplayVersion().UTF8String);
    HoverClickLog("HoverClick: accessibility trusted = %s", trusted ? "YES" : "NO");
    HoverClickLog("HoverClick: launch state leftClickFocus=%s rightClickFocus=%s automaticUpdateChecks=%s automaticDownloadInstall=%s rightClickDefaultsKey=%s",
                  _clickToFocusEnabled ? "ON" : "OFF",
                  _rightClickFocusEnabled ? "ON" : "OFF",
                  self.updaterController.updater.automaticallyChecksForUpdates ? "ON" : "OFF",
                  self.updaterController.updater.automaticallyDownloadsUpdates ? "ON" : "OFF",
                  HoverClickRightClickFocusDefaultsKey.UTF8String);
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

    HoverClickLog("HoverClick: accessibility trusted = %s reason=%s", trusted ? "YES" : "NO", safeReason.UTF8String);

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
    HoverClickLog("HoverClick: Accessibility trust prompt requested result=%s", trusted ? "trusted" : "not trusted");
    return trusted;
}

- (void)showAccessibilityOnboardingIfNeeded {
    if ([self accessibilityTrusted]) {
        [self dismissAccessibilityOnboardingAlertIfNeeded];
        return;
    }

    if (_accessibilityOnboardingShownThisLaunch) {
        if (self.accessibilityOnboardingAlert != nil) {
            [self.accessibilityOnboardingAlert.window makeKeyAndOrderFront:nil];
        }
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
    if (self.accessibilityOnboardingAlert != nil) {
        [self.accessibilityOnboardingAlert.window makeKeyAndOrderFront:nil];
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"HoverClick Needs Accessibility Permission";
    alert.informativeText = @"HoverClick needs Accessibility permission to focus background windows before your original click is delivered. Click focus controls stay disabled until permission is granted.\n\nUse Permissions > Accessibility Settings if macOS does not show the permission prompt, then choose Refresh Status after enabling HoverClick.";
    alert.alertStyle = NSAlertStyleInformational;
    NSButton *okButton = [alert addButtonWithTitle:@"OK"];
    okButton.target = self;
    okButton.action = @selector(dismissAccessibilityOnboardingAlert:);
    self.accessibilityOnboardingAlert = alert;
    alert.window.delegate = self;
    [alert.window setReleasedWhenClosed:NO];
    [alert.window makeKeyAndOrderFront:nil];
    HoverClickLog("HoverClick: Accessibility onboarding shown while permission is missing");
    [self updateMenuTitles];
}

- (void)refreshAccessibilityStatus:(id)sender {
    BOOL userInitiated = (sender != nil);
    [self refreshAccessibilityStatusForReason:userInitiated ? @"manual refresh" : @"refresh"
                              promptIfMissing:userInitiated
                             updateLastAction:userInitiated];
    if (userInitiated) {
        _showRefreshStatusFeedback = YES;
        self.permissionRefreshItem.title = HoverClickMenuItemTitle(@"Refreshed");
        HoverClickSyncMenuRowView(self.permissionRefreshItem);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            _showRefreshStatusFeedback = NO;
            self.permissionRefreshItem.title = HoverClickMenuItemTitle(@"Refresh Status");
            HoverClickSyncMenuRowView(self.permissionRefreshItem);
        });
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
    _lastEventTapCallbackTime = now;
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
    [self recordPermissionCheckResult:@"missing (event tap callback)"];

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

        [self removeEventTapDueToMissingAccessibilityWithReason:@"event tap callback"];
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
                HoverClickLog("HoverClick: existing event tap installed but disabled; enabling");
                CGEventTapEnable(_eventTap, true);
                [self updateEventTapLifecycleFlags];
                HoverClickLog("HoverClick: existing event tap enable result=%s", _eventTapEnabled ? "enabled" : "disabled");
            }

            if (_eventTapEnabled) {
                HoverClickLog("HoverClick: event tap already installed; skipping duplicate install");
                [self updateMenuTitles];
                return YES;
            }

            HoverClickLog("HoverClick: existing event tap could not be enabled; recreating");
        } else {
            HoverClickLog("HoverClick: existing event tap objects are missing or invalid; recreating");
        }

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
        _eventTapEnabled = NO;
        HoverClickLog("HoverClick: failed to create event tap. Check Accessibility permission.");
        [self setLastClickResult:@"Event Tap Create Failed"];
        [self updateMenuTitles];
        return NO;
    }
    HoverClickLog("HoverClick: event tap created");

    _eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    if (_eventTapSource == NULL) {
        CFRelease(_eventTap);
        _eventTap = NULL;
        _eventTapInstalled = NO;
        _eventTapEnabled = NO;
        HoverClickLog("HoverClick: failed to create event tap source.");
        [self setLastClickResult:@"Event Tap Source Failed"];
        [self updateMenuTitles];
        return NO;
    }

    CFRunLoopAddSource(CFRunLoopGetCurrent(), _eventTapSource, kCFRunLoopCommonModes);
    _eventTapInstalled = YES;
    CGEventTapEnable(_eventTap, true);
    [self updateEventTapLifecycleFlags];
    HoverClickLog("HoverClick: event tap enable after install result=%s", _eventTapEnabled ? "enabled" : "disabled");

    if (!_eventTapEnabled) {
        [self setLastClickResult:@"Event Tap Enable Failed"];
        [self updateMenuTitles];
        return NO;
    }

    HoverClickLog("HoverClick: event tap installed mode=pass-through-default");
    [self updateMenuTitles];
    return YES;
}

- (void)removeEventTap {
    if (_eventTap == NULL && _eventTapSource == NULL && !_eventTapInstalled && !_eventTapEnabled) {
        HoverClickLog("HoverClick: event tap remove requested but no active tap");
        [self updateMenuTitles];
        return;
    }

    if (_eventTap != NULL) {
        if (CFMachPortIsValid(_eventTap)) {
            CGEventTapEnable(_eventTap, false);
            HoverClickLog("HoverClick: event tap disabled");
        } else {
            HoverClickLog("HoverClick: event tap disable skipped because port is invalid");
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
        HoverClickLog("HoverClick: event tap removed");
    }

    _eventTapInstalled = NO;
    _eventTapEnabled = NO;
    [self updateMenuTitles];
}

- (void)handleEventTapDisabledWithReason:(NSString *)reason shouldReenable:(BOOL)shouldReenable {
    _lastEventTapRecoveryAttemptTime = CFAbsoluteTimeGetCurrent();
    _eventTapEnabled = NO;
    [self updateEventTapLifecycleFlags];
    [self updateMenuTitles];

    if (!_userWantsEventTap) {
        _lastEventTapRecoveryResult = [NSString stringWithFormat:@"not re-enabled after %@: user disabled tap", reason];
        HoverClickLog("HoverClick: event tap disabled by %s; user disabled tap, not re-enabling", reason.UTF8String);
        return;
    }

    if (![self accessibilityTrusted]) {
        _lastEventTapRecoveryResult = [NSString stringWithFormat:@"not re-enabled after %@: Accessibility permission missing", reason];
        [self removeEventTapDueToMissingAccessibilityWithReason:[NSString stringWithFormat:@"tap disabled by %@", reason]];
        return;
    }

    if (!shouldReenable) {
        _lastEventTapRecoveryResult = [NSString stringWithFormat:@"not re-enabled after %@: recovery disabled", reason];
        HoverClickLog("HoverClick: event tap disabled by %s; not re-enabling", reason.UTF8String);
        return;
    }

    if ([self isEventTapPortValid] && [self isEventTapSourceValid]) {
        HoverClickLog("HoverClick: attempting event tap re-enable after %s", reason.UTF8String);
        CGEventTapEnable(_eventTap, true);
        [self updateEventTapLifecycleFlags];
        if (_eventTapEnabled) {
            _lastEventTapRecoveryResult = [NSString stringWithFormat:@"re-enabled existing tap after %@", reason];
            HoverClickLog("HoverClick: event tap re-enabled after %s", reason.UTF8String);
            [self updateMenuTitles];
            return;
        }

        HoverClickLog("HoverClick: event tap re-enable after %s failed; recreating", reason.UTF8String);
    } else {
        HoverClickLog("HoverClick: event tap disabled by %s with invalid or missing port/source; recreating", reason.UTF8String);
    }

    [self removeEventTap];
    BOOL recovered = [self installEventTap];
    _lastEventTapRecoveryResult = recovered ?
        [NSString stringWithFormat:@"recreated tap after %@", reason] :
        [NSString stringWithFormat:@"recreate failed after %@", reason];
    HoverClickLog("HoverClick: event tap recovery after %s result=%s",
                  reason.UTF8String,
                  recovered ? "recreated" : "failed");
    [self updateMenuTitles];
}

- (void)toggleEventTap:(id)sender {
    (void)sender;

    [self updateEventTapLifecycleFlags];

    if (_userWantsEventTap && (_eventTapInstalled || _eventTap != NULL || _eventTapSource != NULL)) {
        _userWantsEventTap = NO;
        [self removeEventTap];
        [self setLastClickResult:@"Event Tap Disabled"];
        return;
    }

    _userWantsEventTap = YES;
    if (![self accessibilityTrusted]) {
        HoverClickLog("HoverClick: event tap permission missing. Check Accessibility permission.");
        [self removeEventTapDueToMissingAccessibilityWithReason:@"toggle"];
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
        self.diagnosticsCopyItem.title = HoverClickMenuItemTitle(@"Copied");
        HoverClickSyncMenuRowView(self.diagnosticsCopyItem);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            self.diagnosticsCopyItem.title = HoverClickMenuItemTitle(@"Copy Summary");
            HoverClickSyncMenuRowView(self.diagnosticsCopyItem);
        });
    }
}

- (void)showAboutHoverClick:(id)sender {
    (void)sender;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"HoverClick";
    alert.informativeText = [NSString stringWithFormat:
                             @"Version %@\n"
                              "Build %@\n"
                              "Bundle ID: %@\n\n"
                              "Windows-like click focus for macOS.",
                             HoverClickDisplayVersion(),
                             HoverClickBuildVersion(),
                             HoverClickBundleIdentifier()];
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
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

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Uninstall HoverClick";
    alert.informativeText = @"To uninstall HoverClick, turn off Launch at Login, quit HoverClick, then move HoverClick.app to the Trash.";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
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
}

- (void)setLastClickResult:(NSString *)result {
    _lastClickResult = result ?: @"None";
    if ([self shouldPreserveAsLastNonMenuClickResult:_lastClickResult]) {
        _lastNonMenuClickResult = _lastClickResult;
    }
    [self updateMenuTitles];
}

- (BOOL)shouldPreserveAsLastNonMenuClickResult:(NSString *)result {
    if (result.length == 0 || [result isEqualToString:@"None"]) {
        return NO;
    }

    NSSet<NSString *> *volatileMenuOrSetupResults = [NSSet setWithArray:@[
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
        @"Automatic Update Checks Enabled",
        @"Automatic Update Checks Disabled"
    ]];

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

- (BOOL)isChromeApplication:(NSRunningApplication *)app {
    return [app.bundleIdentifier isEqualToString:HoverClickChromeBundleID];
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
    [self beginRecentDecisionWithTrigger:"click" sequenceID:clickID rawPoint:rawPoint axPoint:axPoint];
    [self diagnosticLog:"HoverClick: click #%llu received leftClickFocus=%s raw=(%.1f,%.1f) converted=(%.1f,%.1f)",
                        clickID,
                        _clickToFocusEnabled ? "ON" : "OFF",
                        rawPoint.x,
                        rawPoint.y,
                        axPoint.x,
                        axPoint.y];

    if (!_clickToFocusEnabled) {
        HoverClickLog("HoverClick: click #%llu left click focus disabled; event passed through", clickID);
        [self recordFocusDecisionWithTrigger:"click"
                                  sequenceID:clickID
                                    decision:@"skipped"
                                      detail:@"Left Click Focus disabled; original event passed through unchanged"];
        [self recordClickThroughInvestigationForSequenceID:clickID
                                               focusStatus:@"skipped before target detection: Left Click Focus disabled"
                                                 finalNote:@"original left mouse-down returned unchanged; swallowed=no"];
        [self includeRecentDecisionInHistoryForSequenceID:clickID];
        [self completeRecentDecisionForSequenceID:clickID
                                      finalResult:@"skipped: Left Click Focus disabled"
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"Disabled"];
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
        [self recordFocusDecisionWithTrigger:"click"
                                  sequenceID:clickID
                                    decision:@"skipped"
                                      detail:@"AX element not found; original event passed through unchanged"];
        [self recordClickThroughInvestigationForSequenceID:clickID
                                               focusStatus:@"target detection failed: AX element not found"
                                                 finalNote:@"original left mouse-down returned unchanged; swallowed=no"];
        [self includeRecentDecisionInHistoryForSequenceID:clickID];
        [self completeRecentDecisionForSequenceID:clickID
                                      finalResult:@"skipped: AX element not found"
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"No AX Element"];
        return;
    }

    [self handleResolvedElement:element rawPoint:rawPoint axPoint:axPoint clickID:clickID topmostWindowInfo:topmostWindowInfo];
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
    [self beginRecentDecisionWithTrigger:"right-click" sequenceID:clickID rawPoint:rawPoint axPoint:axPoint];
    [self diagnosticLog:"HoverClick: right-click #%llu received rightClickFocus=%s leftClickFocus=%s raw=(%.1f,%.1f) converted=(%.1f,%.1f)",
                        clickID,
                        _rightClickFocusEnabled ? "ON" : "OFF",
                        _clickToFocusEnabled ? "ON" : "OFF",
                        rawPoint.x,
                        rawPoint.y,
                        axPoint.x,
                        axPoint.y];

    if (!_rightClickFocusEnabled) {
        HoverClickLog("HoverClick: right-click #%llu right click focus disabled; event passed through", clickID);
        [self recordFocusDecisionWithTrigger:"right-click"
                                  sequenceID:clickID
                                    decision:@"skipped"
                                      detail:@"Right Click Focus disabled; right mouse down observed and original event passed through unchanged"];
        [self recordClickThroughInvestigationForSequenceID:clickID
                                               focusStatus:@"skipped before target detection: Right Click Focus disabled"
                                                 finalNote:@"original right mouse-down returned unchanged; swallowed=no"];
        [self includeRecentDecisionInHistoryForSequenceID:clickID];
        [self completeRecentDecisionForSequenceID:clickID
                                      finalResult:@"skipped: Right Click Focus disabled"
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"Right Click Disabled"];
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
        [self recordFocusDecisionWithTrigger:"right-click"
                                  sequenceID:clickID
                                    decision:@"skipped"
                                      detail:@"AX element not found; original event passed through unchanged"];
        [self recordClickThroughInvestigationForSequenceID:clickID
                                               focusStatus:@"target detection failed: AX element not found"
                                                 finalNote:@"original right mouse-down returned unchanged; swallowed=no"];
        [self includeRecentDecisionInHistoryForSequenceID:clickID];
        [self completeRecentDecisionForSequenceID:clickID
                                      finalResult:@"skipped: AX element not found"
                 keepActiveForDelayedVerification:NO];
        [self setLastClickResult:@"No AX Element"];
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
    [self updateRecentDecisionForSequenceID:sequenceID key:@"targetAlreadyFrontmost" value:targetIsFrontmost ? @"yes" : @"no"];
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

- (void)logTopmostWindowInfo:(NSDictionary *)windowInfo atPoint:(CGPoint)point sequenceID:(uint64_t)sequenceID trigger:(const char *)trigger {
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
        [self diagnosticLog:"HoverClick: %s #%llu topmost CG window normal %@", trigger, sequenceID, [self compactWindowInfoDescription:windowInfo]];
    } else {
        [self diagnosticLog:"HoverClick: %s #%llu topmost CG window non-normal %@", trigger, sequenceID, [self compactWindowInfoDescription:windowInfo]];
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
    _lastSuccessfulFocusTime = focusTime;
    _lastSuccessfulFocusDescription = successDescription;
    _totalSuccessfulFocusVerifications++;
    if ([triggerLabel isEqualToString:@"right"]) {
        _lastRightClickFocusPid = targetPid;
        _lastRightClickFocusTime = focusTime;
    }
}

- (void)completeDelayedBackgroundFocusVerification:(NSDictionary *)context {
    NSNumber *sequenceNumber = context[@"sequenceID"];
    NSNumber *targetPidNumber = context[@"targetPid"];
    NSNumber *delayNumber = context[@"delay"];
    NSString *appName = context[@"appName"] ?: @"unknown";
    NSString *triggerLabel = context[@"triggerLabel"] ?: @"unknown";
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
    BOOL verified = (frontDelayed != nil && frontDelayed.processIdentifier == targetPid);
    NSString *frontDelayedDescription = HoverClickRunningApplicationDescription(frontDelayed);
    _lastBackgroundFocusDelayedVerification = [NSString stringWithFormat:@"%@ after %.2fs frontmost=%@",
                                               verified ? @"passed" : @"failed",
                                               delay,
                                               frontDelayedDescription];
    [self updateRecentDecisionForSequenceID:sequenceID key:@"delayedVerification" value:_lastBackgroundFocusDelayedVerification];

    HoverClickLog("HoverClick: %s #%llu delayed verify after %.2fs frontApp=%s current=%s",
                  triggerLabel.UTF8String,
                  sequenceID,
                  delay,
                  verified ? "YES" : "NO",
                  frontDelayedDescription.UTF8String);

    NSString *failureReason = verified ?
        @"none" :
        [NSString stringWithFormat:@"frontmost after delayed check was %@", frontDelayedDescription];
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

    if (verified) {
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
    NSString *frontBeforeDescription = HoverClickRunningApplicationDescription(frontBefore);

    [self recordBackgroundFocusAttemptWithTrigger:trigger
                                      sequenceID:sequenceID
                                         appName:appName
                                             pid:targetPid
                                 frontmostBefore:frontBeforeDescription];

    if (frontBeforePid == targetPid) {
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

    BOOL activateAttempted = targetApp != nil;
    BOOL activateResult = NO;
    if (targetApp != nil) {
        activateResult = [targetApp activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    }
    _lastBackgroundFocusActivation = [NSString stringWithFormat:@"attempted=%@ returnValue=%@",
                                      activateAttempted ? @"yes" : @"no",
                                      activateAttempted ? (activateResult ? @"yes" : @"no") : @"not-applicable"];
    [self updateRecentDecisionForSequenceID:sequenceID
                                        key:@"finalResult"
                                      value:[NSString stringWithFormat:@"focus attempt started; activation %@",
                                             _lastBackgroundFocusActivation]];
    HoverClickLog("HoverClick: %s #%llu app activation attempted=%s result=%s",
                  trigger,
                  sequenceID,
                  activateAttempted ? "YES" : "NO",
                  activateResult ? "YES" : "NO");

    AXUIElementRef appElement = AXUIElementCreateApplication(targetPid);
    BOOL appElementCreated = (appElement != NULL);
    BOOL frontmostAttempted = NO;
    BOOL focusedWindowAttempted = NO;
    AXError frontmostError = kAXErrorIllegalArgument;
    AXError focusedWindowError = kAXErrorIllegalArgument;
    AXError mainWindowError = kAXErrorIllegalArgument;
    AXError focusedAttrError = kAXErrorIllegalArgument;
    if (appElement != NULL) {
        frontmostAttempted = YES;
        frontmostError = AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute, kCFBooleanTrue);
        focusedWindowAttempted = YES;
        focusedWindowError = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute, targetWindow);
        CFRelease(appElement);
    }

    HoverClickLog("HoverClick: %s #%llu AX frontmost set %s", trigger, sequenceID, HoverClickAXErrorName(frontmostError));

    BOOL raiseAttempted = (targetWindow != NULL);
    AXError raiseError = AXUIElementPerformAction(targetWindow, kAXRaiseAction);
    HoverClickLog("HoverClick: %s #%llu AXRaise %s", trigger, sequenceID, HoverClickAXErrorName(raiseError));

    BOOL mainWindowAttempted = (targetWindow != NULL);
    BOOL focusedAttrAttempted = (targetWindow != NULL);
    mainWindowError = AXUIElementSetAttributeValue(targetWindow, kAXMainAttribute, kCFBooleanTrue);
    focusedAttrError = AXUIElementSetAttributeValue(targetWindow, kAXFocusedAttribute, kCFBooleanTrue);
    _lastBackgroundFocusAXOperations = [NSString stringWithFormat:@"appElement=%@ appFrontmost=%@ focusedWindow=%@ raise=%@ mainWindow=%@ focused=%@",
                                        appElementCreated ? @"yes" : @"no",
                                        HoverClickAXAttemptSummary(frontmostAttempted, frontmostError),
                                        HoverClickAXAttemptSummary(focusedWindowAttempted, focusedWindowError),
                                        HoverClickAXAttemptSummary(raiseAttempted, raiseError),
                                        HoverClickAXAttemptSummary(mainWindowAttempted, mainWindowError),
                                        HoverClickAXAttemptSummary(focusedAttrAttempted, focusedAttrError)];
    [self updateRecentDecisionForSequenceID:sequenceID key:@"axOperations" value:_lastBackgroundFocusAXOperations];
    [self recordClickThroughInvestigationForSequenceID:sequenceID
                                           focusStatus:@"AX operations attempted"
                                             finalNote:_lastBackgroundFocusAXOperations];

    HoverClickLog("HoverClick: %s #%llu AX focusedWindow set %s", trigger, sequenceID, HoverClickAXErrorName(focusedWindowError));
    [self diagnosticLog:"HoverClick: %s #%llu AX mainWindow set %s", trigger, sequenceID, HoverClickAXErrorName(mainWindowError)];
    [self diagnosticLog:"HoverClick: %s #%llu AX focused attribute set %s", trigger, sequenceID, HoverClickAXErrorName(focusedAttrError)];

    NSRunningApplication *frontAfter = [NSWorkspace sharedWorkspace].frontmostApplication;
    BOOL frontImmediate = (frontAfter != nil && frontAfter.processIdentifier == targetPid);
    NSString *frontAfterDescription = HoverClickRunningApplicationDescription(frontAfter);
    _lastBackgroundFocusImmediateFrontmost = HoverClickFrontmostVerificationDescription(frontAfter, targetPid);
    [self updateRecentDecisionForSequenceID:sequenceID key:@"immediateVerification" value:_lastBackgroundFocusImmediateFrontmost];
    HoverClickLog("HoverClick: %s #%llu %s-to-focus immediate verify frontApp=%s current=%s",
                  trigger,
                  sequenceID,
                  trigger,
                  frontImmediate ? "YES" : "NO",
                  frontAfterDescription.UTF8String);

    NSString *triggerLabel = HoverClickFocusTriggerLabel(trigger);
    if (frontImmediate) {
        _lastBackgroundFocusDelayedVerification = @"not scheduled (immediate verification passed)";
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
                 keepActiveForDelayedVerification:NO];
    } else {
        NSString *verificationFailureReason = [NSString stringWithFormat:@"frontmost after immediate check was %@", frontAfterDescription];
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

        NSDictionary *verificationContext = @{
            @"sequenceID": @(sequenceID),
            @"targetPid": @(targetPid),
            @"appName": appName ?: @"unknown",
            @"triggerLabel": triggerLabel ?: @"unknown",
            @"delay": @(HoverClickDelayedVerificationDelay)
        };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(HoverClickDelayedVerificationDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self completeDelayedBackgroundFocusVerification:verificationContext];
        });
    }
    HoverClickLog("HoverClick: %s #%llu event passed through", trigger, sequenceID);
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
