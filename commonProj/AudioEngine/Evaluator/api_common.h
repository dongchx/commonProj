#ifndef _API_COMM_DEFINE_H
#define _API_COMM_DEFINE_H

//所有接口正常返回值
#define EvalSing_OK                               (0)

//RunStep时，若有评分结果时的返回值
#define EvalSing_RESULT                           (0x00000001)

//GetResult时，关于声音大小的反馈的返回值
#define EvalSing_VOLUMEHIGH                       (0x00000002)
#define EvalSing_VOLUMELOW                        (0x00000003)

//RunStep时，若新录入的数据为空时的返回值
#define EvalSing_EMPTY                            (0x00000004)

//当evalSing_Create传入 NULL 时，正常获取评分引擎所需要的内存大小时的返回值
#define EvalSing_SIZECALCULATED                   (0x00000005)

//SetParam时，若 参数的ID 越界返回错误
#define EvalSing_PARAM_ID_OUT                     (0x80000001)

//evalSing_InitEvalObj时，对应 载入底库数据数据，基频提取初始化错误，匹配初始化错误
#define EvalSing_LOAD_NO_SENTENCE                 (0x80000002)
#define EvalSing_LOAD_DATA_ERROR                  (0x80000003)
#define EvalSing_PITCHTRACK_INIT_ERROR            (0x80000004)
#define EvalSing_DTMMATCH_INIT_ERROR              (0x80000005)

//RunStep中返回基频提取错误，单句评分错误
#define EvalSing_PITCHTRACK_ERROR                 (0x80000006)
#define EvalSing_EVAL_ONESEGMENT_ERROR            (0x80000007)

#ifdef _MSC_VER
typedef __int16 int16_t;
typedef unsigned __int16 uint16_t;
typedef __int32 int32_t;
typedef unsigned __int32 uint32_t;
typedef __int64 int64_t;
typedef unsigned __int64 uint64_t;
#else
#include <stdint.h>
#endif

typedef void* SING_HANDLE;

typedef struct SingOutputToken{
	uint16_t nIndex;
	uint16_t nType;
	uint16_t nScore;
} SingOutputToken;

typedef struct ToneToken {
    uint16_t nPitch;
    uint16_t nDuration;
} ToneToken;

typedef struct WordToken {
	uint16_t nTone;
    ToneToken* pToneToken;
} WordToken;

typedef struct SentenceToken {
    uint32_t nStartTime;
    uint16_t nDuration;
    uint16_t nWord;
	WordToken* pWordToken;
} SentenceToken;

typedef struct SongToken{
    uint16_t nSentence;
    SentenceToken* pSentenceToken;
} SongToken;


#endif
