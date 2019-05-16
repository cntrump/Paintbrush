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


#import "SWRoundedRectangleTool.h"
#import "SWDocument.h"

@implementation SWRoundedRectangleTool

- (NSBezierPath *)pathFromPoint:(NSPoint)begin toPoint:(NSPoint)end
{
	path = [NSBezierPath bezierPath];
	[path setLineWidth:lineWidth];
	[path setLineCapStyle:NSSquareLineCapStyle];
	[path moveToPoint:begin];
	if (lineWidth <= 1) 
	{
		begin.x += 0.5;
		begin.y += 0.5;
		end.x += 0.5;
		end.y += 0.5;
	}
	
//	// Normally this would work, but there are problems with the NSBezierPath rounded rect
//	if (flags & NSShiftKeyMask) {
//		CGFloat size = fmin(abs(end.x-begin.x),abs(end.y-begin.y));
//		NSInteger x = (end.x-begin.x) / abs(end.x-begin.x);
//		NSInteger y = (end.y-begin.y) / abs(end.y-begin.y);
//		[path appendBezierPathWithRoundedRect:NSMakeRect(begin.x, begin.y, x*size, y*size) xRadius:30 yRadius:30];
//	} else {
//		[path appendBezierPathWithRoundedRect:NSMakeRect(begin.x, begin.y, (end.x - begin.x), (end.y - begin.y)) xRadius:30 yRadius:30];
//	}
	
	// Some weird stuff, since roundedRects are picky and require positive widths and heights
	NSPoint temp = begin;
	BOOL negX = NO, negY = NO;
	if ((end.x - begin.x) < 0) 
	{
		negX = YES;
		temp.x = begin.x;
		begin.x = end.x;
		end.x = temp.x;
	}
	
	if ((end.y - begin.y) < 0) 
	{
		negY = YES;
		temp.y = begin.y;
		begin.y = end.y;
		end.y = temp.y;
	}
	
	if (flags & NSShiftKeyMask)
	{
		CGFloat size = fmin(abs(end.x-begin.x),abs(end.y-begin.y));
		
		if (negX) 
			begin.x -= size - abs(end.x - begin.x);
		if (negY) 
			begin.y -= size - abs(end.y - begin.y);
		
		[path appendBezierPathWithRoundedRect:NSMakeRect(begin.x, begin.y, size, size) 
									  xRadius:(NSInteger)MIN(size/5, 15)
									  yRadius:(NSInteger)MIN(size/5, 15)];
	} 
	else
	{
		[path appendBezierPathWithRoundedRect:NSMakeRect(begin.x, begin.y, (end.x - begin.x), (end.y - begin.y)) 
									  xRadius:(NSInteger)MIN(((end.x - begin.x)/5), 15)  
									  yRadius:(NSInteger)MIN(((end.y - begin.y)/5), 15)];
	}
	
	return path;	
}

- (NSBezierPath *)performDrawAtPoint:(NSPoint)point 
					   withMainImage:(NSBitmapImageRep *)mainImage 
						 bufferImage:(NSBitmapImageRep *)bufferImage 
						  mouseEvent:(SWMouseEvent)event
{
	// Use the points clicked to build a redraw rectangle
	[super addRedrawRectFromPoint:savedPoint toPoint:point];

	[SWImageTools clearImage:bufferImage];
	
	if (event == MOUSE_UP) 
	{
		[document handleUndoWithImageData:nil frame:NSZeroRect];
		drawToMe = mainImage;
	}
	else
		drawToMe = bufferImage;
	
	SWLockFocus(drawToMe); 
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	
	// Which colors should we draw with?
	if (event == MOUSE_DOWN) {
		if (flags & NSAlternateKeyMask) {
			primaryColor = backColor;
			secondaryColor = frontColor;
		} else {
			primaryColor = frontColor;
			secondaryColor = backColor;
		}
	}
	
	[self pathFromPoint:savedPoint toPoint:point];
	if (shouldFill && shouldStroke)
	{
		[primaryColor setStroke];
		[secondaryColor setFill];
		[path fill];
		[path stroke];
	}
	else if (shouldFill) 
	{
		[primaryColor setFill];
		[path fill];
	}
	else if (shouldStroke) 
	{
		[primaryColor setStroke];
		[path stroke];
	}
	
	SWUnlockFocus(drawToMe);
	return nil;
}

- (NSCursor *)cursor
{
	if (!customCursor) {
		customCursor = [[NSCursor crosshairCursor] retain];
	}
	return customCursor;
}

- (BOOL)shouldShowFillOptions
{
	return YES;
}

- (NSString *)description
{
	return @"Rounded Rectangle";
}

@end
