#ifndef REVERB_H_I
#define REVERB_H_I

int init(int rate, int channel, int percision);

/*------------------------------------
doReverb - 对输入wav流做混响效果处理
参数 in_buf 输入wav流
in_buf_size 输入wav流大小
out_buf 输出wav流
out_buf_size_ptr 输出wav流大小
g_argv 配置的参数，大小为10
------------------------------------*/
int doReverb(void* in_buf, int in_buf_size, char** out_buf, int* out_buf_size_ptr, char* g_argv);


int uninit();

#endif