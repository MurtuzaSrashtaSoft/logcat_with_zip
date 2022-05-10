//
//  UserUtil.h
//  Hubble
//
//  Created by Sven Resch on 2014-10-28.
//  Copyright (c) 2014 Hubble Connected Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserUtil : NSObject

+ (NSNumber *)zipAndEncryptFile: (NSString *)path toPath: (NSString *)destPath toKey: (NSString *)key;

@end
