//
//  PublicConfig.h
//  QQKala
//
//  Created by frost on 12-6-4.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#ifndef QQKala_PublicConfig_h
#define QQKala_PublicConfig_h

//#define TEST
//#define LOGON

#ifdef TEST
    #define ProtocolUrl         "http://test3.wapmusic.qq.com"
    #define KStatServiceURL		@"http://test1.wapmusic.qq.com:80/user_stat.jsp"
    #define SOFT_PRO_V          201
    #define kHelpUrl            @"http://musictest4.3g.qq.com/html?aid=kge_help"
    #define kEULAUrl            @"http://musictest4.3g.qq.com/html?aid=kge_statement"
#else
    #define ProtocolUrl         "http://kmusic.3g.qq.com"
    #define KStatServiceURL		@"http://kmusicstat.3g.qq.com/user_stat.jsp"
    #define SOFT_PRO_V          301
    #define kHelpUrl            @"http://y.3g.qq.com/html?aid=kge_help"
    #define kEULAUrl            @"http://y.3g.qq.com/html?aid=kge_statement"
#endif

#define	DATASTORE_VERSION		@"QQKala_v1.sqlite"
#define	SERVER_PROTOCOL_VERSION		10001
#define SERVER_SERVICE_ID           10001

#define MAX_70_COMMENT_TEXT_LEN		138	// 评论回复输入文字最大长度

/*
 * Log preprocessor macro
 */
#ifdef LOGON
#define QKLog(log, ...)   (NSLog(log, ## __VA_ARGS__))
#else
#define QKLog(log, ...)
#endif

/*
 *  System Versioning Preprocessor Macros
 */ 
#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#endif


//#define FONT_NAME_FOR_FANGZHENGZHIYIJIANTI  @"FZZHYJW--GB1-0"
//#define FONT_NAME_FOR_LYRIC                 @"--unknown-1--"



/**
 * The standard duration for transition animations.
 */
#define TT_TRANSITION_DURATION 0.3

#define TT_FAST_TRANSITION_DURATION 0.2

#define TT_FLIP_TRANSITION_DURATION 0.7

#define		NSQQKaraXML             @"<?xml version=\"1.0\" encoding=\"utf-8\"?><root><uid>%@</uid><sid>%@</sid><v>%d</v><qq>%@</qq><imei>%@</imei><dev>%@</dev><phone>%@</phone>%@</root>"

