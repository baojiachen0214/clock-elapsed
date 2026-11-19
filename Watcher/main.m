#import <Foundation/Foundation.h>
#import <AppKit/NSWorkspace.h>
#import <AppKit/NSRunningApplication.h>

static NSString *const ClockBundleID = @"com.apple.clock";
static NSString *const CompanionBundleID = @"local.clockelapsed.prototype";

static BOOL ClockIsRunning(void) {
  for (NSRunningApplication *application in
       [NSRunningApplication runningApplicationsWithBundleIdentifier:ClockBundleID]) {
    if (!application.terminated) return YES;
  }
  return NO;
}

/// No NSApplication, windows, timer, polling, or Swift runtime in the watcher.
@interface ClockElapsedWatcher : NSObject
@property(nonatomic) BOOL opening;
@property(nonatomic, strong) NSURL *companionURL;
- (void)start;
@end

@implementation ClockElapsedWatcher

- (void)start {
  self.companionURL = NSBundle.mainBundle.bundleURL;
  for (NSUInteger level = 0; level < 4; level++) {
    self.companionURL = self.companionURL.URLByDeletingLastPathComponent;
  }
  NSNotificationCenter *center = NSWorkspace.sharedWorkspace.notificationCenter;
  [center addObserver:self selector:@selector(applicationLaunched:)
                 name:NSWorkspaceDidLaunchApplicationNotification object:nil];
  [center addObserver:self selector:@selector(applicationTerminated:)
                 name:NSWorkspaceDidTerminateApplicationNotification object:nil];
  if (ClockIsRunning()) [self launchCompanion];
}

- (void)applicationLaunched:(NSNotification *)notification {
  @autoreleasepool {
    NSRunningApplication *application = notification.userInfo[NSWorkspaceApplicationKey];
    if ([application.bundleIdentifier isEqualToString:ClockBundleID]) {
      [self launchCompanion];
    }
  }
}

- (void)applicationTerminated:(NSNotification *)notification {
  @autoreleasepool {
    NSRunningApplication *application = notification.userInfo[NSWorkspaceApplicationKey];
    if (![application.bundleIdentifier isEqualToString:ClockBundleID] || ClockIsRunning()) return;
    for (NSRunningApplication *companion in
         [NSRunningApplication runningApplicationsWithBundleIdentifier:CompanionBundleID]) {
      [companion terminate];
    }
  }
}

- (void)launchCompanion {
  if (self.opening) return;
  for (NSRunningApplication *application in
       [NSRunningApplication runningApplicationsWithBundleIdentifier:CompanionBundleID]) {
    if (!application.terminated) return;
  }
  self.opening = YES;
  NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
  configuration.activates = NO;
  __weak ClockElapsedWatcher *weakSelf = self;
  [NSWorkspace.sharedWorkspace openApplicationAtURL:self.companionURL
                                     configuration:configuration
                                 completionHandler:^(NSRunningApplication *application, NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      @autoreleasepool {
        ClockElapsedWatcher *watcher = weakSelf;
        watcher.opening = NO;
        // Clock can quit while Launch Services is still opening the companion.
        if (watcher && application && !ClockIsRunning()) [application terminate];
      }
    });
  }];
}

- (void)dealloc {
  [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
}

@end

int main(void) {
  __attribute__((objc_precise_lifetime)) ClockElapsedWatcher *watcher;
  @autoreleasepool {
    watcher = [ClockElapsedWatcher new];
    [watcher start];
    // Keep the run loop blocked even if workspace event sources are temporarily
    // absent. This port is never polled and has no periodic wakeup.
    NSPort *idlePort = [NSMachPort port];
    [NSRunLoop.mainRunLoop addPort:idlePort forMode:NSDefaultRunLoopMode];
  }
  for (;;) {
    @autoreleasepool {
      [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:NSDate.distantFuture];
    }
  }
}
