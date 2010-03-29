//
//  QMController.h
//  QueueManager
//
//  Created by Cory Powers on 12/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PrefController.h"
#import "QueueController.h"
#import "QueueItem.h"
#import "MediaItem.h"


@interface AppController : NSObject {
	NSUserDefaults *defaults;
    
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
    
	PrefController *prefController;
	QueueController *queueController;
	NSString *appSupportDir;
	NSString *appResourceDir;
	NSString *encodeStatusFile;
	NSString *queueFile;
	
	NSTask *encodingTask;
	QueueItem *encodingItem;
	NSFileHandle *encodeOutputHandle;
	NSTimer *outputReadTimer;
	double encodeProgress;
	NSString *encodeETA;
	
	NSTask *metadataTask;
	NSFileHandle *metadataOutputHandle;
	NSTimer *metadataReadTimer;
	MediaItem *metadataItem;

	BOOL runQueue;
	BOOL terminating;
	
	IBOutlet NSWindow *progressWindow;
	IBOutlet NSProgressIndicator *progressBar;
	IBOutlet NSTextField *progressLabel;
}
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (readonly) NSArray *queueItems;

- (id) init;
- (IBAction) saveAction:(id)sender;
- (IBAction) showPreferencesWindow:(id)sender;
- (IBAction) showQueueWindow:(id)sender;
- (BOOL) areFolderActionsEnabledOn: (NSString *)path;
- (void) disableFolderActionOn: (NSString *)path;
- (void) enableFolderActionOn: (NSString *)path;

- (QueueItem *) nextQueueItem;
- (QueueItem *) nextQueueItemAfterItem: (QueueItem *)prevItem;
- (QueueItem *) lastQueueItem;
- (BOOL) moveItemUp: (QueueItem *)anItem;
- (BOOL) moveItemDown: (QueueItem *)anItem;
- (QueueItem *) addFileToQueue: (NSString *)path error:(NSError **)outError;
- (BOOL) processFileName: (MediaItem *)anItem error:(NSError **)outError;
- (BOOL) updateMetadata: (MediaItem *)anItem error:(NSError **)outError;
- (BOOL) writeMetadata: (MediaItem *)anItem error:(NSError **)outError;
- (BOOL) cleanOldTags: (MediaItem *)anItem error:(NSError **) outError;
- (BOOL) writeArt: (MediaItem *)anItem error:(NSError **)outError;
- (BOOL) setHDFlag: (MediaItem *)anItem error:(NSError **)outError;

- (MediaItem *) mediaItemFromFile:(NSString *)path error:(NSError **)outError;

- (BOOL) runQueue;
- (BOOL) isEncodeRunning;
- (BOOL) startEncode:(QueueItem *)anItem;
- (void) stopEncode;
- (QueueItem *) encodingItem;
- (void) taskEnded:(NSNotification *)aNotification;


// Scripting support
- (NSArray *) items;
- (NSScriptObjectSpecifier *) objectSpecifier;
@end
