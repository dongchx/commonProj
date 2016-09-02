//
//  AudioEffectCommonDefine.h
//  QQKala
//
//  Created by frost on 12-7-23.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#ifndef QQKala_AudioEffectCommonDefine_h
#define QQKala_AudioEffectCommonDefine_h

#include "AudioCommonUtil.h"

#define QK_AUDIO_EFFECT_OK          0
#define QK_AUDIO_EFFECT_INVARG      (-1)
#define QK_AUDIO_EFFECT_INVOBJ      (-2)

typedef struct
{
    unsigned short      delays;             // must always be 3
    float               delayTimes[3];
    float               reverbTime;
} ReverbEffectParam;

#endif
