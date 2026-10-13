#import "TestWatchdog.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>
#import <stdio.h>
#import <stdlib.h>

// XCTest's executionTimeAllowance is not enforced by plain swift test.
static const NSTimeInterval WMTestTimeoutSeconds = 120;

@implementation WMTestWatchdog {
    NSLock *_lock;
    dispatch_queue_t _queue;
    NSTimeInterval _seconds;
    void (^_onTimeout)(NSString *);
    NSString *_name;
    NSUInteger _generation;
}

- (instancetype)initWithSeconds:(NSTimeInterval)seconds onTimeout:(void (^)(NSString *))onTimeout {
    if ((self = [super init])) {
        _lock = [NSLock new];
        _queue = dispatch_queue_create("winmux.test-watchdog", DISPATCH_QUEUE_SERIAL);
        _seconds = seconds;
        _onTimeout = [onTimeout copy];
    }
    return self;
}

- (void)startTest:(NSString *)name {
    [_lock lock];
    _name = [name copy];
    NSUInteger generation = ++_generation;
    [_lock unlock];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_seconds * NSEC_PER_SEC)), _queue, ^{
        [self->_lock lock];
        if (self->_name && self->_generation == generation) {
            self->_onTimeout(self->_name);
            self->_name = nil;
        }
        [self->_lock unlock];
    });
}

- (void)finishTest:(NSString *)name {
    [_lock lock];
    if ([_name isEqualToString:name]) {
        _name = nil;
        ++_generation;
    }
    [_lock unlock];
}
@end

@interface WMTestObserver : NSObject
@end

@implementation WMTestObserver {
    WMTestWatchdog *_watchdog;
}

+ (void)load {
    // +load runs before test discovery, including when the first test blocks main.
    Class centerClass = NSClassFromString(@"XCTestObservationCenter");
    if (!centerClass) {
        fprintf(stderr, "WinMux test watchdog: XCTestObservationCenter unavailable\n");
        _Exit(125);
    }
    id center = ((id (*)(id, SEL))objc_msgSend)(centerClass, NSSelectorFromString(@"sharedTestObservationCenter"));
    Protocol *observation = NSProtocolFromString(@"XCTestObservation");
    if (!observation || !class_addProtocol(self, observation)) {
        fprintf(stderr, "WinMux test watchdog: cannot adopt XCTestObservation\n");
        _Exit(125);
    }
    WMTestObserver *observer = [WMTestObserver new];
    ((void (*)(id, SEL, id))objc_msgSend)(center, NSSelectorFromString(@"addTestObserver:"), observer);
}

- (instancetype)init {
    if ((self = [super init])) {
        NSTimeInterval seconds = WMTestTimeoutSeconds;
        const char *override = getenv("WINMUX_TEST_TIMEOUT_SECONDS");
        if (override) {
            char *end = NULL;
            seconds = strtod(override, &end);
            if (end == override || *end || !isfinite(seconds) || seconds <= 0 || seconds > INT64_MAX / (double)NSEC_PER_SEC) {
                fprintf(stderr, "WinMux test watchdog: WINMUX_TEST_TIMEOUT_SECONDS must be a positive finite number of seconds\n");
                _Exit(125);
            }
        }
        _watchdog = [[WMTestWatchdog alloc] initWithSeconds:seconds onTimeout:^(NSString *name) {
            fprintf(stderr, "WinMux test timeout: %s exceeded %.3f seconds; terminating test process (later tests will not run)\n", name.UTF8String, seconds);
            // _Exit skips the buffers, and on CI stdout is a pipe holding the earlier tests' output.
            fflush(NULL);
            _Exit(124);
        }];
    }
    return self;
}

- (void)testCaseWillStart:(id)testCase {
    NSString *name = ((id (*)(id, SEL))objc_msgSend)(testCase, @selector(name));
    [_watchdog startTest:name];
}

- (void)testCaseDidFinish:(id)testCase {
    NSString *name = ((id (*)(id, SEL))objc_msgSend)(testCase, @selector(name));
    [_watchdog finishTest:name];
}
@end
