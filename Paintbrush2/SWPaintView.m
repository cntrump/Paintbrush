/**
 * Copyright 2007, 2008 Soggy Waffles
 *
 * This file is part of Paintbrush.
 *
 * Paintbrush is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Paintbrush is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Paintbrush; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */


#import "SWPaintView.h"
#import "SWCenteringClipView.h"
#import "SWScalingScrollView.h"

@implementation SWPaintView

- (id)initWithFrame:(NSRect)frameRect animate:(BOOL)shouldAnimate
{	
	if (self = [super initWithFrame:frameRect]) {
		toolbox = [SWToolboxController sharedToolboxPanelController];
		isPayingAttention = YES;
		mainImage = [[NSImage alloc] initWithSize:frameRect.size];
		
		// New document, not an opened image: gotta paint the background color
		[mainImage lockFocus];
		[[toolbox backgroundColor] set];
		[NSBezierPath fillRect:frameRect];
		[mainImage unlockFocus];
		
		secondImage = [[NSImage alloc] initWithSize:frameRect.size];	
		
		// Use external method to 
		NSRect tempRect = [self calculateWindowBounds:frameRect];
		
		// Apply the changes to the new document
		if (shouldAnimate) {
			// Core Animation, baby!
			[[[super window] animator] setFrame:tempRect display:YES];
		} else {
			[[super window] setFrame:tempRect display:YES];
		}
		
		// Tracking area
		[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:[self frame]
														   options: NSTrackingMouseMoved | NSTrackingCursorUpdate
							   | NSTrackingEnabledDuringMouseDrag | NSTrackingActiveWhenFirstResponder
															 owner:self
														  userInfo:nil]];
		[[self window] setAcceptsMouseMovedEvents:YES];
		
		
		// Set the initial cursor
		[(NSClipView *)[self superview] setDocumentCursor:[[toolbox currentTool] cursor]];
		
		// Set levels of undos based on user defaults
		NSNumber *undo = [[NSUserDefaults standardUserDefaults] objectForKey:@"UndoLevels"];
		[[self undoManager] setLevelsOfUndo:[undo integerValue]];
		
		// Grid related
		showsGrid = NO;
		gridSpacing = 1;
		gridColor = [NSColor gridColor];
		
		// VERY important for resizing image/canvas!
		hasRun = YES;
		
		[self setNeedsDisplay:YES];
	}
	return self;
}

- (NSRect)calculateWindowBounds:(NSRect)frameRect {
	// Set the window's maximum size to the size of the screen
	// Does not seem to work all the time
	NSRect screenRect = [[NSScreen mainScreen] frame];
	//[[super window] setMaxSize:screenRect.size];
	
	// Center the shrunken/enlarged window with respect to its initial location
	NSRect tempRect = [[super window] frameRectForContentRect:frameRect];
	NSPoint newOrigin = [[super window] frame].origin;
	
	tempRect.size.width += [NSScroller scrollerWidth];
	tempRect.size.height += [NSScroller scrollerWidth];
	
	newOrigin.y += (0.5 * ([[super window] frame].size.height - tempRect.size.height));
	newOrigin.x += (0.5 * ([[super window] frame].size.width - tempRect.size.width));
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
	if (rect.size.width != 0 && rect.size.height != 0) {
		
		NSRect drawRect = NSMakeRect(round(rect.origin.x), round(rect.origin.y), round(rect.size.width), round(rect.size.height));
		
		// If you don't do this, the image looks blurry when zoomed in
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
		
		// Fill the background, but maintain transparency of mainImage
		[[toolbox backgroundColor] set];
		//[NSBezierPath fillRect:[self bounds]];
		
		[NSGraphicsContext saveGraphicsState];
		
		// Draw the NSImage to the view
		if (mainImage) {
			[mainImage drawInRect:drawRect
						 fromRect:drawRect
						operation:NSCompositeSourceOver
						 fraction:1.0];
		}
		
		// If there's an overlay image being used at the moment, draw it
		if (secondImage) {
			[secondImage drawInRect:drawRect
						   fromRect:drawRect
						  operation:NSCompositeSourceOver
						   fraction:1.0];
		}
		
		// If the grid is turned on, draw that too
		if (showsGrid && [(SWScalingScrollView *)[[self superview] superview] scaleFactor] > 2.0) {
			[gridColor set];
			[[NSGraphicsContext currentContext] setShouldAntialias:NO];
			[[self gridInRect:[self frame]] stroke];
		}
		
		[NSGraphicsContext restoreGraphicsState];
	}
}

//- (NSMenu *)menuForEvent:(NSEvent *)theEvent
//{
//	NSLog(@"Wow!");
//	NSLog(@"%d", [theEvent type]);
//	return [SWPaintView defaultMenu];
//}

+ (NSMenu *)defaultMenu {
	//NSMenu *theMenu = [super initWithWindowNibName:@"Preferences"];
    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
    [theMenu insertItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"" atIndex:0];
    [theMenu insertItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"" atIndex:1];
    [theMenu insertItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"" atIndex:2];
	[theMenu insertItem:[NSMenuItem separatorItem] atIndex:3];
    [theMenu insertItemWithTitle:@"Zoom In" action:@selector(zoomIn:) keyEquivalent:@"" atIndex:4];
    [theMenu insertItemWithTitle:@"Zoom Out" action:@selector(zoomOut:) keyEquivalent:@"" atIndex:5];
    [theMenu insertItemWithTitle:@"Actual Size" action:@selector(actualSize:) keyEquivalent:@"" atIndex:6];
    return theMenu;
}

#pragma mark Mouse/keyboard events: the cornerstone of the drawing process

////////////////////////////////////////////////////////////////////////////////
//////////		Mouse/keyboard events: the cornerstone of the drawing process
////////////////////////////////////////////////////////////////////////////////


- (void)mouseDown:(NSEvent *)event
{
	isPayingAttention = YES;
	NSPoint p = [event locationInWindow];
	downPoint = [self convertPoint:p fromView:nil];
	[currentTool resetRedrawRect];
	
	// Necessary for when the view is zoomed above 100%
	currentPoint.x = floor(downPoint.x);
	currentPoint.y = floor(downPoint.y);
	
	// Since it's the click, let's confirm which tool we're dealing with
	if (currentTool != [toolbox currentTool]) {
		currentTool = [toolbox currentTool];
		[self clearOverlay];
	}
	[currentTool setSavedPoint:currentPoint];
	
	// If it's shifted, do something about it
	[currentTool setModifierFlags:[event modifierFlags]];
	[currentTool performDrawAtPoint:currentPoint 
					  withMainImage:mainImage 
						secondImage:secondImage 
						 mouseEvent:MOUSE_DOWN];
	
	//[self setNeedsDisplayInRect:[currentTool invalidRect]];
	[self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event
{
	//NSLog(@"Dragged");
	if (isPayingAttention) {
		NSPoint p = [event locationInWindow];
		NSPoint dragPoint = [self convertPoint:p fromView:nil];
		
		// Necessary for when the view is zoomed above 100%
		dragPoint.x = floor(dragPoint.x);
		dragPoint.y = floor(dragPoint.y);
		
		[currentTool setModifierFlags:[event modifierFlags]];
		[currentTool performDrawAtPoint:dragPoint withMainImage:mainImage secondImage:secondImage mouseEvent:MOUSE_DRAGGED];
		
		currentPoint = dragPoint;
		[self setNeedsDisplayInRect:[currentTool invalidRect]];
	}
}

- (void)mouseUp:(NSEvent *)event
{
	if (isPayingAttention) {
		
		NSPoint p = [event locationInWindow];
		downPoint = [self convertPoint:p fromView:nil];
		
		// Necessary for when the view is zoomed above 100%
		downPoint.x = floor(downPoint.x);
		downPoint.y = floor(downPoint.y);
		[currentTool setModifierFlags:[event modifierFlags]];
		[currentTool performDrawAtPoint:downPoint withMainImage:mainImage secondImage:secondImage mouseEvent:MOUSE_UP];
		currentPoint = downPoint;
		
		//[self setNeedsDisplayInRect:[currentTool invalidRect]];
		[self setNeedsDisplay:YES];
	}
}

// We want right-clicks to result in the use of the background color
- (void)rightMouseDown:(NSEvent *)theEvent
{
	NSEvent *modifiedEvent = [NSEvent mouseEventWithType:NSLeftMouseDown
												location:[theEvent locationInWindow] 
										   modifierFlags:[theEvent modifierFlags] | NSAlternateKeyMask
											   timestamp:[theEvent timestamp]
											windowNumber:[theEvent windowNumber]
												 context:[theEvent context]
											 eventNumber:[theEvent eventNumber]
											  clickCount:[theEvent clickCount]
												pressure:[theEvent pressure]];
	[NSApp postEvent:modifiedEvent atStart:YES];
}

- (void)rightMouseDragged:(NSEvent *)theEvent
{
	NSEvent *modifiedEvent = [NSEvent mouseEventWithType:NSLeftMouseDragged
												location:[theEvent locationInWindow] 
										   modifierFlags:[theEvent modifierFlags] | NSAlternateKeyMask
											   timestamp:[theEvent timestamp]
											windowNumber:[theEvent windowNumber]
												 context:[theEvent context]
											 eventNumber:[theEvent eventNumber]
											  clickCount:[theEvent clickCount]
												pressure:[theEvent pressure]];
	[NSApp postEvent:modifiedEvent atStart:YES];
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
	NSEvent *modifiedEvent = [NSEvent mouseEventWithType:NSLeftMouseUp
												location:[theEvent locationInWindow] 
										   modifierFlags:[theEvent modifierFlags] | NSAlternateKeyMask
											   timestamp:[theEvent timestamp]
											windowNumber:[theEvent windowNumber]
												 context:[theEvent context]
											 eventNumber:[theEvent eventNumber]
											  clickCount:[theEvent clickCount]
												pressure:[theEvent pressure]];
	[NSApp postEvent:modifiedEvent atStart:YES];
}


// Currently only necessary for the text tool, but we'll see where we go with it
- (void)mouseMoved:(NSEvent *)event
{
	//NSLog(@"Moved");
	NSPoint p = [event locationInWindow];
	NSPoint motionPoint = [self convertPoint:p fromView:nil];
	
	// Necessary for when the view is zoomed above 100%
	motionPoint.x = floor(motionPoint.x) + 0.5;
	motionPoint.y = floor(motionPoint.y) + 0.5;	
	[currentTool mouseHasMoved:motionPoint];
	//motionPath = [currentTool pathFromPoint:motionPoint toPoint:motionPoint];
	//[self setNeedsDisplay:YES];
}

// Overridden to set the correct cursor
- (void)cursorUpdate:(NSEvent *)event
{
	NSCursor *cursor = [[toolbox currentTool] cursor];
	if (cursor != [(NSClipView *)[self superview] documentCursor]) {
		[(NSClipView *)[self superview] setDocumentCursor:cursor];
	}
}

// Handles keyboard events
- (void)keyDown:(NSEvent *)event
{
	// Escape key
	if ([event keyCode] == 53) {
		isPayingAttention = NO;
		[currentTool tieUpLooseEnds];
		// This loop removes all the representations in the overlay image, effectively clearing it
		for (NSImageRep *rep in [secondImage representations]) {
			[secondImage removeRepresentation:rep];
		}
		[self setNeedsDisplay:YES];
		
		// Delete keys (back and forward)
	} else if ([event keyCode] == 51 || [event keyCode] == 117) {
		[self clearOverlay];
	} else {
		[[[toolbox window] contentView] keyDown:event];
	}
}

#pragma mark MyDocument tells PaintView this information from the Toolbox

////////////////////////////////////////////////////////////////////////////////
//////////		MyDocument tells PaintView this information from the Toolbox
////////////////////////////////////////////////////////////////////////////////


- (void)setImage:(NSImage *)newImage scale:(BOOL)scale
{	
	//mainImage = newImage;
	for (NSImageRep *rep in [mainImage representations]) {
		[mainImage removeRepresentation:rep];
	}
	[mainImage lockFocus];
	if (scale) {
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
		[newImage drawInRect:[self bounds]
					fromRect:NSZeroRect
				   operation:NSCompositeSourceOver
					fraction:1.0];
	} else {
		[newImage drawAtPoint:NSMakePoint(0, [self bounds].size.height - [newImage size].height)
					 fromRect:NSZeroRect
					operation:NSCompositeSourceOver
					 fraction:1.0];
	}
	[mainImage unlockFocus];
	
	[self setNeedsDisplay:YES];
}

- (void)setCurrentTool:(SWTool *)newTool
{
	currentTool = newTool;
}

#pragma mark Handling undo: a "prep" and then the actual method

////////////////////////////////////////////////////////////////////////////////
//////////		Handling undo: a "prep" and then the actual method
////////////////////////////////////////////////////////////////////////////////


- (void)prepUndo:(id)sender
{
	NSUndoManager *undo = [self undoManager];
	if (sender) {
		if ([(NSDictionary *)sender objectForKey:@"Image"]) {
			[[undo prepareWithInvocationTarget:self] undoImage:(NSData *)[sender objectForKey:@"Image"]];
		} else {
			// It was a resize... oh dear!
			NSSize oldSize = NSZeroSize;
			oldSize.width = [[(NSDictionary *)sender objectForKey:@"Width"] doubleValue];
			oldSize.height = [[(NSDictionary *)sender objectForKey:@"Height"] doubleValue];
			NSLog(@"%f, %f", oldSize.width, oldSize.height);
			[[undo prepareWithInvocationTarget:self] undoResize:[mainImage TIFFRepresentation] oldSize:oldSize];
		}
	} else {
		[[undo prepareWithInvocationTarget:self] undoImage:[mainImage TIFFRepresentation]];
	}
	if (![undo isUndoing]) {
		[undo setActionName:@"Drawing"];
	}
}

// Undo for drawing that doesn't change the canvas
- (void)undoImage:(NSData *)mainImageData
{
	NSUndoManager *undo = [self undoManager];
	[[undo prepareWithInvocationTarget:self] undoImage:[[self mainImage] TIFFRepresentation]];
	if (![undo isUndoing]) {
		[undo setActionName:@"Drawing"];
	}
	
	imageRep = [[NSBitmapImageRep alloc] initWithData:mainImageData];
	
	[mainImage lockFocus];
	[imageRep drawAtPoint:NSZeroPoint];
	[mainImage unlockFocus];
	[self clearOverlay];
}

// Undo canvas resizing
- (void)undoResize:(NSData *)mainImageData oldSize:(NSSize)size
{
	NSUndoManager *undo = [self undoManager];
	[[undo prepareWithInvocationTarget:self] undoResize:[mainImage TIFFRepresentation] oldSize:[mainImage size]];
	if (![undo isUndoing]) {
		[undo setActionName:@"Resize"];
	}
	
	NSRect tempRect = NSZeroRect;
	tempRect.size = size;
	[self initWithFrame:tempRect animate:YES];
	
	imageRep = [[NSBitmapImageRep alloc] initWithData:mainImageData];
	
	[mainImage lockFocus];
	[imageRep drawAtPoint:NSMakePoint(0, [self bounds].size.height - [imageRep pixelsHigh])];
	[mainImage unlockFocus];
	[self clearOverlay];
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
    endLine = floor((NSMaxX(rect)) / gridSpacing);
    for (; curLine<=endLine; curLine++) {
        [gridPath moveToPoint:NSMakePoint((curLine * gridSpacing), NSMinY(rect))];
        [gridPath lineToPoint:NSMakePoint((curLine * gridSpacing), NSMaxY(rect))];
    }
	
    // Rows
    curLine = ceil((NSMinY(rect)) / gridSpacing) + 1;
    endLine = floor((NSMaxY(rect)) / gridSpacing);
    for (; curLine<=endLine; curLine++) {
        [gridPath moveToPoint:NSMakePoint(NSMinX(rect), (curLine * gridSpacing))];
        [gridPath lineToPoint:NSMakePoint(NSMaxX(rect), (curLine * gridSpacing))];
    }
	
    //[gridPath setLineWidth:0.5];
    [gridPath setLineWidth:(1.0 / [(SWScalingScrollView *)[[self superview] superview] scaleFactor])];
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
	if (gridColor != newGridColor) {
		gridColor = newGridColor;
		[self setNeedsDisplay: YES];
	}
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
//////////		Miscellaneous
////////////////////////////////////////////////////////////////////////////////


// Releases the overlay image, then tells the tool about it
- (void)clearOverlay
{
	// This loop removes all the representations in the overlay image, effectively clearing it
	for (NSImageRep *rep in [secondImage representations]) {
		[secondImage removeRepresentation:rep];
	}
	[currentTool tieUpLooseEnds];
	[self setNeedsDisplay:YES];
}

// Pastes data as an image
- (void)pasteData:(NSData *)data
{
	[currentTool tieUpLooseEnds];
	[toolbox switchToScissors:nil];
	currentTool = [toolbox currentTool];
	[self cursorUpdate:nil];
	NSImage *temp = [[NSImage alloc] initWithData:data];
	
	NSLog(@"[[self superview] bounds] == (%lf, %lf), @ %lf by %lf",
		  //		  [[self superview] bounds].origin.x, [[self superview] bounds].origin.y, 
		  //		  [[self superview] bounds].size.width, [[self superview] bounds].size.height);
		  [self bounds].origin.x, [self bounds].origin.y, 
		  [self bounds].size.width, [self bounds].size.height);
	
	// Use ceiling because pixels can be fractions, but the tool assumes integer values
	//NSPoint origin = NSMakePoint([[self superview] bounds].origin.x, 
	//							 (ceil([[self superview] bounds].size.height) - ([temp size].height - origin.y)));
	NSPoint origin = [[self superview] bounds].origin;
	//	origin.y += abs([[self superview] bounds].size.height - [self bounds].size.height);
	NSLog(@"origin = (%lf, %lf)", origin.x, origin.y);
	if (origin.x < 0) origin.x = 0;
	if (origin.y < 0) origin.y = 0;
	origin.x++;
	origin.y++;
	
	NSRect rect = NSZeroRect;
	rect.origin = origin;
	
	// Use ceiling because pixels can be fractions, but the tool assumes integer values								 
	rect.size = NSMakeSize(ceil([temp size].width), ceil([temp size].height));
	
	// This loop removes all the representations in the overlay image, effectively clearing it
	for (NSImageRep *rep in [secondImage representations]) {
		[secondImage removeRepresentation:rep];
	}
	
	[secondImage lockFocus];
	[temp drawAtPoint:rect.origin
			 fromRect:NSZeroRect
			operation:NSCompositeSourceOver
			 fraction:1.0];
	[secondImage unlockFocus];
	
	[(SWSelectionTool *)currentTool setClippingRect:rect
										   forImage:secondImage];
	[self setNeedsDisplay:YES];
}

// Returns the mainImage
- (NSImage *)mainImage
{
	return mainImage;
}

// Returns the overlay
- (NSImage *)secondImage
{
	return secondImage;
}


// Tells the mainImage to refresh itself. Can be called from anywhere in the application.
- (void)refreshImage:(id)sender
{
	if (sender) {
		[self setNeedsDisplayInRect:[sender invalidRect]];
	} else {
		[self setNeedsDisplay:YES];
	}
}

// Optimizes speed a bit
- (BOOL)isOpaque
{
	return YES;
}

- (BOOL)hasRun
{
	return hasRun;
}

// Necessary to allow keyboard events and stuff
- (BOOL)acceptsFirstResponder
{
	return YES;
}

/*- (void)dealloc
 {
 if (undoData) {
 [undoData release];
 }
 [[NSNotificationCenter defaultCenter] removeObserver:self];
 [frontColor release];
 [backColor release];
 [mainImage release];
 [imageRep release];
 [[self undoManager] removeAllActions]; 
 // Note: do NOT release the current tool, as it is just a pointer to the
 // object inherited from ToolboxController
 
 [super dealloc];
 }*/

@end

//void DrawGridWithSettingsInRect(CGFloat spacing, NSColor *color, NSRect rect, NSPoint gridOrigin) 
//{
//    int curLine, endLine;
//    NSBezierPath *gridPath = [NSBezierPath bezierPath];
//	
//    [color set];
//	
//    // Columns
//    curLine = ceil((NSMinX(rect) - gridOrigin.x) / spacing);
//    endLine = floor((NSMaxX(rect) - gridOrigin.x) / spacing);
//    for (; curLine<=endLine; curLine++) {
//        [gridPath moveToPoint:NSMakePoint((curLine * spacing) + gridOrigin.x, NSMinY(rect))];
//        [gridPath lineToPoint:NSMakePoint((curLine * spacing) + gridOrigin.x, NSMaxY(rect))];
//    }
//	
//    // Rows
//    curLine = ceil((NSMinY(rect) - gridOrigin.y) / spacing);
//    endLine = floor((NSMaxY(rect) - gridOrigin.y) / spacing);
//    for (; curLine<=endLine; curLine++) {
//        [gridPath moveToPoint:NSMakePoint(NSMinX(rect), (curLine * spacing) + gridOrigin.y)];
//        [gridPath lineToPoint:NSMakePoint(NSMaxX(rect), (curLine * spacing) + gridOrigin.y)];
//    }
//	
//    [gridPath setLineWidth:0.0];
//    [gridPath stroke];
//}
