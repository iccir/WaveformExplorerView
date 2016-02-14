/*
    Copyright (c) 2014, Ricci Adams
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following condition is met:

    1. Redistributions of source code must retain the above copyright notice, this
       list of conditions and the following disclaimer. 

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
    ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


#import "WaveSampleArray.h"
#import <Accelerate/Accelerate.h>


@implementation WaveSampleArray {
    float *_samples;
    NSUInteger _count;
    BOOL _freeWhenDone;
}

+ (id) sampleArrayWithSamples:(float *)samples count:(NSUInteger)count
{
    return [[self alloc] initWithSamples:samples count:count];
}


+ (id) sampleArrayWithSamplesNoCopy:(float *)samples count:(NSUInteger)count
{
    return [[self alloc] initWithSamplesNoCopy:samples count:count freeWhenDone:YES];
}


+ (id) sampleArrayWithSamplesNoCopy:(float *)samples count:(NSUInteger)count freeWhenDone:(BOOL)b
{
    return [[self alloc] initWithSamplesNoCopy:samples count:count freeWhenDone:b];
}


- (id) initWithSamples:(float *)samples count:(NSUInteger)count
{
    NSUInteger size = sizeof(float) * count;
    
    float *samplesCopy = malloc(size);
    memcpy(samplesCopy, samples, size);
    
    return [self initWithSamplesNoCopy:samplesCopy count:count freeWhenDone:YES];
}


- (id) initWithSamplesNoCopy:(float *)samples count:(NSUInteger)count
{
    return [self initWithSamplesNoCopy:samples count:count freeWhenDone:YES];
}


- (id) initWithSamplesNoCopy:(float *)samples count:(NSUInteger)count freeWhenDone:(BOOL)b
{
    if ((self = [super init])) {
        _samples = samples;
        _count   = count;
        _freeWhenDone = b;
    }

    return self;
}

- (id) initWithData:(NSData *)data freeWhenDone:(BOOL)b;
{
    float *samples = (float *)[data bytes];
    NSUInteger count = [data length] / sizeof(float);
    
    return [self initWithSamplesNoCopy:samples count:count freeWhenDone:b];
}

- (void) dealloc
{
    if (_freeWhenDone) {
        free(_samples);
    }
}


- (WaveSampleArray *) sampleArrayWithCount:(NSUInteger)outCount
{
    float *input = _samples;
    NSInteger inCount = _count;

    double stride = inCount / (double)outCount;
    
    float *output = malloc(outCount * sizeof(float));
    
    dispatch_apply(outCount, dispatch_get_global_queue(0, 0), ^(size_t o) {
        NSInteger i = llrint(o * stride);

        // We cheat twice for performance, we can get away with this because we
        // are dealing with audio waveforms.

        // Cheat #1: Just floor stride, this results in a skipped sample on occasion
        NSInteger length = (NSInteger)stride;
        
        // Be paranoid, I saw a crash in vDSP_maxv() during development
        if (i + length > _count) {
            length = (_count - i);
        }
        
        if (length == 0) {
            output[o] = 0.0;
            return;
        }

        // Cheat #2: Only check for max value and not both max and min
        float max;
        vDSP_maxv(&input[i], 1, &max, length);
        //assert(max != -INFINITY);
        
        output[o] = max;
    });
    
    return [[[self class] alloc] initWithSamplesNoCopy:output count:outCount freeWhenDone:YES];
}


- (float *) samples
{
    return _samples;
}


- (NSUInteger) count
{
    return _count;
}


@end
