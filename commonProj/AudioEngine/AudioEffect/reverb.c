//
//  reverb.c
//  QQKala
//
//  Created by frost on 12-7-23.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#include "reverb.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "AudioEffectCommonDefine.h"


int reverb_init(reverb_p reverb, unsigned int rate, unsigned short numdelays, float reverbTime, float*delays)
{
    if (!reverb)
    {
        return QK_AUDIO_EFFECT_INVOBJ;
    }
    
    reverb->maxsamples = 0;
    reverb->rate = rate;
    reverb->numdelays = numdelays;
    reverb->time = reverbTime;
    reverb->reverbbuf = NULL;
    if (numdelays > MAXREVERBS || !delays)
    {
        return QK_AUDIO_EFFECT_INVARG;
    }
    
    for (int i = 0; i < numdelays; ++i)
    {
        reverb->delay[i] = delays[i];
    }
    return QK_AUDIO_EFFECT_OK;
}

int reverb_start(reverb_p reverb)
{
    if (!reverb)
    {
        return QK_AUDIO_EFFECT_INVOBJ;
    }
    
    if (reverb->time < 0.0) 
    {
        return QK_AUDIO_EFFECT_INVARG;
    }
    
    int i;
    reverb->in_gain = 1.0;
    for (i = 0; i < reverb->numdelays; ++i)
    {
        reverb->samples[i] = reverb->delay[i] * reverb->rate / 1000;
        if (reverb->samples[i] < 1)
        {
            return QK_AUDIO_EFFECT_INVARG;
        }
        /* Compute a realistic decay*/
        reverb->decay[i] = (float) pow(10.0, (-3.0 * reverb->delay[i] / reverb->time));
        if (reverb->samples[i] > reverb->maxsamples)
        {
            reverb->maxsamples = reverb->samples[i];
        }
    }
    reverb->reverbbuf = (float*)malloc(sizeof(float) * reverb->maxsamples);
    memset(reverb->reverbbuf, 0, reverb->maxsamples * sizeof(float));
    reverb->counter = 0;
    /* Compute the input volume carefully*/
    for (i = 0; i < reverb->numdelays; ++i)
    {
        reverb->in_gain *= (1.0 - (reverb->decay[i] * reverb->decay[i]));
    }
    return QK_AUDIO_EFFECT_OK;
}

int reverb_flow(reverb_p reverb, const short *iBuf, short *obuf,short len)
{
    if (NULL == reverb)
    {
        return QK_AUDIO_EFFECT_INVOBJ;
    }

    unsigned short i = reverb->counter;
    float d_in, d_out;
    short out;
    while (len--)
    {
        d_in = *iBuf++;
//        d_in = d_in * reverb->in_gain;
        
        /* Mix decay of delay and input as output */
        for (int j = 0; j < reverb->numdelays; ++j)
        {
            d_in += reverb->reverbbuf[(i + reverb->maxsamples - reverb->samples[j]) % reverb->maxsamples] * reverb->decay[j];
        }
        
        d_out = d_in;
        out = (short)INTERGER_16_CLIP(d_out);
        *obuf++ = (short)(out);
        reverb->reverbbuf[i] = d_in;
        i++;
        i %= reverb->maxsamples;
    }
    reverb->counter = i;
    return QK_AUDIO_EFFECT_OK;
}

int reverb_stop(reverb_p reverb)
{
    if (NULL == reverb)
    {
        return QK_AUDIO_EFFECT_INVOBJ;
    }
    
    free(reverb->reverbbuf);
    memset(reverb, 0, sizeof(reverbstuff));
    return QK_AUDIO_EFFECT_OK;
}
