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


#import "SWToolboxController.h"
#import "SWToolbox.h"
#import "SWToolList.h"
#import "SWColorSelector.h"
#import "SWDocument.h"
#import "SWMatrix.h"

// Heights for the panel, based on what is shown
#define LARGE_HEIGHT 467
#define SMALL_HEIGHT 367

@implementation SWToolboxController

@synthesize lineWidth;
@synthesize selectionTransparency;
@synthesize currentTool;
@synthesize fillStyle;
@synthesize foregroundColor;
@synthesize backgroundColor;
@synthesize activeDocument;
//@synthesize toolListArray;


// Curiosity...!
- (void)windowDidBecomeKey:(NSNotification *)notification
{
    NSWindow *window = notification.object;

    NSDocumentController *controller = [NSDocumentController sharedDocumentController];
    id document = [controller documentForWindow:window];
    if (document && [document class] == [SWDocument class]) {
        activeDocument = document;
        DebugLog(@"Key window is %@", document);        
    }
}


+ (id)sharedToolboxPanelController
{
    // By calling it static, a second instance of the pointer will never be created
    static SWToolboxController *sharedController;
    
    if (!sharedController) {
        sharedController = [[SWToolboxController alloc] initWithWindowNibName:@"Toolbox"];
    }
    
    return sharedController;
}


// Override the initializer
- (instancetype)initWithWindowNibName:(NSString *)windowNibName
{
    if (self = [super initWithWindowNibName:windowNibName]) {        
        // Curiosity...
        [[NSNotificationCenter defaultCenter] addObserver:self
               selector:@selector(windowDidBecomeKey:)
                   name:NSWindowDidBecomeKeyNotification
                 object:nil];
        
    
        // Do some other initialization stuff
        [NSBezierPath setDefaultLineCapStyle:NSRoundLineCapStyle];
        [NSBezierPath setDefaultLineJoinStyle:NSRoundLineJoinStyle];
        [NSBezierPath setDefaultWindingRule:NSEvenOddWindingRule];
    }
    
    return self;
}


// Alert the observers that something's going on
- (void)awakeFromNib
{    
    // Mah toolbox!  MINE!
    toolbox = [[SWToolbox alloc] initWithDocument:nil];
    
    // Set the starting toolbox info
    self.lineWidthDisplay = 3;
    self.foregroundColor = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    self.backgroundColor = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    self.fillStyle = STROKE_ONLY;
    [self setSelectionTransparency:NO];
    [self changeCurrentTool:toolMatrix];    
}


// Called externally at times
- (void)updateInfo
{
    self.lineWidthDisplay = self.lineWidthDisplay;
    self.foregroundColor = self.foregroundColor;
    self.backgroundColor = self.backgroundColor;
    self.fillStyle = self.fillStyle;
    self.selectionTransparency = self.selectionTransparency;
    [self changeCurrentTool:toolMatrix];    
}


// The slider moved, meaning the line width should change
- (void)setLineWidth:(NSInteger)width
{
    // Allows for more line widths with less tick marks
    lineWidth = 2*width - 2;

    //[currentTool setLineWidth:lineWidth];
}


- (void)setLineWidthDisplay:(NSInteger)width
{
    self.lineWidth = width;
}


- (NSInteger)lineWidthDisplay
{
    return (1+lineWidth) / 2 + 1;
}


- (void)setCurrentTool:(NSString *)tool
{
    // Don't tie up loose ends if there's no tool!
    currentTool = tool;
    
    SWTool *tempTool = [toolbox toolForLabel:currentTool];
        
    [fillMatrix setHidden:(!tempTool.shouldShowFillOptions)];
    [transparencyMatrix setHidden:(!tempTool.shouldShowTransparencyOptions)];
    
    // Handle resizing of tool palette, based on which tool is selected
    NSRect aRect = super.window.frame;
    if (tempTool.shouldShowFillOptions || tempTool.shouldShowTransparencyOptions) {
        aRect.origin.y += (aRect.size.height - LARGE_HEIGHT);
        aRect.size.height = LARGE_HEIGHT;
    } else {
        aRect.origin.y += (aRect.size.height - SMALL_HEIGHT);
        aRect.size.height = SMALL_HEIGHT;
    }
    [super.window setFrame:aRect display:YES animate:YES];
}


- (void)keyDown:(NSEvent *)event
{
    // At the moment, most of the keyboard shortcuts are set in Interface Builder
    NSUInteger modifiers = event.modifierFlags;
    
    if (modifiers & NSEventModifierFlagOption) {
        // They held option
        if (event.keyCode == 125) {
            // They pressed down
            self.lineWidthDisplay = fmax(self.lineWidthDisplay-1,1);
        } else if (event.keyCode == 126) {
            // They pressed up
            self.lineWidthDisplay = self.lineWidthDisplay+1;
        }
    } else {
        // Check the letter pressed
        NSString *string = event.characters.lowercaseString;
        
        switch([string characterAtIndex:0]) {
            case 'a':
                DebugLog(@"AAA");
                break;
        }
    }
}

// The IBActions we'll need
// Replaces the front color with the back, and vice-versa
- (IBAction)flipColors:(id)sender 
{
    NSColor *tempColor = [foregroundColor copy];
    self.foregroundColor = backgroundColor;
    self.backgroundColor = tempColor;
}


// We use the title of the cell to indicate which tool to use
//TODO: Make this localization-friendly
- (IBAction)changeCurrentTool:(id)sender
{
    NSString *string = [[sender selectedCell] title];
    if (string && ![string isEqualToString:@""])
        self.currentTool = string;
}


- (IBAction)changeFillStyle:(id)sender
{
    self.fillStyle = [sender selectedTag];
}


- (IBAction)changeSelectionTransparency:(id)sender
{
    self.selectionTransparency = [sender selectedTag];
}


// If "Paste" or "Select All" is chosen, we should switch to the scissors tool
- (void)switchToScissors:(id)sender
{
    for (NSCell *cell in [toolMatrix cells])
    {
        if ([cell.title isEqualToString:@"Selection"])
        {
            [toolMatrix selectCell:cell];
            [self changeCurrentTool:toolMatrix];
            break;
        }
    }
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
