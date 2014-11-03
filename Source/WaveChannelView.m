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


#import "WaveChannelView.h"
#import "WaveRepresentationView.h"

#import <tgmath.h>


@interface WaveChannelView () <WaveRepresentationDelegate>
@end


@implementation WaveChannelView {
    WaveRepresentationView *_activeRepresentation;
    NSMutableArray *_representations;
}

- (void) setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    
    for (WaveRepresentationView *rep in _representations) {
        [rep updateVisibleTiles];
    }
}


- (NSRect) adjustScroll:(NSRect)newVisible
{
    for (WaveRepresentationView *rep in _representations) {
        [rep updateVisibleTiles];
    }

    return newVisible;
}


- (void) enclosingExplorerViewDidUpdateStyle
{
    for (WaveRepresentationView *rep in _representations) {
        [rep enclosingExplorerViewDidUpdateStyle];
    }
}


- (void) _makeRepresentationForMagnification
{
    if (!_sampleArray) return;

    NSInteger newTileCount = pow((CGFloat)2, floor(log2(ceil(_magnification))));

    if ([_activeRepresentation tileCount] != newTileCount) {
        NSInteger sampleCount = [[self enclosingScrollView] frame].size.width * newTileCount;

        WaveRepresentationView *rep = [[WaveRepresentationView alloc] initWithFrame:self.bounds
                                                                           delegate:self
                                                                          tileCount:newTileCount
                                                                        sampleCount:sampleCount];

        if (!_representations) _representations = [NSMutableArray array];
        [_representations addObject:rep];

        [rep loadSampleArray:_sampleArray];
        
        _activeRepresentation = rep;
    }
}


- (void) setMagnification:(CGFloat)magnification
{
    if (_magnification != magnification) {
        _magnification = magnification;

        [self _makeRepresentationForMagnification];

        for (WaveRepresentationView *rep in _representations) {
            [rep updateVisibleTiles];
        }
    }
}

- (void) cleanup
{
    NSMutableArray *deadReps = [NSMutableArray array];

    for (WaveRepresentationView *rep in _representations) {
        if ([rep state] == WaveRepresentationStateDead) {
            [deadReps addObject:rep];
        }
    }

    [_representations removeObjectsInArray:deadReps];
}


- (void) waveRepresentationViewDidLoad:(WaveRepresentationView *)rep
{
    if (rep == _activeRepresentation) {
        [rep setFrame:[self bounds]];
        [rep setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
        
        [self addSubview:rep];

        for (WaveRepresentationView *otherRep in _representations) {
            if (otherRep != _activeRepresentation) {
                // [otherRep removeFromSuperview] would be easier
                // Unfortuately, this ends the current magnify event?
                // Hence the kill/dead system
                //
                [otherRep kill];
            }
        }

        for (WaveRepresentationView *rep in _representations) {
            [rep updateVisibleTiles];
        }
    }
}


- (void) setSampleArray:(WaveSampleArray *)sampleArray
{
    if (_sampleArray != sampleArray) {
        _sampleArray = sampleArray;
        [self _makeRepresentationForMagnification];
    }
}


@end

