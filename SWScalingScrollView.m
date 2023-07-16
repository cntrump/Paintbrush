/**
 * Paintbrush
 * Copyright (C) 2007-2019  Michael Schreiber
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


#import "SWScalingScrollView.h"
#import "SWCenteringClipView.h"
#import "SWDocument.h"

static NSString *scaleMenuLabels[] = { @"25%", @"50%", @"100%", @"200%", @"400%", @"800%", @"1600%"};
static CGFloat scaleMenuFactors[] = { 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0};
static unsigned defaultIndex = 2;

@implementation SWScalingScrollView

- (instancetype)initWithFrame:(NSRect)rect 
{
    if ((self = [super initWithFrame:rect])) {
        scaleFactor = 1.0;
    }
    return self;
}


- (void)makeScalePopUpButton 
{
    if (scalePopUpButton == nil) {
        unsigned cnt, numberOfDefaultItems = (sizeof(scaleMenuLabels) / sizeof(NSString *));
        id curItem;
        
        // create it
        scalePopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 1.0, 1.0) pullsDown:NO];
        ((NSPopUpButtonCell *)scalePopUpButton.cell).bezelStyle = NSBezelStyleShadowlessSquare;
        //[scalePopUpButton setBezelStyle:NSShadowlessSquareBezelStyle];
        [scalePopUpButton.cell setArrowPosition:NSPopUpArrowAtBottom];
        
        // fill it
        for (cnt = 0; cnt < numberOfDefaultItems; cnt++) {
            [scalePopUpButton addItemWithTitle:NSLocalizedString(scaleMenuLabels[cnt], nil)];
            curItem = [scalePopUpButton itemAtIndex:cnt];
            if (scaleMenuFactors[cnt] != 0.0) {
                [curItem setRepresentedObject:[NSNumber numberWithFloat:scaleMenuFactors[cnt]]];
            }
        }
        [scalePopUpButton selectItemAtIndex:defaultIndex];
        
        // hook it up
        scalePopUpButton.target = self;
        scalePopUpButton.action = @selector(scalePopUpAction:);
        
        // set a suitable font
        scalePopUpButton.font = [NSFont controlContentFontOfSize:[NSFont smallSystemFontSize]];
        
        // Make sure the popup is big enough to fit the cells.
        [scalePopUpButton sizeToFit];
        
        // don't let it become first responder
        [scalePopUpButton setRefusesFirstResponder:YES];
        
        // put it in the scrollview
        [self addSubview:scalePopUpButton];
    }
}

- (void)tile 
{
    // Let the superclass do most of the work.
    [super tile];
    
    if (!self.hasHorizontalScroller) {
        if (scalePopUpButton) [scalePopUpButton removeFromSuperview];
        scalePopUpButton = nil;
    } else {
        NSScroller *horizScroller;
        NSRect horizScrollerFrame, buttonFrame;
        
        if (!scalePopUpButton) {
            [self makeScalePopUpButton];
        }
        
        horizScroller = self.horizontalScroller;
        horizScrollerFrame = horizScroller.frame;
        buttonFrame = scalePopUpButton.frame;
        
        // Now we'll just adjust the horizontal scroller size and set the button size and location.
        horizScrollerFrame.size.width = horizScrollerFrame.size.width - buttonFrame.size.width;
        horizScrollerFrame.origin.x = buttonFrame.size.width;
        horizScroller.frame = horizScrollerFrame;

        // Puts it on the left
        buttonFrame.origin.x = 0;
        buttonFrame.size.height = horizScrollerFrame.size.height + 1.0;
        buttonFrame.origin.y = self.bounds.size.height - buttonFrame.size.height + 1.0;
        scalePopUpButton.frame = buttonFrame;
    }
}

- (void)scalePopUpAction:(id)sender 
{
    NSNumber *selectedFactorObject = [[sender selectedCell] representedObject];
    
    if (selectedFactorObject == nil) {
        DebugLog(@"Scale popup action: setting arbitrary zoom factors is not yet supported.");
        return;
    } else {
        [self setScaleFactor:selectedFactorObject.floatValue adjustPopup:NO];
    }
}

- (CGFloat)scaleFactor 
{
    return scaleFactor;
}

// Used by the Zoom tool: zooms and centers on a specific point
- (void)setScaleFactor:(CGFloat)factor atPoint:(NSPoint)point adjustPopup:(BOOL)flag
{
    [self setScaleFactor:factor adjustPopup:flag];
    
    SWCenteringClipView *clipView = (SWCenteringClipView *)self.documentView.superview;
    NSSize size = clipView.bounds.size;

    // Sets the top-left corner to the point clicked
    // NO NEED WHEN THE VIEW IS FLIPPED, as it is starting with v2.1
//    point.y = [clipView documentRect].size.height - point.y - 1;
    
    // Scroll to the correct centered spot thing
    point.x -= size.width / 2;
    point.y -= size.height / 2;
    [clipView setBoundsOrigin:[clipView constrainScrollPoint:point]];
}


- (void)setScaleFactor:(CGFloat)newScaleFactor adjustPopup:(BOOL)flag 
{
    if (scaleFactor != newScaleFactor) {
        NSSize curDocFrameSize, newDocBoundsSize, curDocBoundsSize;
        NSPoint newDocBoundsOrigin;
        // Make a backup!
        //CGFloat oldScaleFactor = scaleFactor;
        
        SWCenteringClipView *clipView = (SWCenteringClipView *)self.documentView.superview;
        
        if (flag) {    // Coming from elsewhere, first validate it
            NSInteger cnt = 0, numberOfDefaultItems = (sizeof(scaleMenuFactors) / sizeof(CGFloat));
            
            // We only work with the preset zoom values, so choose one of the appropriate values 
            //  (Fudge a little for floating point comparison to work)
            while (cnt < numberOfDefaultItems && newScaleFactor * .99 > scaleMenuFactors[cnt]) {
                cnt++;
            }
            if (cnt == numberOfDefaultItems) {
                cnt--;
                return;
            }
            [scalePopUpButton selectItemAtIndex:cnt];
            scaleFactor = scaleMenuFactors[cnt];
        } else {
            scaleFactor = newScaleFactor;
        }
                
        // Get the frame.  The frame must stay the same.
        curDocFrameSize = clipView.frame.size;
        
        // Get the size for fun calculations
        curDocBoundsSize = clipView.bounds.size;
        
        // The new bounds will be frame divided by scale factor
        newDocBoundsSize.width = curDocFrameSize.width / scaleFactor;
        newDocBoundsSize.height = curDocFrameSize.height / scaleFactor;
                
        // Likewise, adjust the bottom-left corner to maintain centered-ness
        newDocBoundsOrigin.x = clipView.bounds.origin.x + (curDocBoundsSize.width - newDocBoundsSize.width) / 2;
        newDocBoundsOrigin.y = clipView.bounds.origin.y + (curDocBoundsSize.height - newDocBoundsSize.height) / 2;

        // Finally, inform the clip view of the changes we've made        
        [clipView setBoundsSize:newDocBoundsSize];
        [clipView setBoundsOrigin:newDocBoundsOrigin];
        
        // Make sure the window size is correct
        NSRect frame = self.window.frame;
                
        // Initially constrain the window size
        if (scaleFactor > 1.0) {
            NSRect contentRect = [self.window contentRectForFrameRect:NSMakeRect(0,0,frame.size.width-[NSScroller scrollerWidth],
                                                                                   frame.size.height-[NSScroller scrollerWidth])];
            contentRect.size.width =  round(contentRect.size.width / scaleFactor) * scaleFactor + [NSScroller scrollerWidth];
            contentRect.size.height = round(contentRect.size.height / scaleFactor) * scaleFactor + [NSScroller scrollerWidth];
            
            NSRect newRect = [self.window frameRectForContentRect:contentRect];
            
            frame.size = newRect.size;
        }
        
        CGFloat factor = fmax(1.0, scaleFactor);
        self.window.resizeIncrements = NSMakeSize(factor, factor);
        [self.window setFrame:frame display:YES animate:YES];
        
        // Constrain the origin
        [clipView setBoundsOrigin:[clipView constrainScrollPoint:clipView.bounds.origin]];
    }
}

- (BOOL)isFlipped
{
    return YES;
}

@end
