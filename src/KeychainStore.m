#import "KeychainStore.h"
#import <Security/Security.h>

@implementation KeychainStore
+ (NSMutableDictionary *)queryForService:(NSString *)service account:(NSString *)account {
    NSMutableDictionary *q=[NSMutableDictionary dictionary];
    [q setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];
    [q setObject:(service?:@"iPad1VNC") forKey:(id)kSecAttrService];
    [q setObject:(account?:@"default") forKey:(id)kSecAttrAccount];
    return q;
}
+ (NSString *)stringForService:(NSString *)service account:(NSString *)account {
    NSMutableDictionary *q=[self queryForService:service account:account];
    [q setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    [q setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
    CFTypeRef result=NULL;
    OSStatus s=SecItemCopyMatching((CFDictionaryRef)q,&result);
    if(s!=errSecSuccess||!result)return nil;
    NSData *d=[(NSData *)result autorelease];
    NSString *v=[[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] autorelease];
    return v;
}
+ (BOOL)setString:(NSString *)value service:(NSString *)service account:(NSString *)account {
    if(!value)value=@"";
    NSMutableDictionary *q=[self queryForService:service account:account];
    NSData *d=[value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attrs=[NSDictionary dictionaryWithObject:d forKey:(id)kSecValueData];
    OSStatus s=SecItemUpdate((CFDictionaryRef)q,(CFDictionaryRef)attrs);
    if(s==errSecItemNotFound){
        [q setObject:d forKey:(id)kSecValueData];
        s=SecItemAdd((CFDictionaryRef)q,NULL);
    }
    return s==errSecSuccess;
}
+ (BOOL)deleteService:(NSString *)service account:(NSString *)account {
    NSMutableDictionary *q=[self queryForService:service account:account];
    OSStatus s=SecItemDelete((CFDictionaryRef)q);
    return s==errSecSuccess||s==errSecItemNotFound;
}
@end
