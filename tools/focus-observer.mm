// focus-observer: records every frontmost-application change while a click is reproduced.
//
// HoverClick samples NSWorkspace.frontmostApplication twice (immediately after -activateWithOptions:
// and again 200 ms later). A transient activation that lands between those two samples is invisible
// in HoverClick's own log. This tool records the workspace activation notifications, which the system
// posts on every real switch, plus a 5 ms poll as a cross-check.
//
// Build:  clang++ -fobjc-arc -framework AppKit -o focus-observer tools/focus-observer.mm
// Run:    ./focus-observer 30
//
// Reads nothing, posts nothing, needs no Accessibility permission.

#import <AppKit/AppKit.h>

static NSString *Stamp(void) {
    static NSDateFormatter *formatter = nil;
    if (formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm:ss.SSS";
    }
    return [formatter stringFromDate:[NSDate date]];
}

static NSString *Describe(NSRunningApplication *app) {
    if (app == nil) {
        return @"none";
    }
    return [NSString stringWithFormat:@"%@ pid=%d%s",
                                      app.localizedName ?: @"unknown",
                                      app.processIdentifier,
                                      app.activationPolicy == NSApplicationActivationPolicyAccessory ? " policy=accessory" : ""];
}

@interface FocusObserver : NSObject
@end

@implementation FocusObserver {
    pid_t _lastPolledPid;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _lastPolledPid = -1;
    }
    return self;
}

- (void)note:(NSString *)label application:(NSRunningApplication *)app {
    printf("%s  %-12s %s\n", Stamp().UTF8String, label.UTF8String, Describe(app).UTF8String);
    fflush(stdout);
}

- (void)workspaceActivated:(NSNotification *)notification {
    [self note:@"ACTIVATED" application:notification.userInfo[NSWorkspaceApplicationKey]];
}

- (void)workspaceDeactivated:(NSNotification *)notification {
    [self note:@"deactivated" application:notification.userInfo[NSWorkspaceApplicationKey]];
}

- (void)poll:(NSTimer *)timer {
    (void)timer;
    NSRunningApplication *front = [NSWorkspace sharedWorkspace].frontmostApplication;
    pid_t pid = front != nil ? front.processIdentifier : 0;
    if (pid != _lastPolledPid) {
        _lastPolledPid = pid;
        [self note:@"poll-change" application:front];
    }
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        double seconds = argc > 1 ? atof(argv[1]) : 30.0;
        if (seconds <= 0.0) {
            seconds = 30.0;
        }

        FocusObserver *observer = [[FocusObserver alloc] init];
        NSNotificationCenter *center = [NSWorkspace sharedWorkspace].notificationCenter;
        [center addObserver:observer
                   selector:@selector(workspaceActivated:)
                       name:NSWorkspaceDidActivateApplicationNotification
                     object:nil];
        [center addObserver:observer
                   selector:@selector(workspaceDeactivated:)
                       name:NSWorkspaceDidDeactivateApplicationNotification
                     object:nil];

        [NSTimer scheduledTimerWithTimeInterval:0.005
                                         target:observer
                                       selector:@selector(poll:)
                                       userInfo:nil
                                        repeats:YES];

        printf("focus-observer: recording for %.0f s. Reproduce the click now.\n", seconds);
        [observer note:@"start" application:[NSWorkspace sharedWorkspace].frontmostApplication];

        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
        printf("focus-observer: done.\n");
    }
    return 0;
}
