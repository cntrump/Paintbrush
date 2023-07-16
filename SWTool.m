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


#import "SWTool.h"
#import "SWToolboxController.h"

@implementation SWTool

@synthesize flags;
@synthesize document;

- (instancetype)initWithController:(SWToolboxController *)controller
{
    if(self = [super init]) 
    {
        [self resetRedrawRect];
        toolboxController = controller;
        [controller addObserver:self 
                     forKeyPath:@"lineWidth" 
                        options:NSKeyValueObservingOptionNew 
                        context:NULL];
        [controller addObserver:self 
                     forKeyPath:@"foregroundColor" 
                        options:NSKeyValueObservingOptionNew 
                        context:NULL];
        [controller addObserver:self 
                     forKeyPath:@"backgroundColor" 
                        options:NSKeyValueObservingOptionNew 
                        context:NULL];
        [controller addObserver:self 
                     forKeyPath:@"fillStyle" 
                        options:NSKeyValueObservingOptionNew 
                        context:NULL];
    }
    return self;
}

// Returns a copy of this object
//- (id)copyWithZone:(NSZone *)zone
//{
//    SWTool *copy = [[[self class] alloc] initWithController:toolbox];
//    
//    return copy;
//}

// The tools will observe several values set by the toolbox
- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context
{
    id thing = change[NSKeyValueChangeNewKey];
    
    if ([keyPath isEqualToString:@"lineWidth"]) {
        [self setLineWidth:[thing integerValue]];
    } else if ([keyPath isEqualToString:@"foregroundColor"]) {
        [self setFrontColor:thing];
    } else if ([keyPath isEqualToString:@"backgroundColor"]) {
        [self setBackColor:thing];
    } else if ([keyPath isEqualToString:@"fillStyle"]) {
        SWFillStyle fillStyle = [thing integerValue];
        [self setShouldFill:(fillStyle == FILL_ONLY || fillStyle == FILL_AND_STROKE) 
                     stroke:(fillStyle == STROKE_ONLY || fillStyle == FILL_AND_STROKE)];
    }
}

- (void)resetRedrawRect
{
    redrawRect = savedRect = NSMakeRect(CGFLOAT_MAX, CGFLOAT_MAX, 0.0, 0.0);
}

- (NSColor *)drawingColor
{
    return frontColor;
}


- (CGFloat)lineWidth
{
    return lineWidth;
}

- (void)setFrontColor:(NSColor *)front
{
    frontColor = front;
}

- (void)setBackColor:(NSColor *)back
{
    backColor = back;
}

- (void)setLineWidth:(CGFloat)width
{
    lineWidth = width;
}

- (void)setShouldFill:(BOOL)fill stroke:(BOOL)stroke
{
    shouldFill = fill;
    shouldStroke = stroke;
}

//- (void)setFrontColor:(NSColor *)front 
//            backColor:(NSColor *)back 
//            lineWidth:(CGFloat)width 
//           shouldFill:(BOOL)fill 
//         shouldStroke:(BOOL)stroke
//{
//    frontColor = front;
//    backColor = back;
//    lineWidth = width;
//    shouldFill = fill;
//    shouldStroke = stroke;
//}

- (NSPoint)savedPoint
{
    return savedPoint;
}

- (void)setSavedPoint:(NSPoint)aPoint
{
    savedPoint = aPoint;
}

- (void)deleteKey
{
    // ?
}

- (void)tieUpLooseEnds
{
    // Must be overridden if you want something more interesting to happen
    DebugLog(@"%@ tool is tying up loose ends", [self class]);
}

- (BOOL)isEqualToTool:(SWTool *)aTool
{
    return ([[self class] isEqualTo:[aTool class]]);
}

- (void)mouseHasMoved:(NSPoint)aPoint
{
    // Does nothing! It's up to the subclasses to implement this one
}

- (NSBezierPath *)path
{
    return path;
}

// By default, no contextual menu
- (BOOL)shouldShowContextualMenu
{
    return NO;
}

// Used to make the drawing faster
- (NSRect)addRedrawRectFromPoint:(NSPoint)p1 toPoint:(NSPoint)p2
{
    NSRect tempRect;
    tempRect.origin = NSMakePoint(round(fmin(p1.x, p2.x) - (lineWidth/2) - 1), round(fmin(p1.y, p2.y) - (lineWidth/2) - 1));
    tempRect.size = NSMakeSize((fabs(p1.x - p2.x) + lineWidth + 2), (fabs(p1.y - p2.y) + lineWidth + 2));
    return [self addRectToRedrawRect:tempRect];
}

- (NSRect)addRectToRedrawRect:(NSRect)newRect
{
    // The redraw region should include both the current rectangle and
    // the last action's rectangle
    redrawRect = NSUnionRect(newRect, savedRect);
    
    // Save the current new rectangle for next time
    savedRect = newRect;
    
    // Just to be save, outsed the right of the rectangle by an extra pixel
    // Hack to fix bug with some fonts and the text tool
    redrawRect.size.width += 1.0;
    
    return redrawRect;
}

- (NSRect)invalidRect
{
    return redrawRect;
}

- (BOOL)shouldShowFillOptions
{
    return NO;
}

- (BOOL)shouldShowTransparencyOptions
{
    return NO;
}

- (void)dealloc
{
    [toolboxController removeObserver:self forKeyPath:@"lineWidth"];
    [toolboxController removeObserver:self forKeyPath:@"foregroundColor"];
    [toolboxController removeObserver:self forKeyPath:@"backgroundColor"];
    [toolboxController removeObserver:self forKeyPath:@"fillStyle"];
}


@end
