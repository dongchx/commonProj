/* vim: set ft=objc fenc=utf-8 sw=2 ts=2 et: */
/*
 *  DOUAudioStreamer - A Core Audio based streaming audio player for iOS/Mac:
 *
 *      https://github.com/douban/DOUAudioStreamer
 *
 *  Copyright 2013-2016 Douban Inc.  All rights reserved.
 *
 *  Use and distribution licensed under the BSD license.  See
 *  the LICENSE file for full text.
 *
 *  Authors:
 *      Chongyu Zhu <i@lembacon.com>
 *
 */

#import "DOUAudioRenderer.h"
#import "DOUAudioDecoder.h"
#import "DOUAudioAnalyzer.h"
#include <CoreAudio/CoreAudioTypes.h>
#include <AudioUnit/AudioUnit.h>
#include <pthread.h>
#include <sys/types.h>
#include <sys/time.h>
#include <mach/mach_time.h>
#include <Accelerate/Accelerate.h>

@interface DOUAudioRenderer () {
@private
  pthread_mutex_t _mutex; // 互斥锁
  pthread_cond_t _cond;   // 条件变量

  AudioComponentInstance _outputAudioUnit;

  uint8_t *_buffer;
  NSUInteger _bufferByteCount;
  NSUInteger _firstValidByteOffset;
  NSUInteger _validByteCount;

  NSUInteger _bufferTime;
  BOOL _started;

  NSArray *_analyzers;

  uint64_t _startedTime;
  uint64_t _interruptedTime;
  uint64_t _totalInterruptedInterval;

  double _volume;
}
@end

@implementation DOUAudioRenderer

@synthesize started = _started;
@synthesize analyzers = _analyzers;

+ (instancetype)rendererWithBufferTime:(NSUInteger)bufferTime
{
  return [[[self class] alloc] initWithBufferTime:bufferTime];
}

- (instancetype)initWithBufferTime:(NSUInteger)bufferTime
{
  self = [super init];
  if (self) {
    pthread_mutex_init(&_mutex, NULL); // 互斥锁
    pthread_cond_init(&_cond, NULL);   // 条件变量

    _bufferTime = bufferTime;
    _volume = 1.0;
  }

  return self;
}

- (void)dealloc
{
  if (_outputAudioUnit != NULL) {
    [self tearDown];
  }

  if (_buffer != NULL) {
    free(_buffer);
  }

  pthread_mutex_destroy(&_mutex);
  pthread_cond_destroy(&_cond);
}

- (void)_setShouldInterceptTiming:(BOOL)shouldInterceptTiming
{
  if (_startedTime == 0) {
    _startedTime =
      mach_absolute_time(); // 返回CPU时钟周期（能够用以描述的时间的均匀变化的值）
  }

  if ((_interruptedTime != 0) == shouldInterceptTiming) {
    return;
  }

  if (shouldInterceptTiming) {
    _interruptedTime = mach_absolute_time();
  }
  else {
    _totalInterruptedInterval += mach_absolute_time() - _interruptedTime;
    _interruptedTime = 0;
  }
}

// i/o回调
static OSStatus au_render_callback(void *inRefCon,
                                   AudioUnitRenderActionFlags *inActionFlags,
                                   const AudioTimeStamp *inTimeStamp,
                                   UInt32 inBusNumber,
                                   UInt32 inNumberFrames,
                                   AudioBufferList *ioData)
{
  __unsafe_unretained DOUAudioRenderer *renderer = (__bridge DOUAudioRenderer *)inRefCon;
  pthread_mutex_lock(&renderer->_mutex);

  NSUInteger totalBytesToCopy = ioData->mBuffers[0].mDataByteSize;
  NSUInteger validByteCount = renderer->_validByteCount;

  if (validByteCount < totalBytesToCopy) {
    [renderer->_analyzers makeObjectsPerformSelector:@selector(flush)];
    [renderer _setShouldInterceptTiming:YES];

    *inActionFlags = kAudioUnitRenderAction_OutputIsSilence;
    bzero(ioData->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
    pthread_mutex_unlock(&renderer->_mutex);
    return noErr;
  }
  else {
    [renderer _setShouldInterceptTiming:NO];
  }

  uint8_t *bytes = renderer->_buffer + renderer->_firstValidByteOffset;
  uint8_t *outBuffer = (uint8_t *)ioData->mBuffers[0].mData;
  NSUInteger outBufSize = ioData->mBuffers[0].mDataByteSize;
  NSUInteger bytesToCopy = MIN(outBufSize, validByteCount);
  NSUInteger firstFrag = bytesToCopy;

  if (renderer->_firstValidByteOffset + bytesToCopy > renderer->_bufferByteCount) {
    firstFrag = renderer->_bufferByteCount - renderer->_firstValidByteOffset;
  }

  if (firstFrag < bytesToCopy) {
    memcpy(outBuffer, bytes, firstFrag);
    memcpy(outBuffer + firstFrag, renderer->_buffer, bytesToCopy - firstFrag);
  }
  else {
    memcpy(outBuffer, bytes, bytesToCopy);
  }

  NSArray *analyzers = renderer->_analyzers;
  if (analyzers != nil) {
    for (DOUAudioAnalyzer *analyzer in analyzers) {
      [analyzer handleLPCMSamples:(int16_t *)outBuffer
                            count:bytesToCopy / sizeof(int16_t)];
    }
  }

  if (renderer->_volume != 1.0) {
    int16_t *samples = (int16_t *)outBuffer;
    size_t samplesCount = bytesToCopy / sizeof(int16_t);

    float floatSamples[samplesCount];
      // 16位整数转单精度浮点数
    vDSP_vflt16(samples, 1, floatSamples, 1, samplesCount);

    float volume = renderer->_volume;
      // 单精度乘法
    vDSP_vsmul(floatSamples, 1, &volume, floatSamples, 1, samplesCount);

      // 单精度浮点数转16位整数
    vDSP_vfix16(floatSamples, 1, samples, 1, samplesCount);
  }

  if (bytesToCopy < outBufSize) {
    bzero(outBuffer + bytesToCopy, outBufSize - bytesToCopy);
  }

  renderer->_validByteCount -= bytesToCopy;
  renderer->_firstValidByteOffset = (renderer->_firstValidByteOffset + bytesToCopy) % renderer->_bufferByteCount;

  pthread_mutex_unlock(&renderer->_mutex);
  pthread_cond_signal(&renderer->_cond);

  return noErr;
}

- (BOOL)setUp
{
  if (_outputAudioUnit != NULL) {
    return YES;
  }

  OSStatus status;

  AudioComponentDescription desc;
  desc.componentType = kAudioUnitType_Output;
  desc.componentSubType = kAudioUnitSubType_RemoteIO;
  desc.componentManufacturer = kAudioUnitManufacturer_Apple;
  desc.componentFlags = 0;
  desc.componentFlagsMask = 0;

  AudioComponent comp = AudioComponentFindNext(NULL, &desc);
  if (comp == NULL) {
    return NO;
  }

  status = AudioComponentInstanceNew(comp, &_outputAudioUnit);
  if (status != noErr) {
    _outputAudioUnit = NULL;
    return NO;
  }

  AudioStreamBasicDescription requestedDesc = [DOUAudioDecoder defaultOutputFormat];

    // 设置流格式
  status = AudioUnitSetProperty(_outputAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &requestedDesc, sizeof(requestedDesc));
  if (status != noErr) {
    AudioComponentInstanceDispose(_outputAudioUnit);
    _outputAudioUnit = NULL;
    return NO;
  }

  UInt32 size = sizeof(requestedDesc);
    
  status = AudioUnitGetProperty(_outputAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &requestedDesc, &size);
  if (status != noErr) {
    AudioComponentInstanceDispose(_outputAudioUnit);
    _outputAudioUnit = NULL;
    return NO;
  }

  AURenderCallbackStruct input;
  input.inputProc = au_render_callback;
  input.inputProcRefCon = (__bridge void *)self;

    // 设置解析回调
  status = AudioUnitSetProperty(_outputAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &input, sizeof(input));
  if (status != noErr) {
    AudioComponentInstanceDispose(_outputAudioUnit);
    _outputAudioUnit = NULL;
    return NO;
  }

    // i/o instance
  status = AudioUnitInitialize(_outputAudioUnit);
  if (status != noErr) {
    AudioComponentInstanceDispose(_outputAudioUnit);
    _outputAudioUnit = NULL;
    return NO;
  }

  if (_buffer == NULL) {
    _bufferByteCount = (_bufferTime * requestedDesc.mSampleRate / 1000) * (requestedDesc.mChannelsPerFrame * requestedDesc.mBitsPerChannel / 8);
    _firstValidByteOffset = 0;
    _validByteCount = 0;
    _buffer = (uint8_t *)calloc(1, _bufferByteCount);
  }

  return YES;
}

- (void)tearDown
{
  if (_outputAudioUnit == NULL) {
    return;
  }

  [self stop];
  [self _tearDownWithoutStop];
}

- (void)_tearDownWithoutStop
{
  AudioUnitUninitialize(_outputAudioUnit);
  AudioComponentInstanceDispose(_outputAudioUnit);
  _outputAudioUnit = NULL;
}

- (void)renderBytes:(const void *)bytes length:(NSUInteger)length
{
  if (_outputAudioUnit == NULL) {
    return;
  }

  while (length > 0) {
    pthread_mutex_lock(&_mutex);

    NSUInteger emptyByteCount = _bufferByteCount - _validByteCount;
    while (emptyByteCount == 0) {
      if (!_started) {
        if (_interrupted) {
          pthread_mutex_unlock(&_mutex);
          return;
        }

        pthread_mutex_unlock(&_mutex);
        AudioOutputUnitStart(_outputAudioUnit);
        pthread_mutex_lock(&_mutex);
        _started = YES;
      }

      struct timeval tv;
      struct timespec ts;
      gettimeofday(&tv, NULL);
      ts.tv_sec = tv.tv_sec + 1;
      ts.tv_nsec = 0;
      pthread_cond_timedwait(&_cond, &_mutex, &ts);
      emptyByteCount = _bufferByteCount - _validByteCount;
    } // end While

    NSUInteger firstEmptyByteOffset = (_firstValidByteOffset + _validByteCount) % _bufferByteCount;
    NSUInteger bytesToCopy;
    if (firstEmptyByteOffset + emptyByteCount > _bufferByteCount) {
      bytesToCopy = MIN(length, _bufferByteCount - firstEmptyByteOffset);
    }
    else {
      bytesToCopy = MIN(length, emptyByteCount);
    }

    memcpy(_buffer + firstEmptyByteOffset, bytes, bytesToCopy);

    length -= bytesToCopy;
    bytes = (const uint8_t *)bytes + bytesToCopy;
    _validByteCount += bytesToCopy;

    pthread_mutex_unlock(&_mutex);
  }
}

- (void)stop
{
  [_analyzers makeObjectsPerformSelector:@selector(flush)];

  if (_outputAudioUnit == NULL) {
    return;
  }

  pthread_mutex_lock(&_mutex);
  if (_started) {
    pthread_mutex_unlock(&_mutex);
    AudioOutputUnitStop(_outputAudioUnit);
    pthread_mutex_lock(&_mutex);

    [self _setShouldInterceptTiming:YES];
    _started = NO;
  }
  pthread_mutex_unlock(&_mutex);
  pthread_cond_signal(&_cond);
}

- (void)flush
{
  [self flushShouldResetTiming:YES];
}

- (void)flushShouldResetTiming:(BOOL)shouldResetTiming
{
  [_analyzers makeObjectsPerformSelector:@selector(flush)];

  if (_outputAudioUnit == NULL) {
    return;
  }

  pthread_mutex_lock(&_mutex);

  _firstValidByteOffset = 0;
  _validByteCount = 0;
  if (shouldResetTiming) {
    [self _resetTiming];
  }

  pthread_mutex_unlock(&_mutex);
  pthread_cond_signal(&_cond);
}

+ (double)_absoluteTimeConversion
{
  static double conversion;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    conversion = 1.0e-9 * info.numer / info.denom;
  });

  return conversion;
}

- (void)_resetTiming
{
  _startedTime = 0;
  _interruptedTime = 0;
  _totalInterruptedInterval = 0;
}

- (NSUInteger)currentTime
{
  if (_startedTime == 0) {
    return 0;
  }

  double base = [[self class] _absoluteTimeConversion] * 1000.0;

  uint64_t interval;
  if (_interruptedTime == 0) {
    interval = mach_absolute_time() - _startedTime - _totalInterruptedInterval;
  }
  else {
    interval = _interruptedTime - _startedTime - _totalInterruptedInterval;
  }

  return base * interval;
}

- (void)setInterrupted:(BOOL)interrupted
{
  pthread_mutex_lock(&_mutex);
  _interrupted = interrupted;
  pthread_mutex_unlock(&_mutex);
}

- (double)volume
{
  return _volume;
}

- (void)setVolume:(double)volume
{
  _volume = volume;
}

@end
