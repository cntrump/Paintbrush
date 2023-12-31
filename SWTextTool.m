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


#import "SWTextTool.h"
#import "SWDocument.h"
#import "SWPaintView.h"

@implementation SWTextTool

- (instancetype)initWithController:(SWToolboxController *)controller
{
    if (self = [super initWithController:controller]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(insertText:)
                                                     name:@"SWTextEntered"
                                                   object:nil];
        canInsert = NO;
        stringToInsert = nil;
    }
    return self;
}

- (NSBezierPath *)pathFromPoint:(NSPoint)begin toPoint:(NSPoint)end
{
    return nil;
}

- (NSBezierPath *)performDrawAtPoint:(NSPoint)point 
                       withMainImage:(NSBitmapImageRep *)mainImage 
                         bufferImage:(NSBitmapImageRep *)bufferImage 
                          mouseEvent:(SWMouseEvent)event
{
    _mainImage = mainImage;
    _bufferImage = bufferImage;
    
    [SWImageTools clearImage:bufferImage];
    if (canInsert) 
    {
        if (event == MOUSE_MOVED)
            drawToMe = bufferImage;
        else if (event == MOUSE_DOWN)
        {
            // We're about to draw, so prep an undo
            [document handleUndoWithImageData:nil frame:NSZeroRect];

            drawToMe = mainImage;
            canInsert = NO;
        }
        else
            return nil; // Return in all other cases
        
        // The size of the string, as a guesstimate
        NSSize textSize = [stringToInsert size];
        
        // Assign the redrawRect based on the string's size and the insertion point
        NSRect rect = [stringToInsert boundingRectWithSize:[stringToInsert size] 
                                                   options:NSStringDrawingUsesFontLeading | NSStringDrawingUsesDeviceMetrics];
        
        CGFloat xOffset = fabs(rect.origin.x);
        CGFloat yOffset = fabs(rect.origin.y);
        rect.size.width += xOffset + textSize.width;
        rect.size.height += yOffset + textSize.height;
        
        // Shift it
        rect.origin = NSMakePoint(floorf(point.x), floorf(point.y));
        rect.origin.y -= rect.size.height;
        rect.origin.y += yOffset;

        [super addRectToRedrawRect:rect];
        rect.origin.x += xOffset;

        // Fix the origin, since we're dealing with flipped stuff
        rect.origin.y = drawToMe.pixelsHigh - rect.origin.y - rect.size.height;
        
        SWLockFocus(drawToMe);
        NSAffineTransform *transform = [NSAffineTransform transform];            
        // Create the transform
        [transform scaleXBy:1.0 yBy:-1.0];
        [transform translateXBy:0 yBy:(0-drawToMe.pixelsHigh)];
        [transform concat];
        [stringToInsert drawAtPoint:rect.origin];
        [NSGraphicsContext restoreGraphicsState];
        SWUnlockFocus(drawToMe);
        
        [NSApp sendAction:@selector(refreshImage:)
                       to:nil
                     from:self];
    }
    else if (event == MOUSE_DOWN) 
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SWText" object:frontColor];
        canInsert = YES;
    }
    return nil;
}

// Summoned by the NSNotificationCenter when the user clicks "OK" in the sheet
- (void)insertText:(NSNotification *)note
{
    stringToInsert = [[NSAttributedString alloc] initWithAttributedString:note.userInfo[@"newText"]];
    
    // Get the current point and then draw it
    // Doesn't work quite right yet
//    NSPoint point = [[document paintView] currentMouseLocation];
//    [self mouseHasMoved:point];
    
    [NSApp sendAction:@selector(refreshImage:)
                   to:nil
                 from:nil];
}

// Overridden for drawing to the buffer image
- (void)mouseHasMoved:(NSPoint)point
{
    if (stringToInsert) 
    {
        [self performDrawAtPoint:point withMainImage:_mainImage bufferImage:_bufferImage mouseEvent:MOUSE_MOVED];        
    }
}

- (void)tieUpLooseEnds
{
    stringToInsert = nil;
    canInsert = NO;
    
    [super tieUpLooseEnds];
}

- (NSCursor *)cursor
{
    if (!customCursor) {
        customCursor = NSCursor.IBeamCursor;
    }
    return customCursor;
}


// Overridden for right-click
- (BOOL)shouldShowContextualMenu
{
    return YES;
}

- (NSString *)description
{
    return @"Text";
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
