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


#import <Cocoa/Cocoa.h>

@class SWToolboxController;
@class SWDocument;

typedef NS_ENUM(unsigned int, SWMouseEvent) {
	MOUSE_DOWN, 
	MOUSE_DRAGGED,
	MOUSE_UP,
	MOUSE_MOVED
};

@interface SWTool : NSObject
{
	NSColor *frontColor;
	NSColor *backColor;
	NSBitmapImageRep *drawToMe;
	NSBitmapImageRep *_mainImage;
	NSBitmapImageRep *_bufferImage;
	NSBezierPath *path;
	CGFloat lineWidth;
	BOOL shouldFill;
	BOOL shouldStroke;
	BOOL shouldShowFillOptions;
	BOOL shouldShowTransparencyOptions;
	NSUInteger flags;
	NSPoint savedPoint;
	NSRect redrawRect, savedRect;
	SWToolboxController *toolboxController;
	
	NSCursor *customCursor;
	
	// We need to talk to the document once in a while
	SWDocument *document;
}

- (instancetype)initWithController:(SWToolboxController *)controller NS_DESIGNATED_INITIALIZER;
//- (id)copyWithZone:(NSZone *)zone;

// Some setters
- (void)setFrontColor:(NSColor *)front;
- (void)setBackColor:(NSColor *)back;
- (void)setLineWidth:(CGFloat)width;
- (void)setShouldFill:(BOOL)fill stroke:(BOOL)stroke;


@property (NS_NONATOMIC_IOSONLY) NSPoint savedPoint;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSColor *drawingColor;
- (void)tieUpLooseEnds;
- (void)mouseHasMoved:(NSPoint)aPoint;
- (BOOL)isEqualToTool:(SWTool *)aTool;
- (void)deleteKey;

// Used for faster drawing: don't redraw the entire screen, just this portion
- (NSRect)addRedrawRectFromPoint:(NSPoint)p1 toPoint:(NSPoint)p2;
- (NSRect)addRectToRedrawRect:(NSRect)newRect;
@property (NS_NONATOMIC_IOSONLY, readonly) NSRect invalidRect;
- (void)resetRedrawRect;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL shouldShowContextualMenu;
//- (BOOL)shouldShowFillOptions;
//- (BOOL)shouldShowTransparencyOptions;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSBezierPath *path;

@property (readonly) BOOL shouldShowFillOptions;
@property (readonly) BOOL shouldShowTransparencyOptions;
@property (assign) NSUInteger flags;
@property (retain, readwrite) SWDocument * document;

@end


// Abstract category on SWTool -- the base class doesn't implement these methods at all
@interface SWTool (Abstract)
- (NSBezierPath *)pathFromPoint:(NSPoint)begin toPoint:(NSPoint)end;
- (NSBezierPath *)performDrawAtPoint:(NSPoint)point 
					   withMainImage:(NSBitmapImageRep *)mainImage 
						 bufferImage:(NSBitmapImageRep *)bufferImage 
						  mouseEvent:(SWMouseEvent)event;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) NSCursor *cursor;

@end
