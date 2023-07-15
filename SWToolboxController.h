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

typedef enum {
	STROKE_ONLY,
	FILL_ONLY,
	FILL_AND_STROKE
} SWFillStyle;

@class SWColorSelector;
@class SWMatrix;
@class SWToolbox;
@class SWDocument;

@interface SWToolboxController : NSWindowController {	
	NSColor *foregroundColor;
	NSColor *backgroundColor;
	NSString *currentTool;
	NSInteger lineWidth;
	SWFillStyle fillStyle;
	BOOL selectionTransparency;
	
	IBOutlet SWMatrix *toolMatrix;
	IBOutlet SWMatrix *transparencyMatrix;
	IBOutlet SWMatrix *fillMatrix;	
	
	// My toolbox -- used when there's no active document
	SWToolbox *toolbox;
    
    // Active Document
    SWDocument *activeDocument;
}

// Accessors
+ (id)sharedToolboxPanelController;

// Mutators
- (IBAction)changeCurrentTool:(id)sender;
- (IBAction)changeFillStyle:(id)sender;
- (IBAction)changeSelectionTransparency:(id)sender;

// Other stuff
- (void)updateInfo;
- (void)switchToScissors:(id)sender;
- (IBAction)flipColors:(id)sender;

@property (assign) NSInteger lineWidthDisplay;
@property (assign,nonatomic) NSInteger lineWidth;
@property (assign) BOOL selectionTransparency;
@property (assign,nonatomic) NSString *currentTool;
@property (assign) SWFillStyle fillStyle;
@property (retain) NSColor *foregroundColor;
@property (retain) NSColor *backgroundColor;
//
@property (readonly) SWDocument *activeDocument;
//@property (readonly) NSMutableArray *toolListArray;

@end
