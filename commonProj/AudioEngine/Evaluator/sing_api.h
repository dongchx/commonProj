// Copyright 2012 Tencent Inc.
// Created by dimwen
#ifndef __SING_API_H_
#define __SING_API_H_

#include "api_common.h"


int evalSing_Create(SING_HANDLE pSingObj, int* recordSize);

int evalSing_SetParam(SING_HANDLE pSingObj, int nParamID, int nParamValue); 

int evalSing_InitEvalObj(SING_HANDLE pSingObj, const SongToken* pSongToken);

int evalSing_AppendData(SING_HANDLE pSingObj, const char* pData, int numSample);

int evalSing_EndData(SING_HANDLE pSingObj, int* WholeSongScore);

int evalSing_RunStep(SING_HANDLE pSingObj);

int evalSing_GetResult(SING_HANDLE pSingObj, SingOutputToken* pResult);

#endif //__SING_API_H_
