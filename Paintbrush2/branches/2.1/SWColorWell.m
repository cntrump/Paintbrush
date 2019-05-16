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


#import "SWColorWell.h"
#import "SWColorSelector.h"

@implementation SWColorWell

@synthesize isHovered;


- (id)initWithCoder:(NSCoder *)coder
{
	[super initWithCoder:coder];
	
	hovImage = [NSImage imageNamed:@"hoveredwell.png"];
	pressedImage = [NSImage imageNamed:@"pressedwell.png"];
	
	return self;
}


// Overwriting NSColorWell to add one interesting feature: when an active
//  well is selected (deactivating it), the associated NSColorPanel is 
//  closed, reinforcing the fact that it has been deselected, as well as
//  eliminating the possibility of CGFloat-clicking and unknowingly
//  deactivating the well.
- (void)deactivate 
{
	// While we're at it, redraw everything
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SWColorSet" object:nil];
	[super deactivate];
	[[NSColorPanel sharedColorPanel] close];
}


// Instead of doing the regular drawing, we're kicking it up a notch!  Bam!
- (void)drawRect:(NSRect)rect
{
	if (isHovered) 
		rect = NSInsetRect(rect, 3.0, 3.0);
	else
		rect = NSInsetRect(rect, 4.0, 4.0);
	
	// An SWColorWell can be hovered, selected, or neither
	if ([self isActive]) 
	{
		[pressedImage drawAtPoint:NSZeroPoint 
						 fromRect:NSZeroRect 
						operation:NSCompositeSourceOver 
						 fraction:1.0];	
	} 
	else if (isHovered) 
	{
		[hovImage drawAtPoint:NSZeroPoint 
					 fromRect:NSZeroRect 
					operation:NSCompositeSourceOver 
					 fraction:1.0];
	}
	
	rect.origin.x += 0.5;
	rect.origin.y += 0.5;
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:4 yRadius:4];
	[path setLineWidth:1.0];
	
	// Draw the fill now
	[[self color] setFill];		
	[path fill];
	
	[[NSColor grayColor] setStroke];
	[path stroke];
}


// When either of these three actions happens, make sure we redraw BOTH rects!  Very important.
- (void)setColor:(NSColor *)color
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SWColorSet" object:nil];
	[super setColor:color];
}

- (void)mouseDown:(NSEvent *)event
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SWColorSet" object:nil];
	[super mouseDown:event];
	[[self superview] mouseDown:event];
}

- (void)mouseUp:(NSEvent *)event
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SWColorSet" object:nil];
	[super mouseUp:event];
	[[self superview] mouseUp:event];
}

- (BOOL)isOpaque
{
	return NO;
}

@end
