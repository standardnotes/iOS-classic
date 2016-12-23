//
//  NSData+Crypto.h
//  standardnotes
//
//  Created by Mo Bitar on 12/20/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSData * AES128CBC(NSString *op, NSData * data, NSData * key);
extern NSData *HMAC256(NSData *data, NSData *keyData);
