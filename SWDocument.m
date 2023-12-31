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


#import "SWDocument.h"
#import "SWPaintView.h"
#import "SWScalingScrollView.h"
#import "SWCenteringClipView.h"
#import "SWToolbox.h"
#import "SWToolboxController.h"
#import "SWTextToolWindowController.h"
#import "SWSizeWindowController.h"
#import "SWResizeWindowController.h"
#import "SWToolList.h"
#import "SWAppController.h"
#import "SWSavePanelAccessoryViewController.h"
#import "SWPrintPanelAccessoryViewController.h"
#import "SWImageDataSource.h"

@implementation SWDocument

// Synthesize our properties here
@synthesize toolbox;
@synthesize paintView;

// TODO: Nasty hack
static BOOL kSWDocumentWillShowSheet = YES;

- (instancetype)init
{
    if (self = [super init]) 
    {                
        // Observers for the toolbox
        nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(showTextSheet:)
                   name:@"SWText"
                 object:nil];
        [nc addObserver:self 
               selector:@selector(undoLevelChanged:) 
                   name:kSWUndoKey 
                 object:nil];
        
        // Set levels of undos based on user defaults
        NSNumber *undo = [NSUserDefaults.standardUserDefaults objectForKey:kSWUndoKey];
        self.undoManager.levelsOfUndo = undo.integerValue;
        
        // Create my window's particular tools
        toolbox = [[SWToolbox alloc] initWithDocument:self];
        
    }
    return self;
}


// Housekeeping
- (void)dealloc
{    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [savePanelAccessoryViewController removeObserver:self forKeyPath:kSWCurrentFileType];
}


- (NSString *)windowNibName
{
    return @"MyDocument";
}


- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];

    // We can make the app more responsive by loading these guys at launch
    if (!sizeController)
        sizeController = [[SWSizeWindowController alloc] initWithWindowNibName:@"SizeWindow"];
    
    if (!resizeController)
        resizeController = [[SWResizeWindowController alloc] initWithWindowNibName:@"ResizePanel"];

    toolboxController = [SWToolboxController sharedToolboxPanelController];
    
    clipView = [[SWCenteringClipView alloc] initWithFrame:scrollView.contentView.frame];
    //[clipView setBackgroundColor:[NSColor windowBackgroundColor]];
    
    // The Scroll View contains the clip view, which is the superclass of the paint view (whew!)
    scrollView.contentView = (NSClipView *)clipView;
    clipView.documentView = paintView;
    [scrollView setScaleFactor:1.0 adjustPopup:YES];
    
    // Get and set the background image of the clip view
    NSImage *bgImage = [NSImage imageNamed:@"bgImage"];
    if (bgImage)
        clipView.bgImagePattern = bgImage;
        
    // If the user opened an image
    if (dataSource) 
        [self setUpPaintView];
    else
    {
        // When we create a new document
        if (kSWDocumentWillShowSheet) 
        {
            [aController.window orderFront:self];
            [self raiseSizeSheet:aController];
        }
        else 
        {
            [SWDocument setWillShowSheet:YES];
            dataSource = [[SWImageDataSource alloc] initWithPasteboard];
            [self setUpPaintView];
        }
    }
    
    [paintView setBackgroundColor:[NSColor clearColor]];
}


- (void)setUpPaintView
{
    [paintView preparePaintViewWithDataSource:dataSource
                                      toolbox:toolbox];
    
    // Use external method to determine the window bounds
    NSRect viewRect = paintView.frame;
    NSRect tempRect = [paintView calculateWindowBounds:viewRect];
    
    // Apply the changes to the new document
    [paintView.window setFrame:tempRect display:YES animate:YES];
}


- (NSString *)pathForImageBackgrounds
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *folder = @"~/Library/Application Support/Paintbrush/Background Images/";
    folder = folder.stringByExpandingTildeInPath;
    
    if ([fileManager fileExistsAtPath: folder] == NO)
    {
        [fileManager createDirectoryAtPath: folder attributes: nil];
    }
    
    NSString *fileName = @"bgImage.png";
    return [folder stringByAppendingPathComponent:fileName];   
}

#pragma mark Sheets - Size and Text

////////////////////////////////////////////////////////////////////////////////
//////////        Sheets - Size and Text
////////////////////////////////////////////////////////////////////////////////


// Called when a new document is made
- (IBAction)raiseSizeSheet:(id)sender
{
    [NSApp beginSheet:sizeController.window
       modalForWindow:super.windowForSheet
        modalDelegate:self
       didEndSelector:@selector(sizeSheetDidEnd:returnCode:contextInfo:)
          contextInfo:NULL];
}


// After the sheet ends, this takes over. If the user clicked "OK", a new
// PaintView is initialized. Otherwise, the window closes.
- (void)sizeSheetDidEnd:(NSWindow *)sheet
             returnCode:(NSInteger)returnCode
            contextInfo:(void *)contextInfo
{
    if (returnCode == NSModalResponseOK) 
    {
        NSSize openingSize;
        openingSize.width = [sizeController width];
        openingSize.height = [sizeController height];
        
        // You better be nil at this point!
        NSAssert(dataSource == nil, @"We can't already have a DataSource when creating a document!");

        // Create the data source
        dataSource = [[SWImageDataSource alloc] initWithSize:openingSize];

        // Initial creation
        [self setUpPaintView];
    } 
    else if (returnCode == NSModalResponseCancel)
    {
        // Close the document - they obviously don't want to play
        [super.windowForSheet close];
    }
}


// Called when the user resizes the canvas/image
- (IBAction)raiseResizeSheet:(id)sender
{
    // Sender tag: 1 == image, 0 == canvas
    if ([[sender class] isEqualTo: [NSMenuItem class]])
        [resizeController setScales:[sender tag]];
    
    // Get, and then set, the current document size
    NSSize currSize = dataSource.size;
    [resizeController setCurrentSize:currSize];
    
    [NSApp beginSheet:resizeController.window
       modalForWindow:super.windowForSheet
        modalDelegate:self
       didEndSelector:@selector(resizeSheetDidEnd:returnCode:contextInfo:)
          contextInfo:NULL];
}


// After the sheet ends, this takes over. If the user clicked "OK", a new
// PaintView is initialized. Otherwise, the window closes.
- (void)resizeSheetDidEnd:(NSWindow *)sheet
               returnCode:(NSInteger)returnCode
              contextInfo:(void *)contextInfo
{
    if (returnCode == NSModalResponseOK) 
    {
        NSSize newSize;
        newSize.width = [resizeController width];
        newSize.height = [resizeController height];
        
        // Nothing to do if the size isn't changing!
        if (dataSource.size.width != newSize.width || dataSource.size.height != newSize.height) 
        {
            // This is also important!
            [toolbox tieUpLooseEndsForCurrentTool];

            [self handleUndoWithImageData:nil frame:NSZeroRect];
            
            [dataSource resizeToSize:newSize scaleImage:[resizeController scales]];
            paintView.frame = NSMakeRect(0.0, 0.0, newSize.width, newSize.height); // Forces a redraw
            
            // We should also redraw the clip view
            [clipView setNeedsDisplay:YES];
        }
    }
}


// Keep the current document's undo manager up to date
- (void)undoLevelChanged:(NSNotification *)n
{
    NSNumber *number = n.object;
    self.undoManager.levelsOfUndo = number.integerValue;
}


- (void)showTextSheet:(NSNotification *)n
{
    if (super.windowForSheet.keyWindow) {
        if (!textController)
            textController = [[SWTextToolWindowController alloc] initWithDocument:self];
        
        // Orders the font manager to the front
        [NSApp beginSheet:textController.window
           modalForWindow:super.windowForSheet
            modalDelegate:self
           didEndSelector:@selector(textSheetDidEnd:string:)
              contextInfo:NULL];
        
        [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
        
        // Assigns the current front color (according to the sharedColorPanel) 
        // to the frontColor reference
        [NSColorPanel sharedColorPanel].color = n.object;
        
    }
}


- (void)textSheetDidEnd:(NSWindow *)sheet
                 string:(NSString *)string
{
    // Orders the font manager to exit
    [[[NSFontManager sharedFontManager] fontPanel:NO] orderOut:self];
}


#pragma mark Menu actions (Open, Save, Cut, Print, et cetera)

////////////////////////////////////////////////////////////////////////////////
//////////        Menu actions (Open, Save, Cut, Print, et cetera)
////////////////////////////////////////////////////////////////////////////////


// Override to ensure that the user's file type is set
- (IBAction)saveDocument:(id)sender
{
    [toolbox tieUpLooseEndsForCurrentTool];
    [super saveDocument:sender];
}


// Overridden so that we can reload the image after saving
- (BOOL) saveToURL:(NSURL *)absURL 
            ofType:(NSString *)type 
  forSaveOperation:(NSSaveOperationType)saveOp 
             error:(NSError **)outError
{
    BOOL status = [super saveToURL:absURL ofType:type forSaveOperation:saveOp error:outError];
    
    if (status==YES && (saveOp==NSSaveOperation || saveOp==NSSaveAsOperation))
    {
        NSURL* url = self.fileURL;
        
        // reload the image (this could fail)
        status = [self readFromURL:url ofType:type error:outError];
        
        // re-initialize the UI
        [paintView setNeedsDisplay:YES];
        
//        // Tell the info panel that the url changed
//        [ImageInfoPanel setURL:url];
    }
    
    return status;
}


// Saving data: returns the correctly-formatted image data
- (NSData *)dataOfType:(NSString *)aType error:(NSError **)anError
{
    NSBitmapImageRep *bitmap = dataSource.mainImage;
//    NSBitmapImageRep *bitmap = [SWImageTools createMonochromeImage:[paintView mainImage]];

    [SWImageTools flipImageVertical:bitmap];
        
    NSData *data = nil;
    NSBitmapImageFileType fileType = NSBitmapImageFileTypePNG;
    
    if ([aType isEqualToString:@"bmp"])
        fileType = NSBitmapImageFileTypeBMP;
    else if ([aType isEqualToString:@"png"])
        fileType = NSBitmapImageFileTypePNG;
    else if ([aType isEqualToString:@"jpg"])
        fileType = NSBitmapImageFileTypeJPEG;
    else if ([aType isEqualToString:@"gif"])
        fileType = NSBitmapImageFileTypeGIF;
    else if ([aType isEqualToString:@"tif"])
        fileType = NSBitmapImageFileTypeTIFF;
    else
        DebugLog(@"Error: unknown filetype!");
    
    // We need to retrieve the data stored in the save panel, and pack them into a dictionary
    NSTIFFCompression tiffCompression = (fileType == NSBitmapImageFileTypeJPEG ? NSTIFFCompressionJPEG : NSTIFFCompressionNone);
    CGFloat compressionFactor = savePanelAccessoryViewController.imageQuality;
    //BOOL alpha = [savePanelAccessoryViewController isAlphaEnabled];
    NSDictionary *propDict = @{NSImageCompressionMethod: @(tiffCompression),
                              NSImageCompressionFactor: [NSNumber numberWithFloat:compressionFactor]};
    
    // Convert the image into the data that we need to return
    data = [bitmap representationUsingType:fileType 
                                properties:propDict];
    
    // Remember to re-flip the image after it's been saved!
    [SWImageTools flipImageVertical:bitmap];

    return data;
}


// By overwriting this, we can ask files saved by Paintbrush to open with Paintbrush
// in the future when double-clicked
- (NSDictionary *)fileAttributesToWriteToURL:(NSURL *)absoluteURL
                                      ofType:(NSString *)typeName
                            forSaveOperation:(NSSaveOperationType)saveOperation
                         originalContentsURL:(NSURL *)absoluteOriginalContentsURL
                                       error:(NSError **)outError
{
    NSMutableDictionary *fileAttributes = [[super fileAttributesToWriteToURL:absoluteURL
                                                                      ofType:typeName 
                                                            forSaveOperation:saveOperation
                                                         originalContentsURL:absoluteOriginalContentsURL
                                                                       error:outError] mutableCopy];
    
    // 'Pbsh' has been registered with Apple as our personal four-letter integer
    // NOTE: This attribute is actively ignored as of 10.6.  If we ever require that OS, go
    // ahead and remove this.
    fileAttributes[NSFileHFSCreatorCode] = [NSNumber numberWithUnsignedInt:'Pbsh'];
    return fileAttributes;
}


// Customizing our save panel to provide a few more options for the user
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    if (!savePanelAccessoryViewController) {
        savePanelAccessoryViewController = [[SWSavePanelAccessoryViewController alloc] initWithNibName:@"SavePanelAccessoryView"
                                                                                                bundle:nil];
        [savePanelAccessoryViewController addObserver:self 
                                           forKeyPath:kSWCurrentFileType 
                                              options:NSKeyValueObservingOptionNew 
                                              context:NULL];
    }

    // Update the filetype based on the user defaults (after converting from human readable form)
    NSString *savedValue = [NSUserDefaults.standardUserDefaults valueForKey:@"FileType"];
    currentFileType = [SWImageTools convertFileType:savedValue];
    
    // Make sure that it's loaded its view
    [savePanelAccessoryViewController loadView];
    NSView *accessoryView = [savePanelAccessoryViewController viewForFileType:savedValue];
    if (accessoryView) {
        savePanel.accessoryView = accessoryView;
    }
    
    // Make sure the correct file extension is being used
    savePanel.allowedFileTypes = @[currentFileType];
    
    return YES;
}


// We need to override this because our save panel has its own format popup
- (NSString *)fileTypeFromLastRunSavePanel
{
    return currentFileType;
}


// Whenever the currently-selected filetype changes, this will trigger
- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context
{
    NSString *newFileType = [change valueForKey:NSKeyValueChangeNewKey];
    if (newFileType) 
    {
        currentFileType = newFileType;
        NSSavePanel *savePanel = (NSSavePanel *)savePanelAccessoryViewController.view.window;
        savePanel.allowedFileTypes = @[currentFileType];
    }
}


// Opening an image
- (BOOL)readFromURL:(NSURL *)URL ofType:(NSString *)aType error:(NSError **)anError
{
#pragma unused(aType, anError)
    if (dataSource == nil)
    {
        // Create the data source
        dataSource = [[SWImageDataSource alloc] initWithURL:URL];
    } 
    else
    {
        // We are reloading an image, so we need to just update the data source
        [dataSource initWithURL:URL];
    }

    return (dataSource != nil);
}


// Printing: Cocoa makes it easy!
- (void)printDocument:(id)sender
{
    NSPrintOperation *op = [NSPrintOperation printOperationWithView:paintView
                                                          printInfo:self.printInfo];
    
    SWPrintPanelAccessoryViewController *ppavc = [[SWPrintPanelAccessoryViewController alloc]
                                                   initWithNibName:@"PrintPanelAccessoryView" bundle:nil];
    [op.printPanel addAccessoryController:ppavc];
    [op runOperationModalForWindow:super.windowForSheet
                          delegate:self
                    didRunSelector:NULL
                       contextInfo:NULL];
}

#pragma mark Handling undo

////////////////////////////////////////////////////////////////////////////////
//////////        Handling undo
////////////////////////////////////////////////////////////////////////////////


// Undo canvas resizing
- (void)handleUndoWithImageData:(NSData *)mainImageData frame:(NSRect)frame
{
    NSUndoManager *undo = self.undoManager;
    NSRect currentFrame = NSZeroRect;
    currentFrame.size = dataSource.size;
    NSData *mainImageDataCurrent = [dataSource copyMainImageData];
    [[undo prepareWithInvocationTarget:self] handleUndoWithImageData:mainImageDataCurrent frame:currentFrame];
    
    // Without resize, set the string to drawing
    if (NSEqualSizes(frame.size, NSZeroSize) || NSEqualSizes(frame.size, dataSource.size))
        [undo setActionName:NSLocalizedString(@"Drawing", @"The standard undo command string for drawings")];
    else
    {
        // It doesn't matter here if we scale or not, since we'll be replacing the image in a moment
        [dataSource resizeToSize:frame.size scaleImage:NO];
        paintView.frame = frame;
        [clipView setNeedsDisplay:YES];
        [undo setActionName:NSLocalizedString(@"Resize", @"The undo command string image resizings")];
    }
    
    if (mainImageData == nil)
    {
        // No data was passed, so retrieve it from the data source
        NSData *mainImageData = [dataSource copyMainImageData];
        [[undo prepareWithInvocationTarget:self] handleUndoWithImageData:mainImageData frame:frame];
    }
    
    [dataSource restoreMainImageFromData:mainImageData];
    
    // Only clear the overlay during an undo -- NEVER during the initial setup
    if (undo.undoing)
        [paintView clearOverlay];
    
    // But force a redraw either way
    [paintView setNeedsDisplay:YES];
}


// Called whenever Copy or Cut are called (copies the overlay image to the pasteboard)
// TODO: Relieve some of this method's dependencies on the Selection tool
- (void)writeImageToPasteboard:(NSPasteboard *)pb
{
    NSAssert([[toolbox currentTool] isKindOfClass:[SWSelectionTool class]], 
             @"How are we copying without a SWSelectionTool as the active tool?");
    if ([toolbox.currentTool isKindOfClass:[SWSelectionTool class]])
    {
        SWSelectionTool *currentTool = (SWSelectionTool *)toolbox.currentTool;
        
        NSBitmapImageRep *selectedImage = [currentTool selectedImage];        
        
        // Make sure we flip the image before we put it in the pasteboard
        [SWImageTools flipImageVertical:selectedImage];
        
        [pb declareTypes:@[NSPasteboardTypeTIFF] owner:self];
        [pb setData:selectedImage.TIFFRepresentation forType:NSPasteboardTypeTIFF];
        
        // Now flip it again
        [SWImageTools flipImageVertical:selectedImage];
    }
}


// Cut: same as copy, but clears the overlay
- (IBAction)cut:(id)sender
{
    [self copy:sender];
    [paintView clearOverlay];
}


// Copy
- (IBAction)copy:(id)sender
{
    [self writeImageToPasteboard:[NSPasteboard generalPasteboard]];
}


// Paste
- (IBAction)paste:(id)sender
{
    // Prepare for a paste by allowing an undo
    [self handleUndoWithImageData:nil frame:NSZeroRect];
    [toolboxController switchToScissors:nil];
    
    NSData *data = [SWImageTools readImageFromPasteboard:[NSPasteboard generalPasteboard]];
    if (data)
    {
        [paintView cursorUpdate:nil];
        NSBitmapImageRep *temp = [[NSBitmapImageRep alloc] initWithData:data];

        NSPoint origin = paintView.superview.bounds.origin;
        if (origin.x < 0) origin.x = 0;
        if (origin.y < 0) origin.y = 0;

        NSRect rect = NSZeroRect;
        rect.origin = origin;

        // Use ceiling because pixels can be fractions, but the tool assumes integer values                                 
        rect.size = NSMakeSize(ceil(temp.size.width), ceil(temp.size.height));
        
        [dataSource restoreBufferImageFromData:data];
        
        // As always, flip the image to be viewed in our flipped view
        [SWImageTools flipImageVertical:dataSource.bufferImage];

        [(SWSelectionTool *)toolbox.currentTool setClippingRect:rect
                                                         forImage:dataSource.bufferImage
                                                    withMainImage:dataSource.mainImage];
        [paintView setNeedsDisplay:YES];
    }
}


// Select all
- (IBAction)selectAll:(id)sender
{
    [toolboxController switchToScissors:nil];
    
    [toolbox.currentTool setSavedPoint:NSZeroPoint];
    [toolbox.currentTool performDrawAtPoint:NSMakePoint(paintView.bounds.size.width, paintView.bounds.size.height)
                                withMainImage:dataSource.mainImage 
                                  bufferImage:dataSource.bufferImage 
                                   mouseEvent:MOUSE_UP];
    
    [paintView cursorUpdate:nil];
    [paintView setNeedsDisplay:YES];
}


- (IBAction)zoomIn:(id)sender
{
    if ([sender isKindOfClass:[SWTool class]]) {
        // Came from the zoom tool, so get its point
        NSPoint point = [(SWTool *)sender savedPoint];
        [scrollView setScaleFactor:([scrollView scaleFactor] * 2) atPoint:point adjustPopup:YES];
    } else {
        // Came from somewhere else (probably an NSMenuItem)
        [scrollView setScaleFactor:([scrollView scaleFactor] * 2) adjustPopup:YES];
    }
}


- (IBAction)zoomOut:(id)sender
{
    if ([sender isKindOfClass:[SWTool class]]) {
        // Came from the zoom tool, so get its point
        NSPoint point = [(SWTool *)sender savedPoint];
        [scrollView setScaleFactor:([scrollView scaleFactor] / 2) atPoint:point adjustPopup:YES];
    } else {
        // Came from somewhere else (probably an NSMenuItem)
        [scrollView setScaleFactor:([scrollView scaleFactor] / 2) adjustPopup:YES];
    }
}


- (IBAction)actualSize:(id)sender
{
    [scrollView setScaleFactor:1 adjustPopup:YES];
}


- (IBAction)showGrid:(id)sender
{
    [paintView setShowsGrid:![paintView showsGrid]];
    [sender setState:[paintView showsGrid]];
}


// Decides which menu items to enable, and which to disable (and when)
//- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
    SEL action = anItem.action;
    if ((action == @selector(copy:)) || 
        (action == @selector(cut:)) || 
        (action == @selector(crop:))) 
    {
        return ([[toolbox.currentTool class] isEqualTo:[SWSelectionTool class]] && 
                [(SWSelectionTool *)toolbox.currentTool isSelected]);
    } 
    else if (action == @selector(paste:)) 
    {
        NSArray *array = [NSPasteboard generalPasteboard].types;
        BOOL paste = NO;
        id object;
        for (object in array) 
        {
            if ([object isEqualToString:NSPasteboardTypeTIFF] || [object isEqualToString:NSPICTPboardType])
                paste = YES;
        }
        return paste;
    }
    else if (action == @selector(zoomIn:))
        return [scrollView scaleFactor] < 16;
    else if (action == @selector(zoomOut:))
        return [scrollView scaleFactor] > 0.25;
    else if (action == @selector(showGrid:))
        return [scrollView scaleFactor] > 2.0;
    else if (action == @selector(newFromClipboard:))
        return YES;
    else
        return YES;
}


// TODO: Nasty nasty hack - fix it!
+ (void)setWillShowSheet:(BOOL)showSheet
{
    kSWDocumentWillShowSheet = showSheet;
}


#pragma mark Handling notifications from the toolbox, application controller

////////////////////////////////////////////////////////////////////////////////
//////////        Handling notifications from the toolbox, application controller
////////////////////////////////////////////////////////////////////////////////


- (IBAction)flipHorizontal:(id)sender
{
    if (super.windowForSheet.keyWindow)
    {
        [self handleUndoWithImageData:nil frame:NSZeroRect];
        NSBitmapImageRep *image = dataSource.mainImage;
        [SWImageTools flipImageHorizontal:image];
        [paintView setNeedsDisplay:YES];
    }
}


- (IBAction)flipVertical:(id)sender
{
    if (super.windowForSheet.keyWindow) 
    {
        [self handleUndoWithImageData:nil frame:NSZeroRect];
        NSBitmapImageRep *image = dataSource.mainImage;
        [SWImageTools flipImageVertical:image];
        [paintView setNeedsDisplay:YES];
    }
}


// Used to shrink the image background while also isolating a specific
// section of the image to save
- (IBAction)crop:(id)sender
{
    // First we need to make a temporary copy of what's selected by the selection tool
    if ([toolbox.currentTool isKindOfClass:[SWSelectionTool class]])
    {
        NSRect rect = [(SWSelectionTool *)toolbox.currentTool clippingRect];
        
        NSBitmapImageRep *croppedImage = [(SWSelectionTool *)toolbox.currentTool selectedImage];
        
        // This is also important!
        [toolbox tieUpLooseEndsForCurrentTool];
        
        [self handleUndoWithImageData:nil frame:NSZeroRect];
                
        // Pretend we are a resize
        [dataSource resizeToSize:rect.size scaleImage:NO];
        
        // Set the image
        [dataSource restoreMainImageFromData:croppedImage.TIFFRepresentation];
        
        // Redraw the Paint view and the clip view
        paintView.frame = NSMakeRect(0.0, 0.0, rect.size.width, rect.size.height);
        [clipView setNeedsDisplay:YES];
    }
}


// We offload the heavy lifting to an external class
- (IBAction)invertColors:(id)sender
{
    [self handleUndoWithImageData:nil frame:NSZeroRect];
    [SWImageTools invertImage:dataSource.mainImage];
    [paintView setNeedsDisplay:YES];
}


@end
