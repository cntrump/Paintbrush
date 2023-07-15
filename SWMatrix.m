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


#import "SWMatrix.h"
#import "SWButtonCell.h"

@implementation SWMatrix

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {

        [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.frame
                                                           options: NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect
                                                             owner:self
                                                          userInfo:nil]];

        [self.window setAcceptsMouseMovedEvents:YES];
        hoveredPoint = NSMakePoint(-1,-1);
        hoveredCell = nil;
    }
    
	return self;
}

// When the mouse exits the tracking area, remove any highlights
- (void)mouseExited:(NSEvent *)theEvent
{
	[hoveredCell setIsHovered:NO];
	hoveredPoint = NSMakePoint(-1,-1);
	hoveredCell = nil;
}

// When the mouse moves, make sure the correct button is hovered
- (void)mouseMoved:(NSEvent *)theEvent
{
	NSPoint p = theEvent.locationInWindow;
	NSPoint converted = [self convertPoint:p fromView:nil];
	
	// Calculate which row and column this point equates to
	NSInteger row, col;
	[self getRow:&row column:&col forPoint:converted];
	
	// Is it a new cell?
	if (hoveredPoint.x != row || hoveredPoint.y != col) {
		hoveredPoint = NSMakePoint(row,col);
		
		// Switch to the new cell
		[hoveredCell setIsHovered:NO];
		hoveredCell = [self cellAtRow:row column:col];
		
		[hoveredCell setIsHovered:YES];			
	}
}

@end
