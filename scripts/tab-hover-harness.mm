// End-to-end check of Background Tab Hover. scripts/tab-hover-harness.sh cuts the feature's block
// out of HoverClick.mm (tab-hover-slice.inc) and swaps two inputs for the harness's own: the
// pointer position and the frontmost application. Everything else is the shipped code: the
// window list, the gate, the Accessibility reads and the card. The harness rests its pointer
// position on real tabs of a running Chromium-family browser and checks that the card shows the
// title of that tab, follows to the next tab and hides over the page. Read-only: it moves no
// cursor, posts no event and focuses nothing. It prints frames, counts and lengths, never a title.
// A card appears on screen for a few seconds while it runs.
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <time.h>
#include <stdarg.h>

static inline NSTimeInterval HoverClickMonotonicSeconds(void) {
    return (NSTimeInterval)clock_gettime_nsec_np(CLOCK_UPTIME_RAW) / 1e9;
}
static NSString *HoverClickSafePrefix(NSString *value, NSUInteger cutIndex) {
    if (cutIndex >= value.length) return value;
    NSUInteger end = [value rangeOfComposedCharacterSequenceAtIndex:cutIndex].location;
    return [value substringToIndex:end];
}
static void HoverClickLog(const char *format, ...) __attribute__((format(printf, 1, 2)));
static void HoverClickLog(const char *format, ...) {
    va_list args; va_start(args, format); printf("  [log] "); vprintf(format, args); printf("\n"); va_end(args);
}

@class HoverClickBackgroundTabHover;
@interface HoverClickAppDelegate : NSObject
- (void)diagnosticLog:(const char *)format, ... __attribute__((format(printf, 1, 2)));
- (NSArray<NSString *> *)userExcludedBundleIDs;
@end

static NSPoint gFakeMouse;
static pid_t gFakeFront;
static NSPoint HarnessMouseLocation(void) { return gFakeMouse; }
static pid_t HarnessFrontmostPid(void) { return gFakeFront; }

#include "tab-hover-slice.inc"

@implementation HoverClickAppDelegate
- (void)diagnosticLog:(const char *)format, ... {
    va_list args; va_start(args, format); printf("  [diag] "); vprintf(format, args); printf("\n"); va_end(args);
}
- (NSArray<NSString *> *)userExcludedBundleIDs { return @[]; }
@end

// ---- harness helpers (plain AX, independent of the code under test) ----
static NSString *HStr(AXUIElementRef el, CFStringRef attr) {
    CFTypeRef v = NULL;
    if (AXUIElementCopyAttributeValue(el, attr, &v) != kAXErrorSuccess || !v) return nil;
    NSString *s = nil;
    if (CFGetTypeID(v) == CFStringGetTypeID()) s = [(__bridge NSString *)v copy];
    CFRelease(v);
    return s;
}
static BOOL HFrame(AXUIElementRef el, CGRect *out) {
    CFTypeRef p = NULL, s = NULL;
    if (AXUIElementCopyAttributeValue(el, kAXPositionAttribute, &p) != kAXErrorSuccess || !p) return NO;
    if (AXUIElementCopyAttributeValue(el, kAXSizeAttribute, &s) != kAXErrorSuccess || !s) { CFRelease(p); return NO; }
    BOOL ok = HoverClickTabHoverRectValue(p, s, out);
    CFRelease(p); CFRelease(s);
    return ok;
}
static NSArray *HChildren(AXUIElementRef el) {
    CFTypeRef v = NULL;
    if (AXUIElementCopyAttributeValue(el, kAXChildrenAttribute, &v) != kAXErrorSuccess || !v) return @[];
    if (CFGetTypeID(v) != CFArrayGetTypeID()) { CFRelease(v); return @[]; }
    return CFBridgingRelease(v);
}
static AXUIElementRef HParent(AXUIElementRef el) {
    CFTypeRef v = NULL;
    if (AXUIElementCopyAttributeValue(el, kAXParentAttribute, &v) != kAXErrorSuccess || !v) return NULL;
    return (AXUIElementRef)v;
}
static BOOL HPointInsideAncestors(AXUIElementRef tab, CGPoint point) {
    AXUIElementRef cur = HParent(tab);
    while (cur) {
        if ([HStr(cur, kAXRoleAttribute) isEqualToString:@"AXWindow"]) { CFRelease(cur); return YES; }
        CGRect f; if (HFrame(cur, &f) && !CGRectContainsPoint(CGRectInset(f, -0.5, -0.5), point)) { CFRelease(cur); return NO; }
        AXUIElementRef p = HParent(cur); CFRelease(cur); cur = p;
    }
    return YES;
}
static void Spin(NSTimeInterval seconds) {
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}
static NSPoint CocoaFromQuartz(CGPoint p) {
    return NSMakePoint(p.x, NSMaxY(NSScreen.screens.firstObject.frame) - p.y);
}
static NSString *TopWindowAt(CGPoint p) {
    NSArray *list = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
    for (NSDictionary *w in list) {
        CGRect b; if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)w[(id)kCGWindowBounds], &b) || !CGRectContainsPoint(b, p)) continue;
        return [NSString stringWithFormat:@"%@ layer=%@", w[(id)kCGWindowOwnerName], w[(id)kCGWindowLayer]];
    }
    return @"none";
}

static int gPass = 0, gFail = 0;
static int gSiteTabs = 0, gSiteExpected = 0, gSiteShown = 0;
static void Expect(BOOL ok, NSString *what) {
    if (ok) gPass++; else gFail++;
    printf("    %s %s\n", ok ? "OK  " : "FAIL", what.UTF8String);
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        NSString *shotDir = argc > 1 ? @(argv[1]) : nil;
        NSApplication *app = [NSApplication sharedApplication];
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        AXUIElementRef sys = AXUIElementCreateSystemWide();
        AXUIElementSetMessagingTimeout(sys, 0.2f);
        printf("AX trusted=%d\n", AXIsProcessTrusted());

        NSRunningApplication *realFront = NSWorkspace.sharedWorkspace.frontmostApplication;
        NSRunningApplication *chrome = nil;
        for (NSRunningApplication *candidate in NSWorkspace.sharedWorkspace.runningApplications) {
            if (HoverClickTabHoverIsSupportedBrowser(candidate.bundleIdentifier)) { chrome = candidate; break; }
        }
        if (!chrome) { printf("no supported browser is running\n"); return 1; }
        printf("browser under test=%s\n", chrome.bundleIdentifier.UTF8String);
        BOOL chromeFront = realFront.processIdentifier == chrome.processIdentifier;
        NSRunningApplication *finder = [[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.finder"] firstObject];
        gFakeFront = chromeFront ? finder.processIdentifier : realFront.processIdentifier;
        printf("real frontmost=%s; frontmost used by the code=%s\n", realFront.bundleIdentifier.UTF8String,
               chromeFront ? "com.apple.finder (stand-in, the browser is really in front)" : realFront.bundleIdentifier.UTF8String);

        // Targets: tabs the pointer can really reach (system-wide hit test lands in their window).
        AXUIElementRef chromeApp = AXUIElementCreateApplication(chrome.processIdentifier);
        AXUIElementSetMessagingTimeout(chromeApp, 0.5f);
        CFTypeRef wins = NULL;
        AXUIElementCopyAttributeValue(chromeApp, kAXWindowsAttribute, &wins);
        NSArray *windows = wins ? CFBridgingRelease(wins) : @[];
        NSMutableArray *targets = [NSMutableArray array];   // @[tab, windowFrameValue]
        for (id w in windows) {
            AXUIElementRef win = (__bridge AXUIElementRef)w;
            CGRect wf = CGRectZero; if (!HFrame(win, &wf) || wf.size.width < 400) continue;
            NSMutableArray *queue = [NSMutableArray arrayWithObject:w];
            NSMutableArray *reachable = [NSMutableArray array]; int visited = 0;
            while (queue.count && visited < 6000) {
                id cur = queue.firstObject; [queue removeObjectAtIndex:0]; visited++;
                AXUIElementRef el = (__bridge AXUIElementRef)cur;
                if ([HStr(el, kAXSubroleAttribute) isEqualToString:@"AXTabButton"]) {
                    CGRect tf; if (!HFrame(el, &tf)) continue;
                    CGPoint c = CGPointMake(CGRectGetMidX(tf), CGRectGetMidY(tf));
                    if (!HPointInsideAncestors(el, c)) continue;
                    AXUIElementRef h = NULL; AXUIElementCopyElementAtPosition(sys, (float)c.x, (float)c.y, &h);
                    BOOL inWindow = NO;
                    if (h) { CFTypeRef hw = NULL; if (AXUIElementCopyAttributeValue(h, kAXWindowAttribute, &hw) == kAXErrorSuccess && hw) { inWindow = CFEqual(hw, win); CFRelease(hw); } CFRelease(h); }
                    if (inWindow) [reachable addObject:cur];
                    continue;
                }
                if ([HStr(el, kAXRoleAttribute) isEqualToString:@"AXWebArea"]) continue;
                [queue addObjectsFromArray:HChildren(el)];
            }
            printf("browser window frame=%s reachable tabs=%lu\n", NSStringFromRect(NSRectFromCGRect(wf)).UTF8String, (unsigned long)reachable.count);
            if (reachable.count >= 3) {
                [targets addObject:@[reachable[0], reachable[reachable.count / 2], reachable.lastObject, [NSValue valueWithRect:NSRectFromCGRect(wf)]]];
            }
        }
        if (targets.count == 0) { printf("no browser window shows three reachable tabs: nothing to test\n"); return 2; }

        HoverClickAppDelegate *host = [[HoverClickAppDelegate alloc] init];
        HoverClickBackgroundTabHover *hover = [[HoverClickBackgroundTabHover alloc] init];
        hover.host = host;
        gFakeMouse = NSMakePoint(-5000, -5000);
        [hover startWithReason:@"harness"];
        Spin(0.3);
        printf("timer running=%d\n", [hover valueForKey:@"timer"] != nil);

        int windowIndex = 0;
        for (NSArray *t in targets) {
            CGRect wf = NSRectToCGRect([t[3] rectValue]);
            printf("\n== window %d frame=%s ==\n", windowIndex, NSStringFromRect(NSRectFromCGRect(wf)).UTF8String);
            for (int i = 0; i < 3; i++) {
                AXUIElementRef tab = (__bridge AXUIElementRef)t[(NSUInteger)i];
                CGRect tf; HFrame(tab, &tf);
                CGPoint c = CGPointMake(CGRectGetMidX(tf), CGRectGetMidY(tf));
                NSString *expected = HStr(tab, kAXTitleAttribute) ?: HStr(tab, kAXDescriptionAttribute);
                printf("  tab %d frame=%s; top window in the list there: %s\n", i, NSStringFromRect(NSRectFromCGRect(tf)).UTF8String, TopWindowAt(c).UTF8String);
                uint64_t cardsBefore = hover.cardsShown;
                gFakeMouse = CocoaFromQuartz(c);
                Spin(i == 0 ? 1.2 : 0.7);
                BOOL visible = [[hover valueForKey:@"cardVisible"] boolValue];
                NSPanel *panel = [hover valueForKey:@"panel"];
                CGRect cardTab = NSRectToCGRect([[hover valueForKey:@"cardTabRect"] rectValue]);
                Expect(visible && panel.isVisible, [NSString stringWithFormat:@"card visible (cardVisible=%d panel.isVisible=%d alpha=%.2f)", visible, panel.isVisible, panel.alphaValue]);
                Expect(visible && CGRectEqualToRect(cardTab, tf), @"card belongs to the tab under the pointer");
                NSString *shown = [[hover valueForKey:@"cardView"] valueForKey:@"title"] ?: @"";
                NSString *trimmed = [expected stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                Expect(visible && shown.length > 0 && [shown isEqualToString:HoverClickTabHoverNormalizedTitle(trimmed)],
                       [NSString stringWithFormat:@"card text equals the tab's title (length %lu)", (unsigned long)shown.length]);
                if (visible) {
                    // The site line: what the card shows against a fresh answer from the browser.
                    pid_t tabPid = 0; AXUIElementGetPid(tab, &tabPid);
                    OSStatus siteStatus = noErr;
                    NSDictionary *hosts = HoverClickTabHoverCopyHostsByTitle(tabPid, &siteStatus);
                    NSString *wantSite = HoverClickTabHoverHostForTitle(hosts, shown);
                    NSString *shownSite = [[hover valueForKey:@"cardView"] valueForKey:@"detail"];
                    gSiteTabs++; if (wantSite.length > 0) gSiteExpected++; if (shownSite.length > 0) gSiteShown++;
                    Expect(wantSite == shownSite || [wantSite isEqualToString:shownSite],
                           [NSString stringWithFormat:@"site line equals the browser's answer for this title (browser status %d, expected length %lu, shown length %lu)",
                            (int)siteStatus, (unsigned long)wantSite.length, (unsigned long)shownSite.length]);
                    CGFloat wantHeight = HoverClickTabHoverCardHeight(HoverClickTabHoverCardTitleLines(shown).count, shownSite.length > 0);
                    Expect([[hover valueForKey:@"cardFrame"] rectValue].size.height == wantHeight, @"card height fits its lines");
                }
                if (visible) {
                    NSRect pf = [[hover valueForKey:@"cardFrame"] rectValue]; NSRect tabCocoa = HoverClickTabHoverCocoaRectFromQuartz(tf, NSMaxY(NSScreen.screens.firstObject.frame));
                    BOOL onAScreen = NO; for (NSScreen *s in NSScreen.screens) if (NSContainsRect(s.frame, pf)) onAScreen = YES;
                    printf("    card frame (cocoa)=%s, left edge %.0f pt from the tab's right edge, top %.0f pt above the tab's, cards shown +%llu\n",
                           NSStringFromRect(pf).UTF8String, NSMinX(pf) - NSMaxX(tabCocoa), NSMaxY(pf) - NSMaxY(tabCocoa), hover.cardsShown - cardsBefore);
                    Expect(onAScreen && !NSIntersectsRect(pf, tabCocoa) && NSMinX(pf) == NSMaxX(tabCocoa) && NSMaxY(pf) - NSMaxY(tabCocoa) == 1.0,
                           @"card sits where Chrome puts its own: against the tab's right edge, top 1 pt above the tab's, fully on a screen");
                    NSArray *list = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID));
                    BOOL listed = NO; for (NSDictionary *w in list) if ([w[(id)kCGWindowNumber] integerValue] == panel.windowNumber) listed = YES;
                    Expect(listed, @"card window is in the on-screen window list");
                    if (shotDir && i == 0) {
                        Spin(0.25);
                        CGFloat primaryMaxY = NSMaxY(NSScreen.screens.firstObject.frame);
                        CGRect region = CGRectMake(tf.origin.x - 12, primaryMaxY - NSMaxY(pf) - 40, NSMaxX(pf) - tf.origin.x + 60, pf.size.height + 90);
                        NSTask *task = [[NSTask alloc] init];
                        task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/screencapture"];
                        task.arguments = @[@"-x", @"-R", [NSString stringWithFormat:@"%.0f,%.0f,%.0f,%.0f", region.origin.x, region.origin.y, region.size.width, region.size.height],
                                           [shotDir stringByAppendingFormat:@"/card-window%d.png", windowIndex]];
                        [task launchAndReturnError:nil]; [task waitUntilExit];
                    }
                }
            }
            // Off the strip, onto the page: the card must go away.
            gFakeMouse = CocoaFromQuartz(CGPointMake(CGRectGetMinX(wf) + 400, CGRectGetMinY(wf) + 500));
            Spin(1.0);
            Expect(![[hover valueForKey:@"cardVisible"] boolValue], @"card hidden after the pointer moved onto the page");
            windowIndex++;
        }
        // ---- any other application: the named element under the pointer ----
        // Skipped for an older HoverClick.mm (--source) that has no element read.
        if ([HoverClickTabHoverHit instancesRespondToSelector:NSSelectorFromString(@"element")]) {
            printf("\n== named elements of other applications ==\n");
            NSArray *list = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
            NSMutableDictionary<NSNumber *, NSNumber *> *perApp = [NSMutableDictionary dictionary];
            NSMutableDictionary *entries = [NSMutableDictionary dictionary];
            int elementCards = 0, sampled = 0;
            for (NSDictionary *w in list) {
                if ([w[(id)kCGWindowLayer] integerValue] != 0 || elementCards >= 9) continue;
                pid_t wpid = [w[(id)kCGWindowOwnerPID] intValue];
                NSRunningApplication *owner = [NSRunningApplication runningApplicationWithProcessIdentifier:wpid];
                if (wpid == gFakeFront || wpid == getpid() || HoverClickTabHoverIsSupportedBrowser(owner.bundleIdentifier)) continue;
                CGRect b; if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)w[(id)kCGWindowBounds], &b) || b.size.width < 200 || b.size.height < 150) continue;
                NSMutableArray<NSValue *> *seen = [NSMutableArray array];
                for (CGFloat y = CGRectGetMinY(b) + 20; y < CGRectGetMaxY(b) && perApp[@(wpid)].intValue < 3; y += 44) {
                    for (CGFloat x = CGRectGetMinX(b) + 24; x < CGRectGetMaxX(b) && perApp[@(wpid)].intValue < 3 && sampled < 1500; x += 70) {
                        CGPoint c = CGPointMake(x, y);
                        sampled++;
                        HoverClickTabHoverHit *want = HoverClickTabHoverRunHitTest(c, gFakeFront, getpid(), kCGNullWindowID, [NSSet set], entries);
                        // want.pid is the owner of the topmost window there: a window lower in the list is covered.
                        if (want.pid != wpid || want.outcome != HoverClickTabHoverOutcomeTab || ![[want valueForKey:@"element"] boolValue]) continue;
                        NSValue *rectValue = [NSValue valueWithRect:NSRectFromCGRect(want.tabRect)];
                        if ([seen containsObject:rectValue]) continue;
                        [seen addObject:rectValue];
                        perApp[@(wpid)] = @(perApp[@(wpid)].intValue + 1);
                        elementCards++;

                        printf("  point=(%.0f,%.0f) shown-by-help=%d\n", c.x, c.y, want.detail.length > 0);
                        printf("  %s element frame=%s\n", owner.bundleIdentifier.UTF8String, NSStringFromRect(NSRectFromCGRect(want.tabRect)).UTF8String);
                        gFakeMouse = NSMakePoint(-5000, -5000);
                        Spin(0.9);
                        Expect(![[hover valueForKey:@"cardVisible"] boolValue], @"no card while the pointer is elsewhere");
                        gFakeMouse = CocoaFromQuartz(c);
                        Spin(1.2);
                        BOOL visible = [[hover valueForKey:@"cardVisible"] boolValue];
                        NSPanel *panel = [hover valueForKey:@"panel"];
                        CGRect cardTab = NSRectToCGRect([[hover valueForKey:@"cardTabRect"] rectValue]);
                        NSString *shown = [[hover valueForKey:@"cardView"] valueForKey:@"title"] ?: @"";
                        // Independent read, right after the card went up (live windows change): the element with
                        // the card's frame, up from the hit element.
                        NSString *independent = nil; NSString *role = nil;
                        AXUIElementRef h = NULL; AXUIElementCopyElementAtPosition(sys, (float)c.x, (float)c.y, &h);
                        for (int step = 0; h != NULL && step < 6; step++) {
                            CGRect f;
                            if (HFrame(h, &f) && CGRectEqualToRect(f, cardTab)) {
                                role = HStr(h, kAXRoleAttribute);
                                NSString *named = HStr(h, kAXTitleAttribute).length > 0 ? HStr(h, kAXTitleAttribute) : HStr(h, kAXDescriptionAttribute);
                                BOOL control = [@[@"AXButton", @"AXPopUpButton", @"AXMenuButton", @"AXCheckBox", @"AXRadioButton", @"AXDisclosureTriangle",
                                                  @"AXImage", @"AXSlider", @"AXIncrementor", @"AXColorWell", @"AXLink"] containsObject:role ?: @""];
                                independent = (control && named.length > 0) ? named : HStr(h, kAXHelpAttribute);
                                break;
                            }
                            AXUIElementRef p = HParent(h); CFRelease(h); h = p;
                        }
                        if (h) CFRelease(h);

                        printf("    role=%s\n", role.UTF8String ?: "?");
                        Expect(visible && panel.isVisible, @"card visible over the element");
                        Expect(visible && CGRectContainsPoint(CGRectInset(cardTab, -2.0, -2.0), c), @"card belongs to an element under the pointer");
                        Expect(visible && shown.length > 0 && [shown isEqualToString:HoverClickTabHoverNormalizedTitle(independent)],
                               [NSString stringWithFormat:@"card text equals the element's own name (length %lu)", (unsigned long)shown.length]);
                        if (visible) {
                            NSRect pf = [[hover valueForKey:@"cardFrame"] rectValue];
                            NSRect elementCocoa = HoverClickTabHoverCocoaRectFromQuartz(cardTab, NSMaxY(NSScreen.screens.firstObject.frame));
                            BOOL onAScreen = NO; for (NSScreen *s in NSScreen.screens) if (NSContainsRect(s.frame, pf)) onAScreen = YES;
                            Expect(onAScreen && !NSIntersectsRect(pf, elementCocoa), @"card is fully on a screen and does not cover the element");
                            if (shotDir && perApp[@(wpid)].intValue == 1) {
                                Spin(0.25);
                                CGFloat primaryMaxY = NSMaxY(NSScreen.screens.firstObject.frame);
                                NSRect both = NSInsetRect(NSUnionRect(pf, elementCocoa), -30, -30);
                                NSTask *task = [[NSTask alloc] init];
                                task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/screencapture"];
                                task.arguments = @[@"-x", @"-R", [NSString stringWithFormat:@"%.0f,%.0f,%.0f,%.0f", NSMinX(both), primaryMaxY - NSMaxY(both), both.size.width, both.size.height],
                                                   [shotDir stringByAppendingFormat:@"/element-%d.png", elementCards]];
                                [task launchAndReturnError:nil]; [task waitUntilExit];
                            }
                        }
                    }
                }
            }
            gFakeMouse = NSMakePoint(-5000, -5000);
            Spin(0.9);
            Expect(![[hover valueForKey:@"cardVisible"] boolValue], @"card hidden after the pointer left the last element");
            printf("  points sampled=%d, elements tested=%d in %lu applications\n", sampled, elementCards, (unsigned long)perApp.count);
            if (elementCards == 0) printf("  no background window of another application shows a named element the pointer can reach: nothing tested here\n");
        }

        printf("\ncounters: cards shown=%llu hit tests started=%llu found tab=%llu covered=%llu AX timeouts=%llu slowest AX part=%.0f ms\n",
               hover.cardsShown, hover.hitTestsStarted, hover.hitTestsFoundTab,
               // Read by name so that an older HoverClick.mm (--source) still compiles as a control.
               [hover respondsToSelector:NSSelectorFromString(@"hitTestsCovered")] ? [[hover valueForKey:@"hitTestsCovered"] unsignedLongLongValue] : 0ULL,
               hover.axTimeouts, hover.slowestAXDuration * 1000.0);
        [hover stopWithReason:@"harness"];
        Spin(0.2);
        printf("site line: the browser names a site for %d of %d tabs, the card showed one on %d\n", gSiteExpected, gSiteTabs, gSiteShown);
        printf("RESULT pass=%d fail=%d\n", gPass, gFail);
        return gFail == 0 ? 0 : 3;
    }
}
