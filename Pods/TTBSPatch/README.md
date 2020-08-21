#### 概要

bsdiff and bspatch are libraries for building and applying patches to binary files.

The original algorithm and implementation was developed by Colin Percival. The algorithm is detailed in his paper, Naïve Differences of Executable Code. For more information, visit his website at http://www.daemonology.net/bsdiff/.

bsdiff/bspatch 是基于C语言的对二进制文件进行差分和增量更新的库。

原始算法和实现详见 [http://www.daemonology.net/bsdiff/.](http://www.daemonology.net/bsdiff/.).
使用版本 version 4.3
MD5  e6d812394f0e0ecc8d5df255aa1db22a

我们只用到了patch的部分，所以在本工程中只引入了bspatch相关文件, 并在其基础上做了一层OC封装

#### 使用说明

```
/**
 @param originFile The absolute path of file will be patched
 @param targetFile The absolute path of the new file will be created
 @param patchFile  The patch file's absolute path
 @return patch success or fail

 */
+ (BOOL)patchWithOriginFilePath:(NSString *)originFile
                targetFilePath:(NSString *)targetFile
                 patchFilePath:(NSString *)patchFile;
```
