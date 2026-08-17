#import <Foundation/Foundation.h>

@interface KeychainStore : NSObject
+ (NSString *)stringForService:(NSString *)service account:(NSString *)account;
+ (BOOL)setString:(NSString *)value service:(NSString *)service account:(NSString *)account;
+ (BOOL)deleteService:(NSString *)service account:(NSString *)account;
@end
