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


#import "AppDelegate.h"
#import "WaveSampleArray.h"
#import "WaveExplorerView.h"

#import <AudioToolbox/AudioToolbox.h>

@implementation AppDelegate


- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSString *path = nil;
    
    NSArray *processArguments = [[NSProcessInfo processInfo] arguments];
    
    if (processArguments.count <= 1) {
        path = [[NSBundle mainBundle] pathForResource:@"liberty_bell" ofType:@"m4a"];
    }
    else {
        NSString *rawPath = processArguments[1];
        path = [rawPath stringByExpandingTildeInPath];
    }
	
    NSURL *url = [NSURL fileURLWithPath:path];
    
    __weak id weakSelf = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [weakSelf _loadAudioAtURL:url];
    });
}


- (void) _loadAudioAtURL:(NSURL *)url
{
    ExtAudioFileRef audioFile = NULL;
    OSStatus err = noErr;

    // Open file
    if (err == noErr) {
        err = ExtAudioFileOpenURL((__bridge CFURLRef)url, &audioFile);
        if (err) NSLog(@"ExtAudioFileOpenURL: %ld", (long)err);
    }


    AudioStreamBasicDescription fileFormat = {0};
    UInt32 fileFormatSize = sizeof(fileFormat);

    if (err == noErr) {
        err = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileDataFormat, &fileFormatSize, &fileFormat);
    }


    AudioStreamBasicDescription clientFormat = {0};

    if (err == noErr) {
        UInt32 channels = fileFormat.mChannelsPerFrame;
        
        clientFormat.mSampleRate       = fileFormat.mSampleRate;
        clientFormat.mFormatID         = kAudioFormatLinearPCM;
        clientFormat.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        clientFormat.mBytesPerPacket   = sizeof(float) * channels;
        clientFormat.mFramesPerPacket  = 1;
        clientFormat.mBytesPerFrame    = clientFormat.mFramesPerPacket * clientFormat.mBytesPerPacket;
        clientFormat.mChannelsPerFrame = channels;
        clientFormat.mBitsPerChannel   = sizeof(float) * CHAR_BIT;

        err = ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(clientFormat), &clientFormat);
    }
    
    SInt64 fileLengthFrames = 0;
    UInt32 fileLengthFramesSize = sizeof(fileLengthFrames);
   
    if (err == noErr) {
        err = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileLengthFrames, &fileLengthFramesSize, &fileLengthFrames);
    }
    
    UInt8 *bytes = NULL;
    NSInteger bytesTotal = 0;

    if (err == noErr) {
        NSInteger framesRemaining = fileLengthFrames;
        NSInteger bytesRemaining = framesRemaining * clientFormat.mBytesPerFrame;
        NSInteger bytesRead = 0;

        bytesTotal = bytesRemaining;
        bytes = malloc(bytesTotal);

        while (1 && (err == noErr)) {
            AudioBufferList fillBufferList;
            fillBufferList.mNumberBuffers = 1;
            fillBufferList.mBuffers[0].mNumberChannels = clientFormat.mChannelsPerFrame;
            fillBufferList.mBuffers[0].mDataByteSize = (UInt32)bytesRemaining;
            fillBufferList.mBuffers[0].mData = &bytes[bytesRead];
        
            UInt32 frameCount = (UInt32)framesRemaining;
            err = ExtAudioFileRead(audioFile, &frameCount, &fillBufferList);

            if (frameCount == 0) {
                break;
            }
            
            framesRemaining -= frameCount;
        
            bytesRead       += frameCount * clientFormat.mBytesPerFrame;
            bytesRemaining  -= frameCount * clientFormat.mBytesPerFrame;

            if (framesRemaining == 0) {
                break;
            }
        }
    }
    
    NSData *data = nil;
    if (err == noErr) {
        data = [NSData dataWithBytesNoCopy:bytes length:bytesTotal freeWhenDone:YES];
    } else {
        free(bytes);
    }
    
    __weak id weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf _didLoadWithData:data];
    });

    if (audioFile) {
        ExtAudioFileDispose(audioFile);
    }
}

- (void) _didLoadWithData:(NSData *)data
{
    float *samples = (float *)[data bytes];
    NSUInteger count = [data length] / sizeof(float);
    
    WaveSampleArray *sampleArray = [[WaveSampleArray alloc] initWithSamples:samples count:count];

    [[self waveExplorerView] setSampleArray:sampleArray];
}

@end
