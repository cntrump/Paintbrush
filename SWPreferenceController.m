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


#import "SWPreferenceController.h"
#import "SWAppController.h"
#import "SWDocument.h"

@implementation SWPreferenceController

- (instancetype)init
{
    if (self = [super initWithWindowNibName:@"Preferences"]) {
    }
     return self;
}

- (void)awakeFromNib
{
    NSArray *fileTypes = [SWDocument writableTypes];
    for (NSString *type in fileTypes)
        [fileTypeButton addItemWithTitle:type];
    
    NSToolbar *toolbar = self.window.toolbar;
    toolbar.selectedItemIdentifier = toolbar.items[0].itemIdentifier;
    
    // Set the initial preference view
    [self.window setContentSize:generalPrefsView.frame.size];
    [self.window.contentView addSubview:generalPrefsView];
    [self.window setTitle:NSLocalizedString(@"General", @"Preferences window: general prefs")];
    currentViewTag = 0;
    //[[[self window] contentView] setWantsLayer:YES];
}

- (void)windowDidLoad
{
    // Load current defaults into the various fields
    undoStepper.stringValue = [NSUserDefaults.standardUserDefaults stringForKey:kSWUndoKey];
    undoTextField.stringValue = [NSUserDefaults.standardUserDefaults stringForKey:kSWUndoKey];
    [fileTypeButton selectItemWithTitle:[NSUserDefaults.standardUserDefaults stringForKey:@"FileType"]];
}

// Sets the default fileType for new documents (can always be set in the save dialog, however)
- (IBAction)changeFileType:(id)sender {
    [NSUserDefaults.standardUserDefaults setValue:[sender titleOfSelectedItem]
                                             forKey:@"FileType"];
}


- (IBAction)changeUndoLimit:(id)sender {
    NSInteger value = [sender stringValue].integerValue;
    if (value == 0) {
        undoStepper.stringValue = @"0";
        undoTextField.stringValue = @"0";
    } else if (value < 0) {
        NSBeep();
        undoStepper.stringValue = @"0";
        undoTextField.stringValue = @"0";
    } else {
        undoStepper.stringValue = [sender stringValue];
        undoTextField.stringValue = [sender stringValue];
    }
    
    [NSUserDefaults.standardUserDefaults setObject:[sender stringValue]
                                              forKey:kSWUndoKey];
    
    // Post a notification that the level has changed
    [[NSNotificationCenter defaultCenter] postNotificationName:kSWUndoKey 
                                                        object:@([sender integerValue])];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
    if (aNotification.object == undoTextField) {
        [self changeUndoLimit:aNotification.object];
    }
}


////////////////////////////////////////////////////////////////////////////////
//////////        Things for the toolbar at the top
////////////////////////////////////////////////////////////////////////////////


- (void)viewForTag:(NSInteger)tag view:(NSView **)view title:(NSString **)title
{
    switch (tag) {
        case 0:
            *view = generalPrefsView;
            *title = NSLocalizedString(@"General", @"Preferences window: general prefs");
            break;
        case 1:
            *view = advancedPrefsView;
            *title = NSLocalizedString(@"Advanced", @"Preferences window: advanced prefs");
            break;
        default:
            break;
    }
}

- (NSRect)newFrameForNewContentView:(NSView *)view
{
    NSRect newFrameRect = [self.window frameRectForContentRect:view.frame];
    NSRect oldFrameRect = self.window.frame;
    NSSize newSize = newFrameRect.size;
    NSSize oldSize = oldFrameRect.size;
    NSRect frame = self.window.frame;
    frame.size = newSize;
    frame.origin.y = frame.origin.y - (newSize.height - oldSize.height);
    return frame;
}

- (IBAction)selectPrefPane:(id)sender
{
    NSInteger tag = [sender tag];
    NSView *view;
    NSString *title;
    [self viewForTag:tag view:&view title:&title];
    self.window.title = title;

    NSView *previousView;
    [self viewForTag:currentViewTag view:&previousView title:&title];
    currentViewTag = tag;
    NSRect newFrame = [self newFrameForNewContentView:view];
    
    // With Core Animation
//    [NSAnimationContext beginGrouping];
//    [[[self window] animator] setFrame:newFrame display:YES];
//    [[[[self window] contentView] animator] replaceSubview:previousView with:view];
//    [NSAnimationContext endGrouping];
    
    // Without Core Animation
    [previousView removeFromSuperview];
    [self.window setFrame:newFrame display:YES animate:YES];
    [self.window.contentView addSubview:view];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    NSMutableArray *selectable = [[NSMutableArray alloc] initWithCapacity:toolbar.items.count];
    for (NSToolbarItem *nsti in toolbar.items) 
    {
        [selectable addObject:nsti.itemIdentifier];
    }
    return selectable;
}


@end
