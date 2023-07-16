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


@interface SWImageDataSource : NSObject 
{
    NSBitmapImageRep * mainImage;    // The main storage image
    NSBitmapImageRep * bufferImage;    // The buffer drawn to for temporary actions
    
    NSArray * imageArray;    // Array of images used for drawing (the images above)
    
    NSSize size;            // Cached size
}

// Initializers
- (instancetype)initWithSize:(NSSize)size NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithURL:(NSURL *)url;
- (instancetype)initWithPasteboard;

// Modifiers to the image
- (void)resizeToSize:(NSSize)size
          scaleImage:(BOOL)shouldScale;

// Need to change the image?  We got your back -- here be datas
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSData *copyMainImageData;
- (void)restoreMainImageFromData:(NSData *)tiffData;
- (void)restoreBufferImageFromData:(NSData *)tiffData; // For pasting

// For drawing
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *imageArray;

// Accessing information about the image source
@property (readonly) NSSize size;
@property (readonly) NSBitmapImageRep * mainImage;
@property (readonly) NSBitmapImageRep * bufferImage;

@end
