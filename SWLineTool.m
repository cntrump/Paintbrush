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


#import "SWLineTool.h"
#import "SWDocument.h"

@implementation SWLineTool

- (NSBezierPath *)pathFromPoint:(NSPoint)begin toPoint:(NSPoint)end
{
    path = [NSBezierPath bezierPath];
    path.lineWidth = lineWidth;
    [path moveToPoint:begin];
    if (lineWidth <= 1) 
    {
        begin.x += 0.5;
        begin.y += 0.5;
        end.x += 0.5;
        end.y += 0.5;
    }
    if (flags & NSEventModifierFlagShift) {
        // x and y are either positive or negative 1
        NSInteger x = (end.x-begin.x) / fabs(end.x-begin.x);
        NSInteger y = (end.y-begin.y) / fabs(end.y-begin.y);
        
        // Theta is the angle formed by the mouse, in degrees (rad * 180/�)
        // atan()'s result is in radians
        CGFloat theta = 180*atan((end.y-begin.y)/(end.x-begin.x)) / pi;
        
        // Deciding whether it should be horizontal, vertical, or at 45�
        NSPoint newPoint = NSZeroPoint;
        CGFloat size = fmin(fabs(end.x-begin.x),fabs(end.y-begin.y));
        
        if (fabs(theta) <= 67.5 && fabs(theta) >= 22.5) {
            // �/4
            newPoint = NSMakePoint(size*x, size*y);
        } else if (fabs(theta) > 67.5) {
            // �/2
            newPoint = NSMakePoint(0, (end.y-begin.y));
        } else {
            // 0
            newPoint = NSMakePoint((end.x - begin.x), 0);
        }
        
        [path relativeLineToPoint:newPoint];
    } else {
        [path lineToPoint:end];
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
    
    // Which color do we use?
    if (event == MOUSE_DOWN)
        primaryColor = (flags & NSEventModifierFlagOption) ? backColor : frontColor;
    
    SWLockFocus(drawToMe); 
    [[NSGraphicsContext currentContext] setShouldAntialias:NO];
    
    [primaryColor setStroke];
    [[self pathFromPoint:savedPoint toPoint:point] stroke];
    
    SWUnlockFocus(drawToMe);
    return nil;
    
}

- (NSCursor *)cursor
{
    if (!customCursor) {
        customCursor = NSCursor.crosshairCursor;
    }
    return customCursor;
}

- (NSString *)description
{
    return @"Line";
}

@end
