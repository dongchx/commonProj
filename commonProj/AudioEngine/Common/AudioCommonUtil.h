//
//  AudioCommonUtil.h
//  QQKala
//
//  Created by frost on 12-7-26.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#ifndef QQKala_AudioCommonUtil_h
#define QQKala_AudioCommonUtil_h

#define INTERGER_CLIP(bits,i)   (\
(i) > (1 << ((bits) - 1)) - 1 ? (1 << ((bits) - 1)) - 1 : \
(i) < -1 << ((bits) - 1)      ? -1 << ((bits) - 1) :(i))
#define INTERGER_16_CLIP(i) INTERGER_CLIP(16,i)

#endif
