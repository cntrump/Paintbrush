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


#import "SWToolbox.h"
#import "SWToolList.h"
#import "SWToolboxController.h"
#import "SWPaintView.h"
#import "SWDocument.h"

@implementation SWToolbox

@synthesize currentTool;

- (instancetype)initWithDocument:(SWDocument *)doc
{
	self = [super init];
	
	sharedController = [SWToolboxController sharedToolboxPanelController];
	
	// Create the dictionary
	toolList = [[NSMutableDictionary alloc] initWithCapacity:14];
	for (Class c in [SWToolbox toolClassList]) 
	{
		SWTool *tool = [[c alloc] initWithController:sharedController];
		tool.document = doc;
		toolList[tool.description] = tool;
	}
	
	[sharedController addObserver:self 
					   forKeyPath:@"currentTool" 
						  options:NSKeyValueObservingOptionNew 
						  context:NULL];
	
	// Set the initial tool info
	[sharedController updateInfo];
	
	return self;
}


// Don't forget to remove my registration to the toolbox controller!
- (void)dealloc
{
	[sharedController removeObserver:self forKeyPath:@"currentTool"];
}


// Here's the setter for the tool: make sure you wrap up loose ends for the previous tool!
- (void)setCurrentTool:(SWTool *)tool
{
	[currentTool tieUpLooseEnds];
	currentTool = tool;
    
    
    SWToolboxController *controller = [SWToolboxController sharedToolboxPanelController];
    SWDocument *document = controller.activeDocument;
    SWPaintView *view = document.paintView;
    [view cursorUpdate:nil];
    
}


// Something happened!
- (void)observeValueForKeyPath:(NSString *)keyPath 
					  ofObject:(id)object 
						change:(NSDictionary *)change 
					   context:(void *)context
{
	id thing = change[NSKeyValueChangeNewKey];
	
	if ([keyPath isEqualToString:@"currentTool"]) {
		SWTool *tool = [self toolForLabel:thing];
		if (tool) {
			self.currentTool = tool;
		}
	}
}


// Which tool comes from which label?
- (SWTool *)toolForLabel:(NSString *)label
{
	return toolList[[NSString stringWithString:label]];
}


+ (NSArray *)toolClassList
{
	return @[[SWBrushTool class], [SWEraserTool class], [SWSelectionTool class], 
			[SWAirbrushTool class], [SWFillTool class], [SWBombTool class], [SWLineTool class], 
			[SWCurveTool class], [SWRectangleTool class], [SWEllipseTool class], [SWRoundedRectangleTool class], 
			[SWTextTool class], [SWEyeDropperTool class], [SWZoomTool class]];
}


- (void)tieUpLooseEndsForCurrentTool
{
	[currentTool tieUpLooseEnds];
}


@end
