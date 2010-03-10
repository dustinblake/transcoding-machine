//
//  QueueController.h
//  QueueManager
//
//  Created by Cory Powers on 12/21/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AppWindowController.h"
#import "QueueItem.h"

@interface QueueController : AppWindowController {
	IBOutlet NSView *statusViewHolder;
	IBOutlet NSView *statusProgressView;
	IBOutlet NSView *statusNoItemView;
	IBOutlet NSProgressIndicator *statusProgressField;
	IBOutlet NSTextField *statusField;
	IBOutlet NSTextField *etaField;
	
	IBOutlet NSWindow *itemWindow;
	IBOutlet NSArrayController *queueItems;
	IBOutlet NSButton *addItemButton;
	IBOutlet NSButton *editItemButton;
	IBOutlet NSButton *startEndcodeButton;
	IBOutlet NSButton *cancelEncodeButton;
	IBOutlet NSTableView *queueItemsTable;
	IBOutlet NSButton *itemUpButton;
	IBOutlet NSButton *itemDownButton;
	
	QueueItem *editingItem;
	
	// Item window outlets
	IBOutlet NSTextField *itemInputField;
	IBOutlet NSTextField *itemOutputField;
	IBOutlet NSTextField *itemTitleField;
	IBOutlet NSTextField *itemShowField;
	IBOutlet NSTextField *itemSeasonField;
	IBOutlet NSTextField *itemEpisodeField;
	IBOutlet NSTextField *itemSummaryField;
	IBOutlet NSTextField *itemDescriptionField;
	IBOutlet NSTextField *itemReleaseDateField;
	IBOutlet NSTextField *itemCopyrightField;
	IBOutlet NSTextField *itemNetworkField;
	IBOutlet NSButton *itemHDVideoButton;
	IBOutlet NSPopUpButton *itemTypePopUp;
	IBOutlet NSPopUpButton *itemGenrePopUp;
	IBOutlet NSTabView *itemTabView;
	IBOutlet NSTextField *itemMessageField;

	IBOutlet NSImageView *itemCoverArtField;
	IBOutlet NSButton *itemSaveButton;
	IBOutlet NSButton *itemCancelButton;
	IBOutlet NSButton *itemProcess;
}
@property (readonly) NSArray *queueItems;
@property (readonly) NSArray *tableSortDescriptors;
@property (readonly) NSArray *genreList;
@property (readonly) NSArray *typeList;

- (id)initWithController: (AppController *)controller;
- (void)populateItemWindowFields: (QueueItem *)anItem;
- (IBAction)showItemWindow: (id)sender;
- (IBAction)closeItemWindow: (id)sender;
- (BOOL)saveItem;
- (IBAction)addQueueItem: (id)sender;
- (IBAction)startEncode: (id)sender;
- (IBAction) browseOutput: (id) sender;
- (void)     browseOutputDone: (NSSavePanel *) sheet
                 returnCode: (int) returnCode 
				contextInfo: (void *) contextInfo;
- (IBAction) browseInput: (id) sender;
- (void)     browseInputDone: (NSSavePanel *) sheet
				   returnCode: (int) returnCode 
				  contextInfo: (void *) contextInfo;
- (void)updateEncodeProgress: (double)progress withEta: (NSString *) eta ofItem: (QueueItem *)item;
- (void)encodeEnded;
- (IBAction)stopEncode: (id)sender;

- (void) rearrangeTable;
- (IBAction)moveItemUp: (id)sender;
- (IBAction)moveItemDown: (id)sender;
- (IBAction)processItem: (id)sender;
- (IBAction)writeMetadata: (id)sender;
- (void)setViewTo: (NSView *)view;
- (void)windowDidBecomeMain:(NSNotification *)notification;
@end
