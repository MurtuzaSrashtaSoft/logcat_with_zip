//
//  UserUtil.m
//  Hubble
//
//  Created by Sven Resch on 2014-10-28.
//  Copyright (c) 2014 Hubble Connected Ltd. All rights reserved.
//

#import "UserUtil.h"
#import "NSData+AESCrypt.h"

@implementation UserUtil

+ (NSNumber *)zipAndEncryptFile: (NSString *)path toPath: (NSString *)destPath toKey:(NSString *)key {

    if ( [[NSFileManager defaultManager] fileExistsAtPath:path] ) {
        NSData *data  = [NSData dataWithContentsOfFile:path];
        
        if (data && data.length > 0) {
            data = [NSData gzipData:data];
//            data = [data AES128EncryptWithKey:@"Super-LovelyDuck"];
            data = [data AES128EncryptWithKey: key];
            if (data && data.length > 0) {
                [data writeToFile: destPath atomically: YES];
                return @YES;
            }
        }
    }

    return @NO;
}

@end
