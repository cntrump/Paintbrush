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

extern NSString * const kSWCurrentFileType;

@interface SWSavePanelAccessoryViewController : NSViewController {
	// We maintain a different view for certain fileTypes, as well as a default one
	IBOutlet NSView *defaultView;
	IBOutlet NSView *jpegView;
	
	// This is the slot they can go in
	IBOutlet NSView *containerView;
	
	// The currently-selected filetype -- used for KVO
	NSString *currentFileType;
	
	// The controls in our views -- we start with the global popup button
	IBOutlet NSPopUpButton *fileTypeButton;
	
	// Used in the various subviews
	BOOL isAlphaEnabled;
	CGFloat imageQuality;
}

- (void)updateViewForFileType:(NSString *)fileType;
- (NSView *)viewForFileType:(NSString *)fileType;
- (IBAction)fileTypeDidChange:(id)sender;

@property (retain) NSString *currentFileType;

// These values are bound (binded?) to the controls in the various subviews
@property (assign) BOOL isAlphaEnabled;
@property (assign) CGFloat imageQuality;

@end
