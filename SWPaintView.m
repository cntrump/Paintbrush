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


#import "SWPaintView.h"
#import "SWCenteringClipView.h"
#import "SWScalingScrollView.h"
#import "SWToolList.h"
#import "SWToolbox.h"
#import "SWToolboxController.h"
#import "SWAppController.h"
#import "SWDocument.h"
#import "SWImageDataSource.h"

@implementation SWPaintView

- (void)preparePaintViewWithDataSource:(SWImageDataSource *)ds
                               toolbox:(SWToolbox *)tb
{
    NSAssert(!dataSource, @"No data source when preparing PaintView!");
    NSAssert(!toolbox, @"No toolbox when preparing PainView!");
    dataSource = ds; // Hold on to it!
    toolbox = tb; // This one too!
    
    // First things first: make sure we are the right size!
    NSRect frameRect = NSMakeRect(0.0, 0.0, ds.size.width, ds.size.height);
    self.frame = frameRect;
    
    toolboxController = [SWToolboxController sharedToolboxPanelController];
    isPayingAttention = YES;
        
    // Tracking area
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.frame
                                                        options: NSTrackingMouseMoved | NSTrackingCursorUpdate
                            | NSTrackingEnabledDuringMouseDrag | NSTrackingActiveWhenFirstResponder
                                                          owner:self
                                                       userInfo:nil]];
    [self.window setAcceptsMouseMovedEvents:YES];
        
    // Grid related
    showsGrid = NO;
    gridSpacing = 1;
    gridColor = [NSColor gridColor];
    
    // Ensure the correct cursor is displayed when opening a new document
    [self cursorUpdate:nil];
    
    // Set up drag stuff
    [self.window registerForDraggedTypes:@[NSPasteboardTypeTIFF]];
    
    [self setNeedsDisplay:YES];    
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.undoManager removeAllActions]; 
    // Note: do NOT release the current tool, as it is just a pointer to the
    // object inherited from ToolboxController
}


- (NSRect)calculateWindowBounds:(NSRect)frameRect
{
    // Set the window's maximum size to the size of the screen
    // Does not seem to work all the time
    NSRect screenRect = [NSScreen mainScreen].frame;
    
    // Center the shrunken/enlarged window with respect to its initial location
    NSRect tempRect = [super.window frameRectForContentRect:frameRect];
    NSPoint newOrigin = super.window.frame.origin;
    
    tempRect.size.width += [NSScroller scrollerWidth];
    tempRect.size.height += [NSScroller scrollerWidth];
    
    newOrigin.y += floor(0.5 * (super.window.frame.size.height - tempRect.size.height));
    newOrigin.x += floor(0.5 * (super.window.frame.size.width - tempRect.size.width));
    tempRect.origin = newOrigin;
    
    // Ensures that the document is never wider than the screen
    tempRect.size.width = MIN(screenRect.size.width, tempRect.size.width);
    
    // Assert some minimum and maximum values!
    tempRect.size.width = MAX([[super window] minSize].width, tempRect.size.width);
    tempRect.size.height = MAX([[super window] minSize].height, tempRect.size.height);
    
    tempRect.origin.x = MAX(tempRect.origin.x, 0);
    
    return tempRect;
}


- (void)drawRect:(NSRect)rect
{
    if (rect.size.width != 0 && rect.size.height != 0)
    {
        [NSGraphicsContext saveGraphicsState];

        // If you don't do this, the image looks blurry when zoomed in
        [NSGraphicsContext currentContext].imageInterpolation = NSImageInterpolationNone;
        CGContextRef cgContext = [NSGraphicsContext currentContext].CGContext;
        NSBitmapImageRep *mainImage = dataSource.mainImage;
        NSBitmapImageRep *bufferImage = dataSource.bufferImage;
        
        //CGContextBeginTransparencyLayer(cgContext, NULL);
        
        // Draw the NSBitmapImageRep to the view
        if (mainImage) 
            CGContextDrawImage(cgContext, NSRectToCGRect(self.bounds), mainImage.CGImage);
        
        // If there's an overlay image being used at the moment, draw it
        if (bufferImage) 
        {
            NSRect rect = (NSRect){ NSZeroPoint, bufferImage.size };
            CGContextDrawImage(cgContext, NSRectToCGRect(rect), bufferImage.CGImage);
        }
        
        //CGContextEndTransparencyLayer(cgContext);
        
        // If the grid is turned on, draw that too (but only after everything else!
        if (showsGrid && [(SWScalingScrollView *)self.superview.superview scaleFactor] > 2.0) 
        {
            [gridColor set];
            [[NSGraphicsContext currentContext] setShouldAntialias:NO];
            [[self gridInRect:self.frame] stroke];
        }
        
        [NSGraphicsContext restoreGraphicsState];
    }
}


+ (NSMenu *)defaultMenu 
{
    //NSMenu *theMenu = [super initWithWindowNibName:@"Preferences"];
    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@""];
    [theMenu insertItemWithTitle:NSLocalizedString(@"Cut", @"Cut the selection") 
                          action:@selector(cut:) 
                   keyEquivalent:@"" 
                         atIndex:0];
    [theMenu insertItemWithTitle:NSLocalizedString(@"Copy", @"Copy the selection") 
                          action:@selector(copy:) 
                   keyEquivalent:@"" 
                         atIndex:1];
    [theMenu insertItemWithTitle:NSLocalizedString(@"Paste", @"Paste the contents of the clipboard") 
                          action:@selector(paste:) 
                   keyEquivalent:@"" 
                         atIndex:2];
    [theMenu insertItem:[NSMenuItem separatorItem] 
                atIndex:3];
    [theMenu insertItemWithTitle:NSLocalizedString(@"Zoom In", @"Increase the zoom level")
                          action:@selector(zoomIn:) 
                   keyEquivalent:@"" 
                         atIndex:4];
    [theMenu insertItemWithTitle:NSLocalizedString(@"Zoom Out", @"Decrese the zoom level")
                          action:@selector(zoomOut:)
                   keyEquivalent:@"" 
                         atIndex:5];
    [theMenu insertItemWithTitle:NSLocalizedString(@"Actual Size", @"Restore the zoom level to 100%")
                          action:@selector(actualSize:) 
                   keyEquivalent:@"" 
                         atIndex:6];
    return theMenu;
}


#pragma mark Mouse/keyboard events: the cornerstone of the drawing process

////////////////////////////////////////////////////////////////////////////////
//////////        Mouse/keyboard events: the cornerstone of the drawing process
////////////////////////////////////////////////////////////////////////////////


- (void)mouseDown:(NSEvent *)event
{
    isPayingAttention = YES;
    NSPoint p = event.locationInWindow;
    NSPoint downPoint = [self convertPoint:p fromView:nil];
    
    // Necessary for when the view is zoomed above 100%
    currentPoint.x = floor(downPoint.x);
    currentPoint.y = floor(downPoint.y);

    [toolbox.currentTool setSavedPoint:currentPoint];
    
    // If it's shifted, do something about it
    toolbox.currentTool.flags = event.modifierFlags;
    [toolbox.currentTool performDrawAtPoint:currentPoint 
                      withMainImage:dataSource.mainImage
                        bufferImage:dataSource.bufferImage
                         mouseEvent:MOUSE_DOWN];
    
    [self setNeedsDisplayInRect:[toolbox.currentTool invalidRect]];
}

- (void)mouseDragged:(NSEvent *)event
{
    if (isPayingAttention) 
    {
        NSPoint p = event.locationInWindow;
        NSPoint dragPoint = [self convertPoint:p fromView:nil];
        
        // Necessary for when the view is zoomed above 100%
        currentPoint.x = floor(dragPoint.x);
        currentPoint.y = floor(dragPoint.y);
        
        toolbox.currentTool.flags = event.modifierFlags;
        [toolbox.currentTool performDrawAtPoint:currentPoint 
                                    withMainImage:dataSource.mainImage
                                      bufferImage:dataSource.bufferImage
                                       mouseEvent:MOUSE_DRAGGED];
        
        [self setNeedsDisplayInRect:[toolbox.currentTool invalidRect]];
    }
}

- (void)mouseUp:(NSEvent *)event
{
    if (isPayingAttention) 
    {
        NSPoint p = event.locationInWindow;
        NSPoint upPoint = [self convertPoint:p fromView:nil];
        
        // Necessary for when the view is zoomed above 100%
        currentPoint.x = floor(upPoint.x);
        currentPoint.y = floor(upPoint.y);
        toolbox.currentTool.flags = event.modifierFlags;
        NSBezierPath *path = [toolbox.currentTool performDrawAtPoint:currentPoint 
                                                         withMainImage:dataSource.mainImage
                                                           bufferImage:dataSource.bufferImage
                                                            mouseEvent:MOUSE_UP];
        
        if (path) {
            expPath = path;
        }
        
        [self setNeedsDisplayInRect:[toolbox.currentTool invalidRect]];
    }
}

// We want right-clicks to result in the use of the background color
- (void)rightMouseDown:(NSEvent *)theEvent
{
    NSUInteger flags = theEvent.modifierFlags | 
    ([toolbox.currentTool shouldShowContextualMenu] ? NSEventModifierFlagControl : NSEventModifierFlagOption);
    
    NSEvent *modifiedEvent = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                                                location:theEvent.locationInWindow 
                                           modifierFlags:flags
                                               timestamp:theEvent.timestamp
                                            windowNumber:theEvent.windowNumber
                                                 context:theEvent.context
                                             eventNumber:theEvent.eventNumber
                                              clickCount:theEvent.clickCount
                                                pressure:theEvent.pressure];
    [NSApp postEvent:modifiedEvent atStart:YES];
}

- (void)rightMouseDragged:(NSEvent *)theEvent
{
    NSUInteger flags = theEvent.modifierFlags | 
    ([toolbox.currentTool shouldShowContextualMenu] ? NSEventModifierFlagControl : NSEventModifierFlagOption);
    
    NSEvent *modifiedEvent = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDragged
                                                location:theEvent.locationInWindow 
                                           modifierFlags:flags
                                               timestamp:theEvent.timestamp
                                            windowNumber:theEvent.windowNumber
                                                 context:theEvent.context
                                             eventNumber:theEvent.eventNumber
                                              clickCount:theEvent.clickCount
                                                pressure:theEvent.pressure];
    [NSApp postEvent:modifiedEvent atStart:YES];
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
    NSUInteger flags = theEvent.modifierFlags | 
    ([toolbox.currentTool shouldShowContextualMenu] ? NSEventModifierFlagControl : NSEventModifierFlagOption);
    
    NSEvent *modifiedEvent = [NSEvent mouseEventWithType:NSEventTypeLeftMouseUp
                                                location:theEvent.locationInWindow 
                                           modifierFlags:flags
                                               timestamp:theEvent.timestamp
                                            windowNumber:theEvent.windowNumber
                                                 context:theEvent.context
                                             eventNumber:theEvent.eventNumber
                                              clickCount:theEvent.clickCount
                                                pressure:theEvent.pressure];
    [NSApp postEvent:modifiedEvent atStart:YES];
}


// Currently only necessary for the text tool, but we'll see where we go with it
- (void)mouseMoved:(NSEvent *)event
{
    NSPoint p = event.locationInWindow;
    NSPoint motionPoint = [self convertPoint:p fromView:nil];
    
    // Necessary for when the view is zoomed above 100%
    motionPoint.x = floor(motionPoint.x) + 0.5;
    motionPoint.y = floor(motionPoint.y) + 0.5;    
    [toolbox.currentTool mouseHasMoved:motionPoint];
}


// Overridden to set the correct cursor
- (void)cursorUpdate:(NSEvent *)event
{
    if (toolbox && toolbox.currentTool) 
    {
        NSCursor *cursor = [toolbox.currentTool cursor];
        ((NSClipView *)self.superview).documentCursor = cursor;
        [cursor push];
    }
    else
        [super cursorUpdate:event];
}


// Handles keyboard events
- (void)keyDown:(NSEvent *)event
{
    // Escape key
    if (event.keyCode == 53) 
    {
        isPayingAttention = NO;
        [toolbox tieUpLooseEndsForCurrentTool];
        [SWImageTools clearImage:dataSource.bufferImage];
        [self setNeedsDisplay:YES];
    } 
    else if (event.keyCode == 51 || event.keyCode == 117) 
    {
        // Delete keys (back and forward)
        [self clearOverlay];
    } 
    else
    {
        [toolboxController.window.contentView keyDown:event];
    }
}


#pragma mark MyDocument tells PaintView this information from the Toolbox

////////////////////////////////////////////////////////////////////////////////
//////////        MyDocument tells PaintView this information from the Toolbox
////////////////////////////////////////////////////////////////////////////////


- (void)setBackgroundColor:(NSColor *)color
{
    backgroundColor = color;
}


////////////////////////////////////////////////////////////////////////////////
//////////      Grid-Related Methods
////////////////////////////////////////////////////////////////////////////////


// Generates the NSBezeierPath used as the grid
- (NSBezierPath *)gridInRect:(NSRect)rect
{
    NSUInteger curLine, endLine;
    NSBezierPath *gridPath = [NSBezierPath bezierPath];
    
    // Columns
    curLine = ceil((NSMinX(rect)) / gridSpacing) + 1;
    endLine = ceil((NSMaxX(rect)) / gridSpacing) - 1;
    for (; curLine<=endLine; curLine++) {
        [gridPath moveToPoint:NSMakePoint((curLine * gridSpacing), NSMinY(rect))];
        [gridPath lineToPoint:NSMakePoint((curLine * gridSpacing), NSMaxY(rect))];
    }
    
    // Rows
    curLine = ceil((NSMinY(rect)) / gridSpacing) + 1;
    endLine = ceil((NSMaxY(rect)) / gridSpacing) - 1;
    for (; curLine<=endLine; curLine++) {
        [gridPath moveToPoint:NSMakePoint(NSMinX(rect), (curLine * gridSpacing))];
        [gridPath lineToPoint:NSMakePoint(NSMaxX(rect), (curLine * gridSpacing))];
    }
    
    //[gridPath setLineWidth:0.5];
    gridPath.lineWidth = (1.0 / [(SWScalingScrollView *)self.superview.superview scaleFactor]);
    //[gridPath stroke];
    return gridPath;
}

// Switch the grid, if it isn't already the same as the parameter
- (void)setShowsGrid:(BOOL)shouldShowGrid 
{
    if (shouldShowGrid != showsGrid) {
        showsGrid = !showsGrid;
        [self setNeedsDisplay:YES];
    }
}

// Change the spacing of the grid, based off the slider in the GridController
- (void)setGridSpacing:(CGFloat)newGridSpacing 
{
    if (gridSpacing != newGridSpacing) {
        gridSpacing = newGridSpacing;
        [self setNeedsDisplay: YES];
    }
}

// Change the color of the grid from the default gray
- (void)setGridColor:(NSColor *)newGridColor 
{
    gridColor = newGridColor;
    [self setNeedsDisplay: YES];
}

// Should the grid be shown? Hmm...
- (BOOL)showsGrid 
{
    return showsGrid;
}

// Returns the spacing of the grid
- (CGFloat)gridSpacing 
{
    return gridSpacing;
}

// If there is a grid color, return it... otherwise, go with light gray
- (NSColor *)gridColor 
{
    return gridColor;
}

#pragma mark Miscellaneous

////////////////////////////////////////////////////////////////////////////////
//////////        Miscellaneous
////////////////////////////////////////////////////////////////////////////////


// Releases the overlay image, then tells the tool about it
- (void)clearOverlay
{
    [SWImageTools clearImage:dataSource.bufferImage];
    [toolbox.currentTool deleteKey];
    [toolbox tieUpLooseEndsForCurrentTool];
    [self setNeedsDisplay:YES];
}

// Tells the mainImage to refresh itself. Can be called from anywhere in the application.
- (void)refreshImage:(id)sender
{
    if (sender)
        [self setNeedsDisplayInRect:[sender invalidRect]];
    else
        [self setNeedsDisplay:YES];
}


// Doesn't work...?
//- (NSPoint)currentMouseLocation
//{
//    // Get the point in screen coordinates
//    NSPoint screenCoord = [NSEvent mouseLocation];
//    
//    // Convert it to base coordinates
//    NSPoint baseCoord = [[self window] convertScreenToBase:screenCoord];
//    
//    // Convert it to view coordinates and return
//    NSPoint viewCoord = [self convertPointFromBase:baseCoord];
//    return viewCoord;
//}


// We can't promise we're opaque!
- (BOOL)isOpaque
{
    return NO;
}


// Necessary to allow keyboard events and stuff
- (BOOL)acceptsFirstResponder
{
    return YES;
}


- (BOOL)isFlipped
{
    return YES;
}

@end
