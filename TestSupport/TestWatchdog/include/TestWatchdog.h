#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface WMTestWatchdog : NSObject
- (instancetype)initWithSeconds:(NSTimeInterval)seconds
                      onTimeout:(void (^)(NSString *testName))onTimeout;
- (void)startTest:(NSString *)name;
- (void)finishTest:(NSString *)name;
@end
NS_ASSUME_NONNULL_END
