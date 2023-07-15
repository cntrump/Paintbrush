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


@interface SWImageTools : NSObject

+ (void)invertImage:(NSBitmapImageRep *)image;
+ (void)clearImage:(NSBitmapImageRep *)image;
+ (void)clearImage:(NSBitmapImageRep *)image inRect:(NSRect)rect;
+ (void)drawToImage:(NSBitmapImageRep *)dest 
		  fromImage:(NSBitmapImageRep *)src
	withComposition:(BOOL)shouldCompositeOver;
+ (void)drawToImage:(NSBitmapImageRep *)dest 
		  fromImage:(NSBitmapImageRep *)src 
			atPoint:(NSPoint)point
	withComposition:(BOOL)shouldCompositeOver;
+ (void)initImageRep:(NSBitmapImageRep **)imageRep withSize:(NSSize)size;
+ (void)flipImageHorizontal:(NSBitmapImageRep *)bitmap;
+ (void)flipImageVertical:(NSBitmapImageRep *)bitmap;
+ (NSString *)convertFileType:(NSString *)fileType;
+ (BOOL)color:(NSColor *)c1 isEqualToColor:(NSColor *)c2;
+ (void)stripImage:(NSBitmapImageRep *)imageRep ofColor:(NSColor *)color;
+ (NSData *)readImageFromPasteboard:(NSPasteboard *)pb;
+ (NSBitmapImageRep *)cropImage:(NSBitmapImageRep *)image toRect:(NSRect)rect;

// User requested feature!
+ (NSBitmapImageRep *)createMonochromeImage:(NSBitmapImageRep *)baseImage;

// A few things I'd like to try
void SWLockFocus(NSBitmapImageRep *image);
void SWUnlockFocus(NSBitmapImageRep *image);

@end
