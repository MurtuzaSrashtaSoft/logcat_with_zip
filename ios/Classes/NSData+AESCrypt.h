//
//  NSData+AESCrypt.h
//
//  AES128Encryption + Base64Encoding
//

#import <Foundation/Foundation.h>

@interface NSData (AESCrypt)

+ (NSData *)gzipData:(NSData*)pUncompressedData;

+ (NSData *)base64DataFromString:(NSString *)string;

- (NSData *)AES128EncryptWithKey:(NSString *)key;

- (NSData *)EncryptAES:(NSString *)key;

- (NSData *)DecryptAES:(NSString *)key;

- (NSString *)base64Encoding;

@end
