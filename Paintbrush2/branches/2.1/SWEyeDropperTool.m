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


#import "SWEyeDropperTool.h"
#import "SWToolboxController.h"


@implementation SWEyeDropperTool

- (NSBezierPath *)performDrawAtPoint:(NSPoint)point 
					   withMainImage:(NSBitmapImageRep *)mainImage 
						 bufferImage:(NSBitmapImageRep *)bufferImage 
						  mouseEvent:(SWMouseEvent)event
{
	// This should happen regardless of the type of click
	NSColor *colorClicked = [mainImage colorAtX:point.x y:([mainImage pixelsHigh] - point.y - 1)];
	
	if (colorClicked != nil) {
		NSColor *colorClickedConverted = [colorClicked colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
		if (flags & NSAlternateKeyMask) {
			[[SWToolboxController sharedToolboxPanelController] setBackgroundColor:colorClickedConverted];
		} else {
			[[SWToolboxController sharedToolboxPanelController] setForegroundColor:colorClickedConverted];
		}
	}

	return nil;
}

- (NSCursor *)cursor
{
	if (!customCursor) {
		NSImage *customImage = [NSImage imageNamed:@"eyedrop-cursor.png"];
		customCursor = [[NSCursor alloc] initWithImage:customImage hotSpot:NSMakePoint(1,15)];
	}
	return customCursor;
}

- (NSString *)description
{
	return @"Eyedropper";
}


@end
