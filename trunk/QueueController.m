//
//  QueueController.m
//  QueueManager
//
//  Created by Cory Powers on 12/21/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "QueueController.h"
#import "AppController.h"

@implementation QueueController
- (id)init{
	NSLog(@"init called on queue controller");
	return nil;
}

- (id)initWithController:(AppController *)controller {
    if (self = [super initWithController: controller withNibName:@"Queue"]){
        NSAssert([self window], @"[QueueController init] window outlet is not connected in Preferences.nib");
		
		[statusViewHolder addSubview:statusNoItemView];
    }
    return self;
}

- (IBAction)addQueueItem: (id)sender{
	NSManagedObjectContext *moc = [appController managedObjectContext];
	NSEntityDescription *queueEntity = [NSEntityDescription entityForName:@"QueueItem" inManagedObjectContext:moc];
	if(queueEntity){
		NSManagedObject *newItem = [[NSManagedObject alloc] initWithEntity:queueEntity insertIntoManagedObjectContext:moc];
		[newItem setValue:@"newItem" forKey:@"input"];
		[queueItems insertObject:newItem atArrangedObjectIndex:0];
		[queueItems setSelectedObjects:[NSArray arrayWithObject:newItem]];	
	}
	
	[self showItemWindow:sender];
}
- (IBAction)startEncode: (id)sender{
	QueueItem *selectedItem = [[queueItems selectedObjects] objectAtIndex:0];
	[appController startEncode:selectedItem];
}

- (void)populateItemWindowFields: (QueueItem *)anItem {
	NSString *input = [anItem input];
	if (input == nil) {
		input = [NSString string];
	}
	[itemInputField setStringValue:input];
	
	NSString *output = [anItem output];
	if (output == nil) {
		output = [NSString string];
	}
	[itemOutputField setStringValue:output];
	
	NSString *title = [anItem title];
	if (title == nil) {
		title = [NSString string];
	}
	[itemTitleField setStringValue:title];

	NSString *showName = [anItem showName];
	if (showName == nil) {
		showName = [NSString string];
	}
	[itemShowField setStringValue:showName];
	
	NSString *season = [[anItem season] stringValue];
	if (season == nil) {
		season = [NSString string];
	}
	[itemSeasonField setStringValue:season];
	
	NSString *episode = [[anItem episode] stringValue];
	if (episode == nil) {
		episode = [NSString string];
	}
	[itemEpisodeField setStringValue:episode];
	
	NSString *summary = [anItem summary];
	if (summary == nil) {
		summary = [NSString string];
	}
	[itemSummaryField setStringValue:summary];
	
	NSImage *coverArt = [[NSImage alloc] initWithData:[anItem coverArt]];
	[itemCoverArtField setImage:coverArt];
	
	NSString *longDesc = [anItem longDescription];
	if (longDesc == nil) {
		longDesc = [NSString string];
	}
	[itemDescriptionField setStringValue:longDesc];
	
	NSString *copyright = [anItem copyright];
	if (copyright == nil) {
		copyright = [NSString string];
	}
	[itemCopyrightField setStringValue:copyright];
	
	NSString *network = [anItem network];
	if (network == nil) {
		network = [NSString string];
	}
	[itemNetworkField setStringValue:network];
	
	NSNumber *type = [anItem type];
	[itemTypePopUp selectItemWithTitle:nil];
	if ([type intValue] == 1) {
		[itemTypePopUp selectItemWithTitle:@"TV Show"];
	}else if ([type intValue] == 2) {
		[itemTypePopUp selectItemWithTitle:@"Movie"];
	}
	
	[itemGenrePopUp selectItemWithTitle: [anItem genre]];
	
	NSString *message = [anItem message];
	if (message == nil) {
		message = [NSString string];
	}
	[itemMessageField setStringValue:message];
}

- (IBAction)showItemWindow: (id)sender{
	// Setup fields with selected object
	if (sender == addItemButton) {
		// Populate default values
		[itemInputField setStringValue:[NSString string]];
		[itemOutputField setStringValue:[NSString string]];
		[itemTitleField setStringValue:[NSString string]];
		[itemShowField setStringValue:[NSString string]];
		[itemSeasonField setStringValue:[NSString string]];
		[itemEpisodeField setStringValue:[NSString string]];
		[itemSummaryField setStringValue:[NSString string]];
		[itemDescriptionField setStringValue:[NSString string]];
		[itemReleaseDateField setStringValue:[NSString string]];
		[itemCopyrightField setStringValue:[NSString string]];
		[itemNetworkField setStringValue:[NSString string]];
		[itemHDVideoButton setState:NSOffState];
		[itemCoverArtField setImage:nil];
		editingItem = nil;
		[itemWindow makeKeyAndOrderFront:sender];
		[itemTabView selectFirstTabViewItem:sender]; 
		[self browseInput:sender];
	}else{
		// Populate item values
		QueueItem *selectedItem = [[queueItems selectedObjects] objectAtIndex:0];
		editingItem = selectedItem;
		[self populateItemWindowFields:editingItem];
		[itemWindow makeKeyAndOrderFront:sender];
	}
	
}

- (IBAction)closeItemWindow: (id)sender{	
	// Setup fields with selected object
	if (sender == itemSaveButton) {
		NSString *input = [itemInputField stringValue];
		// Validate the input file
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if (![fileManager fileExistsAtPath:input] || ![fileManager isReadableFileAtPath:input]){
			NSRunAlertPanel(@"Invalid input file", @"Invalid input file, make sure the file exists and is readable", @"Ok", nil, nil);
			[itemInputField selectText:sender];
			return;
		}
		
		// Save the object
		[self saveItem];
	}
	
	[itemWindow orderOut:sender];
}

- (BOOL)saveItem {
	NSNumberFormatter *numFormatter = [NSNumberFormatter alloc];
	if (editingItem == nil) {
		NSManagedObjectContext *moc = [appController managedObjectContext];
		NSEntityDescription *queueEntity = [NSEntityDescription entityForName:@"QueueItem" inManagedObjectContext:moc];
		editingItem = [[NSManagedObject alloc] initWithEntity:queueEntity insertIntoManagedObjectContext:moc];
		[queueItems addSelectedObjects:[NSArray arrayWithObject:editingItem]];
		QueueItem *lastItem = [appController lastQueueItem];
		if (lastItem != nil) {
			NSNumber *nextSortOrder = [NSNumber numberWithInt:[[lastItem sortOrder] intValue] + 1];
			[editingItem setSortOrder: nextSortOrder];
		}else{
			[editingItem setSortOrder:[NSNumber numberWithInt:0]];
		}
		
	}
	editingItem.input = [itemInputField stringValue];		
	editingItem.output = [itemOutputField stringValue];		
	editingItem.showName = [itemShowField stringValue];
	editingItem.season = [numFormatter numberFromString:[itemSeasonField stringValue]];
	editingItem.episode = [numFormatter numberFromString:[itemEpisodeField stringValue]];
	editingItem.summary = [itemSummaryField stringValue];
	editingItem.coverArt = [[itemCoverArtField image] TIFFRepresentation];
	editingItem.longDescription = [itemDescriptionField stringValue];
	editingItem.copyright = [itemCopyrightField stringValue];
	editingItem.network = [itemNetworkField stringValue];
	editingItem.releaseDate	= [itemReleaseDateField stringValue];
	if([itemHDVideoButton state] == NSOnState){
		editingItem.hdVideo = [NSNumber numberWithInt:1];
	}else{
		editingItem.hdVideo = [NSNumber numberWithInt:0];
	}
	editingItem.genre = [[itemGenrePopUp selectedItem] title];
	[appController saveAction:nil];
	
	return YES;
}

- (IBAction) browseOutput: (id) sender{
    NSSavePanel * panel = [NSSavePanel savePanel];
	/* We get the current file name and path from the destination field here */
	[panel beginSheetForDirectory: [[itemOutputField stringValue] stringByDeletingLastPathComponent] 
							 file: [[itemOutputField stringValue] lastPathComponent]
				   modalForWindow: itemWindow modalDelegate: self
				   didEndSelector: @selector( browseOutputDone:returnCode:contextInfo: )
					  contextInfo: NULL];
}

- (void) browseOutputDone: (NSSavePanel *) sheet
             returnCode: (int) returnCode 
			contextInfo: (void *) contextInfo{
    if( returnCode == NSOKButton ){
        [itemOutputField setStringValue: [sheet filename]];
    }
}

- (IBAction) browseInput: (id) sender{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
	[panel setAllowsMultipleSelection:FALSE];
	[panel setCanChooseFiles:TRUE];
	[panel setCanChooseDirectories:FALSE];
	
	NSString *input = [itemInputField stringValue];
	NSString *panelDir = nil;
	NSString *panelFile = nil;
	if (input == nil || [input length] == 0) {
		panelDir = [[NSUserDefaults standardUserDefaults] stringForKey:@"monitoredFolder"];
	}else{
		panelDir = [input stringByDeletingLastPathComponent];
		panelFile = [input lastPathComponent];
	}
	
	/* We get the current file name and path from the destination field here */
	[panel beginSheetForDirectory: panelDir 
							 file: panelFile
				   modalForWindow: itemWindow modalDelegate: self
				   didEndSelector: @selector( browseInputDone:returnCode:contextInfo: )
					  contextInfo: NULL];
}

- (void) browseInputDone: (NSSavePanel *) sheet
			   returnCode: (int) returnCode 
			  contextInfo: (void *) contextInfo{
    if( returnCode == NSOKButton ){
		NSError *error;
		QueueItem *newItem = [appController addFileToQueue:[sheet filename] error:&error];
		editingItem = newItem;
		[editingItem retain];
		[self populateItemWindowFields:newItem];
    }
}

- (NSArray *)queueItems{
	return [appController queueItems];
}

- (NSArray *)genreList{
	return [NSArray arrayWithObjects:@"Comedy", @"Drama", @"Nonfiction", @"Other", @"Sports", nil];
}

- (NSArray *)typeList{
	return [NSArray arrayWithObjects:@"TV Show", @"Movie", nil];
}

- (void)windowDidBecomeMain:(NSNotification *)notification{
	NSLog(@"Window did resize");
	NSArray *subviews = [statusViewHolder subviews];
	if ([subviews count] > 0) {
		NSView *currentView = [subviews objectAtIndex:0];
		[statusViewHolder resizeSubviewsWithOldSize:[currentView bounds].size];		
	}
}

- (void)setViewTo:(NSView *)view{
	NSArray *subviews = [statusViewHolder subviews];
	NSView *currentView = [subviews objectAtIndex:0];
	if (currentView != view ) {
		[currentView removeFromSuperview];
		[statusViewHolder addSubview:view];
		[statusViewHolder resizeSubviewsWithOldSize:[view bounds].size];
	}
}

- (void)updateEncodeProgress: (double)progress withEta: (NSString *) eta ofItem: (QueueItem *)item{
	[self setViewTo:statusProgressView];

	// Refresh table for icon update
	[queueItemsTable reloadData];
	[queueItemsTable setNeedsDisplay];
	
	// Disable start button if needed
	if ([startEndcodeButton isEnabled]) {
		[startEndcodeButton setEnabled:FALSE];
	}
	[statusField setStringValue:[item shortName]];
	if (eta == nil) {
		[etaField setStringValue:@"--h--m--s"];
	}else{
		[etaField setStringValue:eta];
	}
	[statusProgressField setDoubleValue:progress];
}

- (void)encodeEnded{
	[queueItemsTable reloadData];
	[queueItemsTable setNeedsDisplay];
	[self setViewTo:statusNoItemView];
	[startEndcodeButton setEnabled:TRUE];
}

- (IBAction)stopEncode: (id)sender{
	[appController stopEncode];
}

- (NSArray *)tableSortDescriptors{
	NSSortDescriptor *sortOrder = [[NSSortDescriptor alloc]
								   initWithKey: @"sortOrder" ascending:YES] ;
	return [NSArray arrayWithObjects: sortOrder, nil];
}

- (void) rearrangeTable{
	[queueItems didChangeArrangementCriteria];	
}

- (IBAction) moveItemUp: (id)sender{
	QueueItem *selectedItem = [[queueItems selectedObjects] objectAtIndex:0];
	if ([appController moveItemUp:selectedItem]) {
		[self rearrangeTable];
	};	
}

- (IBAction) moveItemDown: (id)sender{
	QueueItem *selectedItem = [[queueItems selectedObjects] objectAtIndex:0];
	if ([appController moveItemDown:selectedItem]) {
		[self rearrangeTable];
	};	
}

- (IBAction)processItem: (id)sender{
	[self saveItem];
	NSError *anError;
	[appController updateMetadata: editingItem error:&anError];
	[self populateItemWindowFields:editingItem];
}

- (IBAction)writeMetadata: (id)sender{
	NSError *anError;
	[appController setHDFlag: editingItem error:&anError];
	[appController writeMetadata: editingItem error:&anError];
	[appController writeArt: editingItem error:&anError];
}

@end
