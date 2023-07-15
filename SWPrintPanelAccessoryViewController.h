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


@interface SWPrintPanelAccessoryViewController : NSViewController <NSPrintPanelAccessorizing>

// Connected to the scaling checkbox (defaults to YES)
- (IBAction)changeScaling:(id)sender;

// Called in a few places: updates the print info with our desired scaling
@property (NS_NONATOMIC_IOSONLY) BOOL scaling;

// Methods used for NSPrintPanelAccessorizing protocol
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *localizedSummaryItems;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSSet *keyPathsForValuesAffectingPreview;

@end
