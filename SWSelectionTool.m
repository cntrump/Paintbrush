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


#import "SWSelectionTool.h"
#import "SWToolboxController.h"
#import "SWDocument.h"

@implementation SWSelectionTool

@synthesize selectedImage;
@synthesize oldOrigin;

- (instancetype)initWithController:(SWToolboxController *)controller;
{
	if (self = [super initWithController:controller]) {
		[controller addObserver:self
					 forKeyPath:@"selectionTransparency" 
						options:NSKeyValueObservingOptionNew 
						context:NULL];
		deltax = deltay = 0;
		dottedLineOffset = 0;
		isSelected = NO;
		dottedLineArray[0] = 5.0;
		dottedLineArray[1] = 3.0;
	}
	return self;
}

// The tools will observe several values set by the toolbox
- (void)observeValueForKeyPath:(NSString *)keyPath 
					  ofObject:(id)object 
						change:(NSDictionary *)change 
					   context:(void *)context
{
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	
	id thing = change[NSKeyValueChangeNewKey];
	
	if ([keyPath isEqualToString:@"selectionTransparency"]) 
	{
		shouldOmitBackground = [thing boolValue];
		[self updateBackgroundOmission];
	}
}

- (NSBezierPath *)pathFromPoint:(NSPoint)begin toPoint:(NSPoint)end
{
	path = [NSBezierPath bezierPath];
	path.lineWidth = 1.0;
	[path setLineDash:dottedLineArray count:2 phase:dottedLineOffset];
	path.lineCapStyle = NSSquareLineCapStyle;	
	
	// The 0.5s help because the width is 1, and that does weird stuff
	[path appendBezierPathWithRect:
		NSMakeRect(clippingRect.origin.x+0.5, clippingRect.origin.y+0.5, clippingRect.size.width-1, clippingRect.size.height-1)];

	return path;	
}

- (NSBezierPath *)performDrawAtPoint:(NSPoint)point 
					   withMainImage:(NSBitmapImageRep *)mainImage 
						 bufferImage:(NSBitmapImageRep *)bufferImage 
						  mouseEvent:(SWMouseEvent)event
{	
	_bufferImage = bufferImage;
	_mainImage = mainImage;
	
	// Running the selection animator
	if (event == MOUSE_DOWN && animationTimer) 
	{
		[animationTimer invalidate];
		animationTimer = nil;
	}
	else if (event == MOUSE_UP && !NSEqualPoints(point, savedPoint)) 
	{
		// We are drawing the frame for the first time
		animationTimer = [NSTimer scheduledTimerWithTimeInterval:0.075 // 75 ms, or 13.33 Hz
														  target:self
														selector:@selector(drawNewBorder:)
														userInfo:nil
														 repeats:YES];		
	} 
	
	// If the rectangle has already been drawn
	if (isSelected)
	{
		// We checked for the drag because it's possible that the cursor has been dragged outside the 
		// clipping rect in one single event
		if (event == MOUSE_DRAGGED || [[NSBezierPath bezierPathWithRect:clippingRect] containsPoint:point]) 
		{
			if (event == MOUSE_DOWN)
				previousPoint = point;

			deltax += point.x - previousPoint.x;
			deltay += point.y - previousPoint.y;
			
			previousPoint = point;
			
			// Do the moving thing
			[SWImageTools clearImage:bufferImage];
			clippingRect.origin.x = oldOrigin.x + deltax;
			clippingRect.origin.y = oldOrigin.y + deltay;
			
			// Check for the shift key
//			if (flags & NSShiftKeyMask) {				
//				NSUInteger dx = abs(point.x - previousPoint.x);
//				NSUInteger dy = abs(point.y - previousPoint.y);
//				
//				if (dx > dy) {
//					clippingRect.origin.x -= deltax;
//				} else {
//					clippingRect.origin.y -= deltay;
//				}		
//			}
			
			// The clipping rect is the new redraw rect
			[super addRectToRedrawRect:clippingRect];
			
			// Finally, move the image and stroke it
			[self drawNewBorder:nil];
		} 
		else
			[self tieUpLooseEnds];
	} 
	else
	{
		// Still drawing the dotted line
		deltax = deltay = 0;

		[SWImageTools clearImage:bufferImage];
		
		// Taking care of the outer bounds of the image
		if (point.x < 0)
			point.x = 0.0;
		if (point.y < 0)
			point.y = 0.0;
		if (point.x > mainImage.size.width)
			point.x = mainImage.size.width;
		if (point.y > mainImage.size.height)
			point.y = mainImage.size.height;
				
		// If this check fails, then they didn't draw a rectangle
		if (!NSEqualPoints(point, savedPoint)) 
		{
			// Set the redraw rectangle
			[super addRedrawRectFromPoint:savedPoint toPoint:point];
			
			// Create the clipping rect based on these two new points
			clippingRect = NSMakeRect(fmin(savedPoint.x, point.x), fmin(savedPoint.y, point.y), 
									  fabs(point.x - savedPoint.x), fabs(point.y - savedPoint.y));

			if (event == MOUSE_UP) 
			{
				// Copy the rectangle's contents to the second image
				originalImageCopy = [[NSBitmapImageRep alloc] initWithData:mainImage.TIFFRepresentation];
				
				[SWImageTools clearImage:bufferImage];
				
				// Prepare the two image: one with transparency, and one without
				selImageSansTransparency = [SWImageTools cropImage:mainImage toRect:clippingRect];
				selImageWithTransparency = [SWImageTools cropImage:mainImage toRect:clippingRect];
				[SWImageTools stripImage:selImageWithTransparency ofColor:backColor];
				
				// Now if we should, remove the background of the image
				if (shouldOmitBackground) 
					selectedImage = selImageWithTransparency;
				else
					selectedImage = selImageSansTransparency;
				
				// Delete it from the main image
				SWLockFocus(mainImage);
				[backColor set];
				// Note: don't use a bezierpath! It'll fail with clear-ish colors
				NSRectFill(clippingRect);
				SWUnlockFocus(mainImage);
				
				isSelected = YES;
				
			}
			oldOrigin = clippingRect.origin;
			
			// Finally, draw the image and the selection
			[self drawNewBorder:nil];
		}
	}
	return nil;
}

// Tick the timer!
- (void)drawNewBorder:(NSTimer *)timer
{
	dottedLineOffset = (dottedLineOffset + 1) % 8;
	
	// Draw the backed image to the overlay
	if (_bufferImage) 
	{
		[SWImageTools clearImage:_bufferImage];
		SWLockFocus(_bufferImage);
		if (selectedImage)
			[selectedImage drawAtPoint:NSMakePoint(oldOrigin.x + deltax, oldOrigin.y + deltay)];
		
		// Next, stroke it
		[[NSGraphicsContext currentContext] setShouldAntialias:NO];
		[[NSColor darkGrayColor] setStroke];
		[[self pathFromPoint:clippingRect.origin 
					 toPoint:NSMakePoint(clippingRect.origin.x + clippingRect.size.width, 
										 clippingRect.origin.y + clippingRect.size.height)] stroke];			
		SWUnlockFocus(_bufferImage);
	}
	
	// Get the view to perform a redraw to see the new border
	[NSApp sendAction:@selector(refreshImage:)
				   to:nil
				 from:self];
}

- (void)deleteKey
{
	selectedImage = nil;
	selImageWithTransparency = nil;
	selImageSansTransparency = nil;
}


- (void)updateBackgroundOmission
{
	// Switch the image that selectedImage points to, if it exists
	if (shouldOmitBackground)
	{
		selectedImage = selImageWithTransparency;
	}
	else
	{
		selectedImage = selImageSansTransparency;
	}
	
	// Update the UI with the new image
	[self drawNewBorder:nil];
}


- (void)tieUpLooseEnds
{
	[super tieUpLooseEnds];
	
	if (animationTimer) 
	{
		[animationTimer invalidate];
		animationTimer = nil;
	}
	
	// Before making an undo happen, copy _mainImage to mainImageCopy -- the undo-ing process will revert mainImage
	NSBitmapImageRep *mainImageCopy = nil;
	if (_mainImage)
	{
		[SWImageTools initImageRep:&mainImageCopy withSize:_mainImage.size];
		[SWImageTools drawToImage:mainImageCopy fromImage:_mainImage withComposition:NO];
	}

	// Make an undo happen if there's an active selection
	if (isSelected)
	{
		isSelected = NO;
		if (originalImageCopy)
		{
			// Re-set the _mainImage to originalImageCopy for the undo to work properly
			[SWImageTools drawToImage:_mainImage fromImage:originalImageCopy withComposition:NO];
			[document handleUndoWithImageData:nil frame:NSZeroRect];
			
			// Clean up!
			originalImageCopy = nil;
		}
	}

	// Checking to see if references have been made; otherwise causes strange drawing bugs
	if (_mainImage)
	{
		[SWImageTools drawToImage:mainImageCopy
						fromImage:selectedImage 
						  atPoint:NSMakePoint(oldOrigin.x + deltax, oldOrigin.y + deltay)
				  withComposition:YES];

		// Redraw the entire image
		[super addRectToRedrawRect:NSMakeRect(0,0,mainImageCopy.size.width,mainImageCopy.size.height)];
		
		// Finally, move all of mainImageCopy to _mainImage
		[SWImageTools drawToImage:_mainImage fromImage:mainImageCopy withComposition:NO];
	} 
	else
		[super resetRedrawRect];
	
	// Now nuke the buffer image
	if (_bufferImage)
	{
		[SWImageTools clearImage:_bufferImage];
		_bufferImage = nil;
	}
	
	// Get rid of references to the selected image
	[self deleteKey];
	
	// Clean up after ourselves
	_mainImage = nil;
}

- (NSRect)clippingRect
{
	return clippingRect;
}

// Called from the PaintView when an image is pasted
- (void)setClippingRect:(NSRect)rect forImage:(NSBitmapImageRep *)image withMainImage:(NSBitmapImageRep *)mainImage
{
	_mainImage = mainImage;
	_bufferImage = image;
	deltax = deltay = 0;
	clippingRect = rect;
	oldOrigin = rect.origin;
	isSelected = YES;
	
	// Create the image to paste
    NSBitmapImageRep *selectedImage = nil, *selImageWithTransparency = nil;
	[SWImageTools initImageRep:&selectedImage withSize:_bufferImage.size];
    self->selectedImage = selectedImage;
	SWLockFocus(selectedImage);
	[NSGraphicsContext currentContext].imageInterpolation = NSImageInterpolationNone;
	// Create the point to paste at
	NSPoint point = NSMakePoint(clippingRect.origin.x, clippingRect.origin.y + (clippingRect.size.height - selectedImage.size.height));
	[image drawAtPoint:point];
	SWUnlockFocus(selectedImage);
	
	// Make the copies of the image for with/without transparency
	selImageSansTransparency = selectedImage;
	[SWImageTools initImageRep:&selImageWithTransparency withSize:_bufferImage.size];
    self->selImageWithTransparency = selImageWithTransparency;
	[SWImageTools drawToImage:selImageWithTransparency
					fromImage:selImageSansTransparency 
			  withComposition:NO];
	[SWImageTools stripImage:selImageWithTransparency ofColor:backColor];

	// Which one should we be using?  Let this method decide
	[self updateBackgroundOmission];
	
	// Draw the dotted line around the selected region
	[self drawNewBorder:nil];
	
	// Set the redraw rect!
	[super addRectToRedrawRect:clippingRect];
	
	// Manually create the timer
	animationTimer = [NSTimer scheduledTimerWithTimeInterval:0.075 // 75 ms, or 13.33 Hz
													  target:self
													selector:@selector(drawNewBorder:)
													userInfo:nil
													 repeats:YES];	
}

- (NSData *)imageData
{
	return originalImageCopy.TIFFRepresentation;
}

- (NSBitmapImageRep *)selectedImage
{
	return selectedImage;
}

- (BOOL)isSelected
{
	return isSelected;
}

- (NSCursor *)cursor
{
	if (!customCursor) {
		customCursor = NSCursor.crosshairCursor;
	}
	return customCursor;
}

// We got better color accuracy in 2.1, so we flipped this back on
- (BOOL)shouldShowTransparencyOptions
{
	return YES;
}

// Overridden for right-click
- (BOOL)shouldShowContextualMenu
{
	return YES;
}

- (NSString *)description
{
	return @"Selection";
}

- (void)dealloc
{
	[toolboxController removeObserver:self forKeyPath:@"selectionTransparency"];
}

@end
