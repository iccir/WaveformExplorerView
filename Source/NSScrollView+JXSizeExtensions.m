//
//  NSScrollView+JXSizeExtensions.m
//  WaveformExplorerView
//
//  Created by Jan on 03.11.14.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "NSScrollView+JXSizeExtensions.h"

@implementation NSScrollView (JXSizeExtensions)

NS_INLINE NSControlSize controlSizeForScrollViewWithScrollers(NSScrollView *scrollView, NSScroller **horizontalScroller_p, NSScroller **verticalScroller_p) {
    NSScroller *horizontalScroller = nil;
    NSScroller *verticalScroller = nil;
    NSControlSize controlSize = NSRegularControlSize;
    
    if (scrollView.hasHorizontalScroller) {
        horizontalScroller = scrollView.horizontalScroller;
        controlSize = horizontalScroller.controlSize;
    }
    
    if (scrollView.hasVerticalScroller) {
        verticalScroller = scrollView.verticalScroller;
        NSControlSize verticalControlSize = NSRegularControlSize;
        verticalControlSize = verticalScroller.controlSize;
        
        if ((horizontalScroller != nil) &&
            (controlSize != verticalControlSize)) {
            NSLog(@"Horizontal and vertical controlSize should match in NSScrollView.");
        }
        else {
            controlSize = verticalControlSize;
        }
    }
    
    if (horizontalScroller_p != NULL) {
        *horizontalScroller_p = horizontalScroller;
    }
    
    if (verticalScroller_p != NULL) {
        *verticalScroller_p = verticalScroller;
    }
    
    return controlSize;
}


- (NSSize) contentSizeForFrameSizeJX:(NSSize)scrollViewFrameSize;
{
    NSScroller *horizontalScroller = nil;
    NSScroller *verticalScroller = nil;
    NSControlSize controlSize = controlSizeForScrollViewWithScrollers(self, &horizontalScroller, &verticalScroller);
    
    return [[self class] contentSizeForFrameSize:scrollViewFrameSize
                         horizontalScrollerClass:horizontalScroller.class
                           verticalScrollerClass:verticalScroller.class
                                      borderType:self.borderType
                                     controlSize:controlSize
                                   scrollerStyle:self.scrollerStyle];
}

- (NSRect) contentRectForFrameRectJX:(NSRect)bounds;
{
    NSSize boundsSize = bounds.size;
    
    NSSize contentSize = [self contentSizeForFrameSizeJX:boundsSize];
    NSRect contentRect = bounds;
    contentRect.size = contentSize;
    
    return contentRect;
}


- (NSSize) frameSizeForContentSizeJX:(NSSize)contentSize;
{
    NSScroller *horizontalScroller = nil;
    NSScroller *verticalScroller = nil;
    NSControlSize controlSize = controlSizeForScrollViewWithScrollers(self, &horizontalScroller, &verticalScroller);
    
    return [[self class] frameSizeForContentSize:contentSize
                         horizontalScrollerClass:horizontalScroller.class
                           verticalScrollerClass:verticalScroller.class
                                      borderType:self.borderType
                                     controlSize:controlSize
                                   scrollerStyle:self.scrollerStyle];
}

@end