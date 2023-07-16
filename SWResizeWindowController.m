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


#import "SWResizeWindowController.h"
#import "SWDocument.h"

@implementation SWResizeWindowController

@synthesize selectedUnit;


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


// Each time the user types in the width or height field, check to see if it's
// one of the preset values in the popup button
- (void)textDidChange:(NSNotification *)aNotification
{
    NSInteger width, height;
    switch (selectedUnit) {
        case PERCENT:
            width = widthFieldNew.stringValue.integerValue * originalSize.width / 100;
            height = heightFieldNew.stringValue.integerValue * originalSize.height / 100;
            break;
        case PIXELS:
            width = widthFieldNew.stringValue.integerValue;
            height = heightFieldNew.stringValue.integerValue;
            break;
        default:
            DebugLog(@"Error!  The selected units are wrong!");
            return;
    }
    
    newSize = NSMakeSize(width, height);
}


- (void)windowDidBecomeKey:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textDidChange:)
                                                 name:NSControlTextDidChangeNotification
                                               object:nil];
    
    heightFieldOriginal.stringValue = @(originalSize.height).stringValue;
    widthFieldOriginal.stringValue = @(originalSize.width).stringValue;
    
    newSize = originalSize;
    
    switch (selectedUnit) {
        case PERCENT:
            widthFieldNew.stringValue = @"100";
            heightFieldNew.stringValue = @"100";
            break;
        case PIXELS:
            widthFieldNew.stringValue = @(newSize.width).stringValue;
            heightFieldNew.stringValue = @(newSize.height).stringValue;
            break;
        default:
            break;
    }
}


// Convert between percentage and pixels
- (IBAction)changeUnits:(id)sender
{
    switch (selectedUnit) {
        case PERCENT:
            widthFieldNew.stringValue = @(100 * newSize.width / originalSize.width).stringValue;
            heightFieldNew.stringValue = @(100 * newSize.height / originalSize.height).stringValue;
            break;
        case PIXELS:
            widthFieldNew.stringValue = @(newSize.width).stringValue;
            heightFieldNew.stringValue = @(newSize.height).stringValue;
            break;
        default:
            break;
    }
}


// After they click OK or Cancel
- (IBAction)endSheet:(id)sender
{
    if ([sender tag] == NSModalResponseOK) {
        if (widthFieldNew.stringValue.integerValue > 0 && heightFieldNew.stringValue.integerValue > 0) {
            
            // Save entered values as defaults
//            NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
//            NSNumber *width = [NSNumber numberWithInteger:[widthFieldNew integerValue]];
//            NSNumber *height = [NSNumber numberWithInteger:[heightFieldNew integerValue]];
//            [defaults setObject:width forKey:@"HorizontalSize"];
//            [defaults setObject:height forKey:@"VerticalSize"];
            
            [self.window orderOut:sender];
            [NSApp endSheet:self.window returnCode:NSModalResponseOK];
        } else {
            NSBeep();
        }
    } else {
        // They clicked cancel
        [self.window orderOut:sender];
        [NSApp endSheet:self.window returnCode:NSModalResponseCancel];
    }    
}

- (NSInteger)width
{
    return newSize.width;
}

- (NSInteger)height
{
    return newSize.height;
}

- (void)setCurrentSize:(NSSize)currSize
{
    originalSize = currSize;
}

- (BOOL)scales
{
    return scales;
}

- (void)setScales:(BOOL)s
{
    scales = s;
}


@end
