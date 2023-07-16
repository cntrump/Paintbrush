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


#import "SWPrintPanelAccessoryViewController.h"


@implementation SWPrintPanelAccessoryViewController

- (IBAction)changeScaling:(id)sender
{
    [self setScaling:[sender state] ? YES : NO];
}


- (void)setRepresentedObject:(id)printInfo 
{
    super.representedObject = printInfo;
    NSNumber * shouldScaleValue = [NSUserDefaults.standardUserDefaults objectForKey:@"ScaleImageToFitPage"];
    BOOL shouldScale = YES;
    if (shouldScaleValue != nil)
        shouldScale = shouldScaleValue.boolValue;
    [self setScaling:shouldScale];
}


- (void)setScaling:(BOOL)flag
{
    NSPrintInfo *printInfo = self.representedObject;
    [printInfo dictionary][NSPrintHorizontalPagination] = [NSNumber numberWithInteger:(flag ? NSFitPagination : NSAutoPagination)];
    [printInfo dictionary][NSPrintVerticalPagination] = [NSNumber numberWithInteger:(flag ? NSFitPagination : NSAutoPagination)];    
}


- (BOOL)scaling
{
    NSPrintInfo *printInfo = self.representedObject;
    return ( [[printInfo dictionary][NSPrintVerticalPagination] integerValue] ) == NSFitPagination;
}


- (NSArray *)localizedSummaryItems
{
    return @[@{NSPrintPanelAccessorySummaryItemNameKey: NSLocalizedString(@"Scaling", @"Print panel summary item title for whether the image should be scaled down to fit on a page"),
             NSPrintPanelAccessorySummaryItemDescriptionKey: [self scaling] ? NSLocalizedString(@"On", @"Print panel summary value when scaling is on") : NSLocalizedString(@"Off", @"Print panel summary value when scaling is off")}];    
}


- (NSSet *)keyPathsForValuesAffectingPreview
{
    return [NSSet setWithObject:@"scaling"];
}
@end
