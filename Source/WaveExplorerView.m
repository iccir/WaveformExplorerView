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

#import "NSScrollView+JXSizeExtensions.h"

#import <tgmath.h>

@interface WaveExplorerView ()
@property (nonatomic, assign) CGFloat magnification;
@end

@implementation WaveExplorerView {
    NSScrollView     *_scrollView;
    WaveChannelView  *_channelView;
    CGFloat _magnification;
}


- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    
    if (self) {
        [self _setupWaveformView];
    }
    
    return self;
}


- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
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

    NSRect contentRect = [_scrollView contentRectForFrameRectJX:bounds];
    
    _channelView = [[WaveChannelView alloc] initWithFrame:contentRect];
    
    [_scrollView setDocumentView:_channelView];

    [_channelView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

    [self addSubview:_scrollView];

    [_channelView setFrame:contentRect];
    [_channelView setMagnification:1.0];
}


#pragma mark *** Key Event Handling ***

// Make us able to -becomeFirstResponder, so we can receive key events.
- (BOOL) acceptsFirstResponder
{
    return YES;
}

- (void) keyDown:(NSEvent *)event
{
    BOOL didProcess = NO;
    
    NSString *characters = [event characters];
    if (characters && ([characters length] > 0)) {
        unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];
        
        if (((key == '+') || (key == '-'))) {
            NSRect bounds = self.bounds;
            CGPoint locationInSelf = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
            switch (key) {
                case '+':
                    [self increaseMagnification];
                    
                    [self scrollAndZoomForLocationInSelf:locationInSelf
                                           exactLocation:NO];
                    
                    didProcess = YES;
                    break;
                    
                case '-':
                    [self decreaseMagnification];
                    
                    [self scrollAndZoomForLocationInSelf:locationInSelf
                                           exactLocation:NO];
                    
                    didProcess = YES;
                    break;
                    
                default:
                    break;
            }
        }
    }
    
    if (didProcess == NO) {
        return [super keyDown:event];
    }
}


#pragma mark *** Mouse Event Handling ***

// Always receive -mouseDown: messages for clicks that occur in our view,
// even if the click is one that’s activating the window.
// This lets the user start interacting with the contents without having to click again.
- (BOOL) acceptsFirstMouse
{
    return YES;
}

// User clicked the main mouse button inside our view.
- (void) mouseDown:(NSEvent *)event
{
    NSEventModifierFlags modifierFlags = [event modifierFlags];
    if (modifierFlags & NSCommandKeyMask) {
        if ((modifierFlags & NSShiftKeyMask)) {
            [self decreaseMagnification];
        } else {
            [self increaseMagnification];
        }
        
        [self scrollAndZoomForEvent:event];
    }

    // Make us the window’s firstResponder when clicked.
    [[self window] makeFirstResponder:self];
}



#pragma mark *** Zoom/Scroll Utilities ***

- (void) increaseMagnification
{
    self.magnification *= 2.0;
}

- (void) decreaseMagnification
{
    self.magnification /= 2.0;
}

- (void) scrollAndZoomForEvent:(NSEvent *)event
{
    CGPoint locationInWindow      = [event locationInWindow];
    CGPoint locationInSelf        = [self convertPoint:locationInWindow fromView:nil];
    
    BOOL isExactLocation = YES;
    
    [self scrollAndZoomForLocationInSelf:locationInSelf
                           exactLocation:isExactLocation];
}

- (void) scrollAndZoomForLocationInSelf:(CGPoint)locationInSelf
                          exactLocation:(BOOL)isExactLocation
{
    CGPoint locationInChannelView = [_channelView convertPoint:locationInSelf fromView:self];
    CGFloat channelViewWidth = [_channelView frame].size.width;
    
    BOOL isNearBeginning = NO;
    BOOL isNearEnd = NO;
    
    BOOL snapToEnds = YES;
    
    if (snapToEnds && (isExactLocation == NO)) {
        // Determine, if our viewport touches the beginning or end of the channel view.
        // We could make this fuzzy.
        CGRect bounds = self.bounds;
        CGRect selfBoundsInChannelView = [_channelView convertRect:bounds fromView:self];
        if (CGRectGetMinX(selfBoundsInChannelView) == 0.0) {
            isNearBeginning = YES;
        } else if (CGRectGetMaxX(selfBoundsInChannelView) == channelViewWidth) {
            isNearEnd = YES;
        }
    }
    
    CGFloat percentX;
    if (isNearBeginning) {
        percentX = 0.0;
    }
    else if (isNearEnd) {
        percentX = 1.0;
    }
    else {
        percentX = locationInChannelView.x / channelViewWidth;
    }

    NSRect bounds = self.bounds;
    NSRect frame = [_scrollView contentRectForFrameRectJX:bounds];
    frame.size.width *= _magnification;
    frame.size.width = floor(frame.size.width);
    
    [_channelView setFrame:frame];
    [_channelView setMagnification:_magnification];
    
    CGFloat scrollOffset = percentX * frame.size.width - locationInSelf.x;
    [_channelView scrollPoint:CGPointMake(scrollOffset, 0.0)];
}


#pragma mark *** Gesture Event Handling ***

- (void) magnifyWithEvent:(NSEvent *)event
{
    self.magnification *= ([event magnification] + 1.0);

    [self scrollAndZoomForEvent:event];
}

- (void) endGestureWithEvent:(NSEvent *)event
{
    [_channelView cleanup];
}


#pragma mark - Accessors

- (CGFloat) magnification
{
    return _magnification;
}

- (void) setMagnification:(CGFloat)magnification
{
    if (_magnification != magnification) {
        _magnification = magnification;
        // Limit to maximum zoom!
        _magnification = MAX(_magnification, 1.0);
    }
}

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
