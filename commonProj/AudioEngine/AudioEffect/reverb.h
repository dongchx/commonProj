//
//  reverb.h
//  QQKala
//
//  Created by frost on 12-7-23.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#ifndef QQKala_reverb_h
#define QQKala_reverb_h

#ifdef __cplusplus
extern "C" {
#endif
    
#define MAXREVERBS  8
    typedef struct {
        unsigned int    rate;                   // sample rate
        unsigned int    counter;
        float           *reverbbuf;
        unsigned short  numdelays;
        unsigned short  maxsamples;
        unsigned short  samples[MAXREVERBS];
        float           in_gain;
        float           out_gain;
        float           time;                   // reverb time (ms)
        float           delay[MAXREVERBS];      // delay time (ms)
        float           decay[MAXREVERBS];
    } reverbstuff, *reverb_p;
    
    int reverb_init(reverb_p reverb, unsigned int rate, unsigned short numdelays, float reverbTime, float*delays);
    int reverb_start(reverb_p reverb);
    int reverb_flow(reverb_p reverb, const short *iBuf, short *obuf, short len);
    int reverb_stop(reverb_p reverb);
    
#ifdef __cplusplus
}
#endif

#endif
