#ifndef REVERB_H_I
#define REVERB_H_I

int init(int rate, int channel, int percision);

/*------------------------------------
doReverb - ������wav��������Ч������
���� in_buf ����wav��
in_buf_size ����wav����С
out_buf ���wav��
out_buf_size_ptr ���wav����С
g_argv ���õĲ�������СΪ10
------------------------------------*/
int doReverb(void* in_buf, int in_buf_size, char** out_buf, int* out_buf_size_ptr, char* g_argv);


int uninit();

#endif