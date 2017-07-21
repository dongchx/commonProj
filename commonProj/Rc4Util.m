//
//  Rc4Util.m
//  commonProj
//
//  Created by dongchx on 7/5/17.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import "Rc4Util.h"
#import <CommonCrypto/CommonDigest.h>


@implementation Rc4Util

+ (NSString *)md5:(NSString *)str

{
    const char *cStr = [str UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (CC_LONG)str.length, digest );
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [result appendFormat:@"%02x", digest[i]];
    
    return result;
}

// 生成秘钥

+ (NSString *)generatrKeyWithAdid:(NSString *)adid
                             acid:(NSString *)acid
{
    static NSString *randomStr = @"qidian-tingshu";
    
    NSString *seed = [NSString stringWithFormat:@"%@%@%@", adid,acid,randomStr];
    NSString *md5Str = [self md5:seed];
    
    char * digest = (char *)[[md5Str dataUsingEncoding:NSUTF8StringEncoding] bytes];
    
    return [self getHexStr: digest];
}

+ (NSString *)getHexStr:(char *)b
{
    unsigned char PRE_MASK  = ((char *)[[@"-16" dataUsingEncoding:NSUTF8StringEncoding] bytes])[0];
    unsigned char LAST_MASK = ((char *)[[@"15" dataUsingEncoding:NSUTF8StringEncoding] bytes])[0];
    
    NSMutableString *tmp = [NSMutableString string];
    
    for (int offset = 0; offset < strlen(b); offset++) {
        unsigned char value = b[offset];
        int pre  = (value & PRE_MASK & 0xff) >> 4;
        int last = (value & LAST_MASK);
        
        [tmp appendString:[NSString stringWithFormat:@"%x", pre]];
        [tmp appendString:[NSString stringWithFormat:@"%x", last]];
    }
    
    return tmp;
}

char* doProcess(short *sbox, char *input)
{
    int i = 0, j = 0, t = 0;
    short tmp;
    const unsigned long inputLength = strlen(input);
    
    char output[inputLength];
    
    for (int k = 0; k < inputLength; k++) {
        i = (i + 1) % 256;
        j = (j + sbox[i]) % 256;
        tmp = sbox[i];
        sbox[i] = sbox[j];
        sbox[j] = tmp;
        t = (sbox[i] + sbox[j]) % 256;
        output[k] = (char) (input[k] ^ sbox[t]);
    }
    
    char *result = output;
    return result;
}

short* rc4Int(NSString* keyStr)
{
    const short length = 256;
    short sbox[length];
    short key[length];
    
    for (short i = 0; i < length; i++) {
        sbox[i] = i;
        key[i] = (short)[keyStr characterAtIndex:i%keyStr.length];
    }
    
    short j = 0;
    short tmp = 0;
    for (short i = 0; i < length; i++) {
        j = (short) ((j + sbox[i] + key[i]) % length);
        tmp = sbox[i];
        sbox[i] = sbox[j];
        sbox[j] = tmp;
    }
    
    short *result = sbox;
    return result;
}

char* endecrption(char *input, int offset, int len, NSString *keyStr)
{
    if(input==NULL || strlen(input)==0 ||
       len<=0 || offset+len>strlen(input) ||
       keyStr==nil || keyStr.length<1)
    {
        return NULL;
    }
    
    short* sbox = rc4Int(keyStr);
    char * input2 = malloc(len);
    strncpy(input2, input+offset, len);
    char *output = doProcess(sbox, input2);

    return output;
}

@end








