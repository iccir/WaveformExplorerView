//
//  NSScrollView+JXSizeExtensions.h
//  WaveformExplorerView
//
//  Created by Jan on 03.11.14.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSScrollView (JXSizeExtensions)

- (NSSize) contentSizeForFrameSizeJX:(NSSize)scrollViewFrameSize;
- (NSRect) contentRectForFrameRectJX:(NSRect)bounds;

- (NSSize) frameSizeForContentSizeJX:(NSSize)contentSize;

@end
