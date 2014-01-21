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


#import "WaveRepresentationView.h"
#import "WaveSampleArray.h"
#import "WaveExplorerView.h"

#import <QuartzCore/QuartzCore.h>

static NSString * const sTileIndexKey = @"tile-index";


@implementation WaveRepresentationView {
    WaveSampleArray *_sampleArray;
    NSInteger        _sampleCount;

    NSMutableArray  *_tileLayers;
    NSIndexSet      *_tileIndices;
    NSInteger        _tileCount;
    
    NSInteger _waitingFirstTileIndex;
    NSInteger _waitingLastTileIndex;
}


- (id) initWithFrame: (NSRect) frameRect
            delegate: (id<WaveRepresentationDelegate>)delegate
           tileCount: (NSUInteger) tileCount
         sampleCount: (NSUInteger) sampleCount
{
    if ((self = [super initWithFrame:frameRect])) {
        _tileCount   = tileCount;
        _sampleCount = sampleCount;
        _delegate    = delegate;
    }
    
    return self;
}


- (CGRect) _frameForTileLayer:(CALayer *)tileLayer
{
    NSInteger tileIndex = [[tileLayer valueForKey:sTileIndexKey] integerValue];

    CGRect bounds = [self bounds];
    
    CGFloat (^xForIndex)(NSInteger) = ^(NSInteger index) {
        if (index == 0) {
            return 0.0;
        } else if (index >= _tileCount) {
            return bounds.size.width;
        } else {
            return (CGFloat)floor((bounds.size.width / _tileCount) * index);
        }
    };
    
    CGRect tileFrame = bounds;
    tileFrame.origin.x   = xForIndex(tileIndex);
    tileFrame.size.width = xForIndex(tileIndex + 1) - tileFrame.origin.x;
    
    return tileFrame;
}


#pragma mark - CALayer Delegate

- (id<CAAction>) actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    return (id)[NSNull null];
}


- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    if (!_sampleArray) return;
    
    NSNumber *indexNumber = [layer valueForKey:sTileIndexKey];
    if (!indexNumber) return;
    
    NSInteger index = [indexNumber integerValue];

    NSColor *foregroundColor = [[self enclosingExplorerView] waveForegroundColor];
    NSColor *backgroundColor = [[self enclosingExplorerView] waveBackgroundColor];

    CGContextSetFillColorWithColor(context, [backgroundColor CGColor]);
    CGContextFillRect(context, [layer bounds]);

    CGContextSetInterpolationQuality(context, kCGInterpolationLow);

    NSInteger sampleCount = [_sampleArray count];
    NSInteger samplesPerTile = sampleCount / _tileCount;

    NSInteger start = (index * samplesPerTile);
    NSInteger end   = (start + samplesPerTile) + 1;
    
    if (start < 0) start = 0;
    if (end > sampleCount) end = sampleCount;

    CGRect bounds = [layer bounds];

    CGAffineTransform transform = CGAffineTransformMakeScale(bounds.size.width / (double)samplesPerTile, 1);

    transform = CGAffineTransformTranslate(transform, -start, 0);

    transform = CGAffineTransformTranslate(transform, 0, bounds.size.height / 2);
    transform = CGAffineTransformScale(transform, 1, bounds.size.height / 2);

    CGContextConcatCTM(context, transform);

    float *samples = [_sampleArray samples];

    // Draw top of waveform
    {
        if (start < end) {
            CGContextMoveToPoint(context, start, samples[start]);
        }

        for (NSInteger i = start + 1; i < end; i++) {
            CGContextAddLineToPoint(context, i, samples[i]);
        }
    }
    
    // Draw bottom of waveform
    {
        for (NSInteger i = end - 1; i >= 0; i--) {
            CGContextAddLineToPoint(context, i, -samples[i]);
        }
    }

    CGContextSetFillColorWithColor(context, [foregroundColor CGColor]);
    CGContextFillPath(context);
}


- (BOOL) layer:(CALayer *)layer shouldInheritContentsScale:(CGFloat)newScale fromWindow:(NSWindow *)window
{
    for (CALayer *tileLayer in _tileLayers) {
        [tileLayer setContentsScale:[window backingScaleFactor]];
        [tileLayer setNeedsDisplay];
    }

    return YES;
}


#pragma mark - State

- (void) _didLoadSampleArray:(WaveSampleArray *)sampleArray
{
    _sampleArray = sampleArray;
    [self _updateFirstTileIndex:_waitingFirstTileIndex lastTileIndex:_waitingLastTileIndex];

    [_delegate waveRepresentationViewDidLoad:self];
}


- (void) loadSampleArray:(WaveSampleArray *)sampleArray
{
    _state = WaveRepresentationStateLoading;

    __weak id weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        WaveSampleArray *smallerSampleArray = [sampleArray sampleArrayWithCount:_sampleCount];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _didLoadSampleArray:smallerSampleArray];
        });
    });
}


- (void) kill
{
    _sampleArray = nil;

    for (CALayer *tileLayer in _tileLayers) {
        [tileLayer removeFromSuperlayer];
    }

    _state = WaveRepresentationStateDead;
}


- (void) enclosingExplorerViewDidUpdateStyle
{
    for (CALayer *tileLayer in _tileLayers) {
        [tileLayer setNeedsDisplay];
    }
}


- (void) updateVisibleTiles
{
    NSRect  visibleRect = [[self enclosingScrollView] documentVisibleRect];
    CGFloat selfWidth   = [self bounds].size.width;

    CGFloat minX = NSMinX(visibleRect);
    CGFloat maxX = NSMaxX(visibleRect);

    NSInteger tileCount = _tileCount;
    
    NSInteger firstTileIndex = floor((minX * tileCount) / selfWidth);
    NSInteger lastTileIndex  = ceil( (maxX * tileCount) / selfWidth);

    // Add additional tile on each side
    firstTileIndex--;
    lastTileIndex++;

    if (firstTileIndex < 0) firstTileIndex = 0;
    if (lastTileIndex >= tileCount) lastTileIndex = tileCount - 1;

    [self _updateFirstTileIndex:firstTileIndex lastTileIndex:lastTileIndex];
}


- (void) _updateFirstTileIndex:(NSInteger)firstTileIndex lastTileIndex:(NSInteger)lastTileIndex
{
    if (!_sampleArray) {
        _waitingFirstTileIndex = firstTileIndex;
        _waitingLastTileIndex  = lastTileIndex;
        return;
    }

    NSRange tileRange = NSMakeRange(firstTileIndex, (lastTileIndex - firstTileIndex) + 1);

    NSIndexSet *newIndices = [[NSIndexSet alloc] initWithIndexesInRange:tileRange];
    NSIndexSet *oldIndices = _tileIndices ? _tileIndices : [NSIndexSet indexSet];

    // Calculate added indices (newTileIndices - oldTileIndices)
    NSMutableIndexSet *addedIndices = [NSMutableIndexSet indexSet];
    [addedIndices addIndexes:newIndices];
    [addedIndices removeIndexes:oldIndices];

    NSMutableArray *tileLayers = [NSMutableArray array];

    // Keep existing tiles
    for (CALayer *tileLayer in _tileLayers) {
        NSInteger tileIndex = [[tileLayer valueForKey:sTileIndexKey] integerValue];

        if (tileIndex >= firstTileIndex && tileIndex <= lastTileIndex) {
            [tileLayers addObject:tileLayer];
        } else {
            [tileLayer setDelegate:nil];
            [tileLayer removeFromSuperlayer];
        }
    }
    
    for (NSInteger i = firstTileIndex; i <= lastTileIndex; i++) {
        if ([addedIndices containsIndex:i]) {
            CALayer *tileLayer = [CALayer layer];
            
            [tileLayer setDelegate:self];
            [tileLayer setValue:@(i) forKey:sTileIndexKey];
            [tileLayer setNeedsDisplay];
            [tileLayer setEdgeAntialiasingMask:0];
            [tileLayer setContentsScale:[[self window] backingScaleFactor]];
            [tileLayer setOpaque:YES];

            [[self layer] addSublayer:tileLayer];
            
            [tileLayers addObject:tileLayer];
        }
    }
    
    for (CALayer *tileLayer in tileLayers) {
        [tileLayer setFrame:[self _frameForTileLayer:tileLayer]];
    }

    _tileLayers  = tileLayers;
    _tileIndices = newIndices;
}


@end
