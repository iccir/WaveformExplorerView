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


#import "WaveExplorerView.h"
#import "WaveChannelView.h"

#import <tgmath.h>


@implementation WaveExplorerView {
    NSScrollView     *_scrollView;
    WaveChannelView  *_channelView;
    CGFloat _magnification;
}


- (id) initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame:frameRect]) {
        [self _setupWaveformView];
    }
    
    return self;
}


- (id) initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self _setupWaveformView];
    }
    
    return self;
}


- (void) _setupWaveformView
{
    _waveBackgroundColor = [NSColor whiteColor];
    _waveForegroundColor = [NSColor blackColor];

    _magnification = 1.0;

    [self setWantsLayer:YES];
    [[self layer] setMasksToBounds:YES];
    
    NSRect bounds = self.bounds;
    
    _scrollView = [[NSScrollView alloc] initWithFrame:bounds];
    [_scrollView setWantsLayer:YES];
    
    [_scrollView setBorderType:NSNoBorder];
    
    [_scrollView setHasHorizontalScroller:YES];
    [_scrollView setHasVerticalScroller:NO];
    [_scrollView setAutohidesScrollers:NO];
    
    [[_scrollView contentView] setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [_scrollView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

    [_scrollView flashScrollers];

    _channelView = [[WaveChannelView alloc] initWithFrame:bounds];
    
    [_scrollView setDocumentView:_channelView];

    [_channelView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

    [self addSubview:_scrollView];

    [_channelView setFrame:bounds];
    [_channelView setMagnification:1.0];
}


- (void) magnifyWithEvent:(NSEvent *)event
{
    CGPoint locationInWindow      = [event locationInWindow];
    CGPoint locationInSelf        = [self convertPoint:locationInWindow fromView:nil];
    CGPoint locationInChannelView = [_channelView convertPoint:locationInWindow fromView:nil];

    CGFloat percentX = locationInChannelView.x / [_channelView frame].size.width;

    _magnification *= ([event magnification] + 1.0);
    if (_magnification < 1.0) _magnification = 1.0;

    NSRect bounds = self.bounds;
    NSRect frame = bounds;
    frame.size.width *= _magnification;
    frame.size.width = floor(frame.size.width);

    [_channelView setFrame:frame];
    [_channelView setMagnification:_magnification];
    
    CGFloat scrollOffset = percentX * frame.size.width - locationInSelf.x;
    [_channelView scrollPoint:CGPointMake(scrollOffset, 0.0)];
}


- (void) endGestureWithEvent:(NSEvent *)event
{
    [_channelView cleanup];
}


#pragma mark - Accessors

- (void) setSampleArray:(WaveSampleArray *)sampleArray
{
    if (_sampleArray != sampleArray) {
        _sampleArray = sampleArray;
        [_channelView setSampleArray:sampleArray];
    }
}

- (void) setWaveForegroundColor:(NSColor *)waveForegroundColor
{
    if (_waveForegroundColor != waveForegroundColor) {
        _waveForegroundColor = waveForegroundColor;
        [_channelView enclosingExplorerViewDidUpdateStyle];
    }
}


- (void) setWaveBackgroundColor:(NSColor *)waveBackgroundColor
{
    if (_waveBackgroundColor != waveBackgroundColor) {
        _waveBackgroundColor = waveBackgroundColor;
        [_channelView enclosingExplorerViewDidUpdateStyle];
    }
}

@end
