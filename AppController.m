//
//  QMController.m
//  QueueManager
//
//  Created by Cory Powers on 12/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "AppController.h"
#import "SystemEvents.h"
#import "StringToNumberTransformer.h"
#import <RegexKit/RegexKit.h>
#import "TheTVDBProvider.h"

#define FolderActionScriptName @"add to transcoding machine.scpt"
#define EncodeStatusFilename @"tm_encoder.log"
const NSString *QMErrorDomain = @"QMErrors";

@implementation AppController
- (id)init{
    self = [super init];
    if( !self ){
        return nil;
    }
		
	// create an autoreleased instance of our value transformer
	StringToNumberTransformer *sToNTransformer = [[[StringToNumberTransformer alloc] init] autorelease];
	
	// register it with the name that we refer to it with
	[NSValueTransformer setValueTransformer:sToNTransformer		 
									forName:@"StringToNumberTransformer"];		
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(taskEnded:)
												 name:NSTaskDidTerminateNotification
											   object:nil];
	
	runQueue = TRUE;
	
	terminating = FALSE;

    /* Check for check for the app support directory here as
     * outputPanel needs it right away, as may other future methods
     */
    NSString *libraryDir = [NSSearchPathForDirectoriesInDomains( NSLibraryDirectory,
                                                                NSUserDomainMask,
                                                                YES ) objectAtIndex:0];
    appSupportDir = [[[libraryDir stringByAppendingPathComponent:@"Application Support"]
                           stringByAppendingPathComponent:@"TranscodingMachine"] retain];
    if( ![[NSFileManager defaultManager] fileExistsAtPath:appSupportDir] ){
        [[NSFileManager defaultManager] createDirectoryAtPath:appSupportDir
                                                   attributes:nil];
    }
	appResourceDir = [[[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents"] stringByAppendingPathComponent:@"Resources"] retain];
    [PrefController registerUserDefaults: appSupportDir];

	encodeStatusFile = [[appSupportDir stringByAppendingPathComponent:EncodeStatusFilename] retain];
	NSLog(@"Using output file: %@", encodeStatusFile);

	encodeProgress = 0.0;
	encodeETA = [[NSString alloc] initWithString:@"--h--m--s"];
	
	// Initialize controllers
	prefController = [[PrefController alloc] initWithController: self];
	queueController = [[QueueController alloc] initWithController: self];

    return self;
}

/**
 Returns the support directory for the application, used to store the Core Data
 store file.  This code uses a directory named "QueueManager" for
 the content, either in the NSApplicationSupportDirectory location or (if the
 former cannot be found), the system's temporary directory.
 */

- (NSString *)applicationSupportDirectory {
	
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"TranscodingMachine"];
}


/**
 Creates, retains, and returns the managed object model for the application 
 by merging all of the models found in the application bundle.
 */

- (NSManagedObjectModel *)managedObjectModel {
	
    if (managedObjectModel) return managedObjectModel;
	
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
    return managedObjectModel;
}


/**
 Returns the persistent store coordinator for the application.  This 
 implementation will create and return a coordinator, having added the 
 store for the application to it.  (The directory for the store is created, 
 if necessary.)
 */

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {
	
    if (persistentStoreCoordinator) return persistentStoreCoordinator;
	
    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSAssert(NO, @"Managed object model is nil");
        NSLog(@"%@:%s No model to generate a store from", [self class], _cmd);
        return nil;
    }
	
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *applicationSupportDirectory = [self applicationSupportDirectory];
    NSError *error = nil;
    
    if ( ![fileManager fileExistsAtPath:applicationSupportDirectory isDirectory:NULL] ) {
		if (![fileManager createDirectoryAtPath:applicationSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
            NSAssert(NO, ([NSString stringWithFormat:@"Failed to create App Support directory %@ : %@", applicationSupportDirectory,error]));
            NSLog(@"Error creating application support directory at %@ : %@",applicationSupportDirectory,error);
            return nil;
		}
    }
    
    NSURL *url = [NSURL fileURLWithPath: [applicationSupportDirectory stringByAppendingPathComponent: @"storedata"]];
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: mom];
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType 
												  configuration:nil 
															URL:url 
														options:nil 
														  error:&error]){
        [[NSApplication sharedApplication] presentError:error];
        [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
        return nil;
    }    
	
    return persistentStoreCoordinator;
}

/**
 Returns the managed object context for the application (which is already
 bound to the persistent store coordinator for the application.) 
 */

- (NSManagedObjectContext *) managedObjectContext {
	
    if (managedObjectContext) return managedObjectContext;
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    managedObjectContext = [[NSManagedObjectContext alloc] init];
    [managedObjectContext setPersistentStoreCoordinator: coordinator];
	
    return managedObjectContext;
}

/**
 Returns the NSUndoManager for the application.  In this case, the manager
 returned is that of the managed object context for the application.
 */

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [[self managedObjectContext] undoManager];
}


/**
 Performs the save action for the application, which is to send the save:
 message to the application's managed object context.  Any encountered errors
 are presented to the user.
 */

- (IBAction) saveAction:(id)sender {
	
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%s unable to commit editing before saving", [self class], _cmd);
    }
	
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}


/**
 Implementation of the applicationShouldTerminate: method, used here to
 handle the saving of changes in the application managed object context
 before the application terminates.
 */

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	
	if ([self isEncodeRunning]) {
		NSInteger returnCode = NSRunAlertPanel(@"Encode in progress", @"An encoding process is currently running, if you continue the encoding process will be canceled!\n Are you sure you want to quit?", @"Cancel", @"Quit", nil);
		if (returnCode == NSAlertAlternateReturn) {
			[self stopEncode];
			terminating = TRUE;
			return NSTerminateLater;
		}
	}
	
    if (!managedObjectContext) return NSTerminateNow;
	
    if (![managedObjectContext commitEditing]) {
        NSLog(@"%@:%s unable to commit editing to terminate", [self class], _cmd);
        return NSTerminateCancel;
    }
	
    if (![managedObjectContext hasChanges]) return NSTerminateNow;
	
    NSError *error = nil;
    if (![managedObjectContext save:&error]) {
		
        // This error handling simply presents error information in a panel with an 
        // "Ok" button, which does not include any attempt at error recovery (meaning, 
        // attempting to fix the error.)  As a result, this implementation will 
        // present the information to the user and then follow up with a panel asking 
        // if the user wishes to "Quit Anyway", without saving the changes.
		
        // Typically, this process should be altered to include application-specific 
        // recovery steps.  
		
        BOOL result = [sender presentError:error];
        if (result) return NSTerminateCancel;
		
        NSString *question = NSLocalizedString(@"Could not save changes while quitting.  Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];
		
        NSInteger answer = [alert runModal];
        [alert release];
        alert = nil;
        
        if (answer == NSAlertAlternateReturn) return NSTerminateCancel;
		
    }
	
    return NSTerminateNow;
}


/**
 Implementation of dealloc, to release the retained variables.
 */

- (void)dealloc {
	
    [managedObjectContext release];
    [persistentStoreCoordinator release];
    [managedObjectModel release];
	[appSupportDir release];
	[appResourceDir release];
	[encodeStatusFile release];
	[encodeETA release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching: (NSNotification *)aNotification{
	// Check for our folder action script
	NSString *folderActionDest = [@"/Library/Scripts/Folder Action Scripts" stringByAppendingPathComponent:FolderActionScriptName];
	NSLog(@"Looking for folder action script at %@", folderActionDest);
	
	if(![[NSFileManager defaultManager] fileExistsAtPath: folderActionDest]){
		NSString *folderActionSource = [appResourceDir stringByAppendingPathComponent:FolderActionScriptName];
		NSLog(@"NOT FOUND: Copying script from %@", folderActionSource);
		NSError *error;
		if (![[NSFileManager defaultManager] copyItemAtPath:folderActionSource toPath:folderActionDest error:&error]) {
			NSAlert *theAlert = [NSAlert alertWithError:error];
			[theAlert runModal]; // Ignore return value.
		}
	}
}

#pragma mark ===== Encode Management ======

- (BOOL)runQueue{
	if ([self isEncodeRunning]) {
		return NO;
	}
	
	// Start the next item
	if (runQueue == TRUE) {
		
		QueueItem *nextItem = [self nextQueueItem];
		BOOL foundItem = NO;
		while (foundItem == NO) {
			// TODO: Make sure filesize is stable;
			
			

			if([self startEncode:nextItem]){
				foundItem = YES;
			}else {
				nextItem = [self nextQueueItemAfterItem:nextItem];
				if (nextItem == nil) {
					return NO;
				}
			}

		}
		
		
		return [self isEncodeRunning];
	}
	
	return NO;
}

- (BOOL)startEncode:(QueueItem *)anItem {
	if ([self isEncodeRunning]) {
		NSLog(@"Encoding is already running");
		return NO;
	}
	
	if(anItem == nil){
		NSLog(@"nil item passed to startEncode");
		return NO;
	}
	
	// Restart the automatic queue running
	runQueue = TRUE;
	
	NSError *error;
	
	// Clean up old status file
	NSFileManager *defaultManger = [NSFileManager defaultManager];
	if ([defaultManger fileExistsAtPath:encodeStatusFile]) {
		NSLog(@"Removing old log file %@", encodeStatusFile);
		[defaultManger removeItemAtPath:encodeStatusFile
								  error:&error];
	}
	[[NSFileManager defaultManager] createFileAtPath:encodeStatusFile contents:nil attributes:nil];

	encodeProgress = 0.0;
	
	// make task object
	encodingTask = [[NSTask alloc] init];
	encodingItem = [anItem retain];
	// make stdout file
	NSFileHandle *taskStdout = [NSFileHandle fileHandleForWritingAtPath:encodeStatusFile];
	[encodingTask setStandardOutput:taskStdout];
	[encodingTask setStandardError:taskStdout];
	
	
    // set arguments
	NSString *argString = [[NSUserDefaults standardUserDefaults] stringForKey:@"transcoderArgs"];
	NSArray *argArray = [argString componentsSeparatedByString:@" "];
    NSMutableArray *taskArgs = [NSMutableArray array];
	for(NSString *inputArg in argArray){
		if ([inputArg isEqual:@"|INPUT|"]) {
			[taskArgs addObject:[anItem input]];
		}else if ([inputArg isEqual:@"|OUTPUT|"]) {
			[taskArgs addObject:[anItem output]];
		}else{
			[taskArgs addObject:inputArg];
		}
	}
	NSLog(@"Starting task with arguments: %@", [taskArgs componentsJoinedByString:@" "]);
    [encodingTask setArguments:taskArgs];
	
	// launch
    [encodingTask setLaunchPath:[[NSUserDefaults standardUserDefaults] stringForKey:@"transcoderPath"]];
    [encodingTask launch];
	[encodingItem setStatus:[NSNumber numberWithInt:1]];
	[self saveAction:nil];
	// Check to make sure there wasn't an immediate failure
	if ([self isEncodeRunning]) {
		// Store the pid in case we die
		NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
		[standardDefaults setObject:[NSNumber numberWithInt:[encodingTask processIdentifier]] forKey:@"encodePid"];
		 
		[queueController updateEncodeProgress:0.0 withEta:nil ofItem:[self encodingItem]];
		// Setup the timer and status file
		outputReadTimer = [[NSTimer scheduledTimerWithTimeInterval: 2 
														   target: self 
														 selector:@selector(outputTimerFired:)
														 userInfo: nil
														  repeats: TRUE] retain];
		encodeOutputHandle = [[NSFileHandle fileHandleForReadingAtPath:encodeStatusFile] retain];
		
		return YES;
	}
	
	return NO;
}

- (void)outputTimerFired:(NSTimer*)theTimer{
	// Read the last line
	NSLog(@"Output read timer fired");
	NSString *fileData = [[NSString alloc] initWithData:[encodeOutputHandle readDataToEndOfFile] 
													encoding:NSASCIIStringEncoding];
	NSArray *lines = [fileData componentsSeparatedByString:@"\r"];
	NSLog(@"Found %d lines", [lines count]);
	NSString *lastLine = [lines objectAtIndex:[lines count] - 1];
	NSLog(@"Last line: %@", lastLine);
	// Extract required info from last line
	NSString *encodeProgressString;
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	if(![lastLine getCapturesWithRegexAndReferences:@".*, (\\d+.\\d+) %.*ETA ([\\dhms]+).*", @"${1}", &encodeProgressString, @"${2}", &encodeETA, nil]){
		NSLog(@"Could not match pattern");
		encodeProgress = 0.0;
		encodeETA = [[NSString alloc] initWithString:@"--h--m--s"];
	}else{
		encodeProgress = [[formatter numberFromString:encodeProgressString] doubleValue];
		[queueController updateEncodeProgress:encodeProgress withEta:encodeETA ofItem:[self encodingItem]];
	}
	NSLog(@"Current progress %f, eta %@", encodeProgress, encodeETA);
	[formatter release];
	[fileData release];
}

- (BOOL)isEncodeRunning {
	if (encodingItem != nil && encodingTask != nil) {
		return TRUE;
	}
	
	return FALSE;
}

- (void)taskEnded:(NSNotification *)aNotification {
	QueueItem *currentItem = [self encodingItem];
	NSTask *notifyingTask = [aNotification object];
	NSError *error;
	BOOL encodeSucceeded = NO;
	
	if (notifyingTask == encodingTask) {
		NSLog(@"The encoding task has stopped");
	}else{
		return;
	}
	int status = [notifyingTask terminationStatus];
    if (status == 0){
		// See if output file exists. Sometimes handbrake exits with 0 code without working
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if ([fileManager fileExistsAtPath:[currentItem output]]){
			encodeSucceeded = YES;
			NSLog(@"Task succeeded.");
		}
	}


	// Clear out our cached encode pid 
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	[standardDefaults setObject:[NSNumber numberWithInt:0] forKey:@"encodePid"];

	
	// Update the queue item's status
	[queueController encodeEnded];
	
	// Clean up
	[outputReadTimer invalidate];
	[outputReadTimer release];
	outputReadTimer = nil;
	[encodingItem release];
	encodingItem = nil;
	[encodingTask release];
	encodingTask = nil;
	[encodeOutputHandle release];
	encodeOutputHandle = nil;

	if (encodeSucceeded == YES) {
		[self setHDFlag:currentItem error:&error];
		[self writeMetadata:currentItem error:&error];
		[self writeArt:currentItem error:&error];
		[currentItem setStatus:[NSNumber numberWithInt:255]];
	}else {
		NSFileHandle *logHandle = [NSFileHandle fileHandleForReadingAtPath:encodeStatusFile];
		NSString *fileData = [[NSString alloc] initWithData:[logHandle readDataToEndOfFile] 
												   encoding:NSASCIIStringEncoding];
		[currentItem setMessage:fileData];
		[currentItem setStatus:[NSNumber numberWithInt:3]];
	}

	[self saveAction:nil];	
	// If the user requested to terminate then do so
	if (terminating == TRUE) {
		[[NSApplication sharedApplication] replyToApplicationShouldTerminate: YES];
	}else {
		[self runQueue];
	}
}

- (BOOL) writeMetadata: (QueueItem *)anItem error:(NSError **) outError {
//	NSString *mp4tagsLogPath = [[self applicationSupportDirectory] stringByAppendingPathComponent:@"mp4tags.log"];
//	
//	[[NSFileManager defaultManager] createFileAtPath:mp4tagsLogPath contents:nil attributes:nil];

	NSTask *mp4tagsTask = [[NSTask alloc] init];
	// make stdout file
//	NSFileHandle *taskStdout = [NSFileHandle fileHandleForWritingAtPath:mp4tagsLogPath];
//	[mp4tagsTask setStandardOutput:taskStdout];
	
	
    // set arguments
    NSMutableArray *taskArgs = [NSMutableArray array];
	if ([anItem episodeId] != [NSString string]) {
		[taskArgs addObject:@"-o"];
		[taskArgs addObject: [anItem episodeId]];
		[taskArgs addObject:@"-I"];
		[taskArgs addObject: [anItem episodeId]];
	}
	if ([anItem hdVideo] != nil) {
		[taskArgs addObject:@"-H"];
		[taskArgs addObject: [[anItem hdVideo] stringValue]];		
	}
	if ([anItem title] != nil) {
		[taskArgs addObject:@"-s"];
		[taskArgs addObject: [anItem title]];		
	}
	if ([anItem showName] != nil) {		
		[taskArgs addObject:@"-a"];
		[taskArgs addObject: [anItem showName]];
		[taskArgs addObject:@"-S"];
		[taskArgs addObject: [anItem showName]];
	}
	if ([anItem releaseDate] != nil) {
		[taskArgs addObject:@"-y"];
		[taskArgs addObject: [anItem releaseDate]];		
	}
	if ([anItem summary] != nil) {
		[taskArgs addObject:@"-m"];
		[taskArgs addObject: [anItem summary]];		
	}
	if ([anItem longDescription] != nil) {
		[taskArgs addObject:@"-l"];
		[taskArgs addObject: [anItem longDescription]];		
	}
	if ([anItem episode] != nil) {
		[taskArgs addObject:@"-t"];
		[taskArgs addObject: [[anItem episode] stringValue]];
		[taskArgs addObject:@"-M"];
		[taskArgs addObject: [[anItem episode] stringValue]];		
	}
	if ([anItem network] != nil) {
		[taskArgs addObject:@"-N"];
		[taskArgs addObject: [anItem network]];		
	}
	if ([anItem season] != nil) {
		[taskArgs addObject:@"-n"];
		[taskArgs addObject: [[anItem season] stringValue]];
		[taskArgs addObject:@"-d"];
		[taskArgs addObject: [[anItem season] stringValue]];		
	}
	[taskArgs addObject:@"-i"];
	if ([[anItem type] intValue] == ItemTypeTV) {
		[taskArgs addObject:@"tvshow"];
	}else {
		[taskArgs addObject:@"movie"];
	}

	[taskArgs addObject:[anItem output]];
	
	NSLog(@"Starting task with arguments: %@", [taskArgs componentsJoinedByString:@" "]);
    [mp4tagsTask setArguments:taskArgs];
	
	// launch
    [mp4tagsTask setLaunchPath:[appResourceDir stringByAppendingPathComponent:@"mp4tags"]];
    [mp4tagsTask launch];
	
	while ([mp4tagsTask isRunning]) {
		sleep(1);
	}
	NSLog(@"tags task ended with status %d", [mp4tagsTask terminationStatus]);
	return YES;
}

- (BOOL) writeArt: (QueueItem *)anItem error:(NSError **) outError {
	if([anItem coverArt] == nil){
		return YES;
	}
	
	NSTask *mp4artTask = [[NSTask alloc] init];
	NSString *tempArtPath = [[self applicationSupportDirectory] stringByAppendingPathComponent:@"coverart.jpg"];
	if([[anItem coverArt] writeToFile:tempArtPath atomically:NO] == NO){
		return NO;
	};

    // set arguments
    NSMutableArray *taskArgs = [NSMutableArray array];
	[taskArgs addObject:@"--keepgoing"];
	[taskArgs addObject:@"--remove"];
	[taskArgs addObject:@"--art-any"];
	[taskArgs addObject:[anItem output]];
	
	NSLog(@"Starting task with arguments: %@", [taskArgs componentsJoinedByString:@" "]);
    [mp4artTask setArguments:taskArgs];
	
	// launch
    [mp4artTask setLaunchPath:[appResourceDir stringByAppendingPathComponent:@"mp4art"]];
    [mp4artTask launch];
	
	while ([mp4artTask isRunning]) {
		sleep(1);
	}
	
	NSLog(@"art clear task ended with status %d", [mp4artTask terminationStatus]);

	NSTask *mp4artAddTask = [[NSTask alloc] init];
	[taskArgs removeAllObjects];
	[taskArgs addObject:@"--keepgoing"];
	[taskArgs addObject:@"--add"];
	[taskArgs addObject:tempArtPath];
	[taskArgs addObject:@"--art-index"];
	[taskArgs addObject:@"0"];
	[taskArgs addObject:[anItem output]];
	
	NSLog(@"Starting task with arguments: %@", [taskArgs componentsJoinedByString:@" "]);
    [mp4artAddTask setArguments:taskArgs];
	
	// launch
    [mp4artAddTask setLaunchPath:[appResourceDir stringByAppendingPathComponent:@"mp4art"]];
    [mp4artAddTask launch];
	
	while ([mp4artAddTask isRunning]) {
		sleep(1);
	}
	
	NSLog(@"art add task ended with status %d", [mp4artAddTask terminationStatus]);
	return YES;
}

- (BOOL) setHDFlag: (QueueItem *)anItem error:(NSError **) outError {
	NSTask *mp4trackTask = [[NSTask alloc] init];
	NSPipe *mp4trackStdoutPipe = [NSPipe pipe];
	NSFileHandle *mp4trackStdoutHandle = [mp4trackStdoutPipe fileHandleForReading];
	[mp4trackTask setStandardOutput:mp4trackStdoutPipe];
	
	// set arguments
    NSMutableArray *taskArgs = [NSMutableArray array];
	[taskArgs addObject:@"--list"];
	[taskArgs addObject:[anItem output]];
	
	NSLog(@"Starting task with arguments: %@", [taskArgs componentsJoinedByString:@" "]);
    [mp4trackTask setArguments:taskArgs];
	
	// launch
    [mp4trackTask setLaunchPath:[appResourceDir stringByAppendingPathComponent:@"mp4track"]];
    [mp4trackTask launch];
	
	NSData *outputData = nil;
	while ([mp4trackTask isRunning]) {
		sleep(1);
	}
	
	outputData = [mp4trackStdoutHandle readDataToEndOfFile];
	
	NSString *output = [[NSString alloc] initWithData:outputData encoding:NSASCIIStringEncoding];
	NSArray *lines = [output componentsSeparatedByString:@"\n"];
	NSLog(@"Found %d lines", [lines count]);
	NSString *keyName = nil;
	NSString *value = nil;
	NSNumber *width = nil;
	BOOL foundVideo = NO;
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	for(NSString *line in lines){
		NSLog(@"Looking at line %@", line);
		if([line getCapturesWithRegexAndReferences:@"\\s*([a-zA-Z]+)\\s*=\\s*([a-zA-Z0-9]+)", @"${1}", &keyName, @"${2}", &value, nil]){
			NSLog(@"Matched line: %@=%@", keyName, value);
			if ([keyName isEqualToString:@"type"] && [value isEqualToString:@"video"]) {
				foundVideo = YES;
				NSLog(@"Found video track");
			}
			if (foundVideo && [keyName isEqualToString:@"height"] ) {
				NSLog(@"Found width %@", value);
				width = [formatter numberFromString:value];
				break;
			}
		}
	}
	
	NSLog(@"mp4track task ended with status %d", [mp4trackTask terminationStatus]);
	if([width intValue] >= 720){
		NSLog(@"Setting hd flag to 1");
		[anItem setHdVideo:[NSNumber numberWithInt:1]];
	}else{
		NSLog(@"Setting hd flag to 0");
		[anItem setHdVideo:[NSNumber numberWithInt:0]];
	}
		
	return YES;
}

- (void)stopEncode{
	if ([self isEncodeRunning]) {
		runQueue = FALSE;
		[encodingTask terminate];
	}
}

- (QueueItem *)encodingItem{
	return encodingItem;
}

#pragma mark ===== Queue Management ======

- (QueueItem *) addFileToQueue:(NSString *)path error:(NSError **) outError {
	NSMutableDictionary *errorDict = [NSMutableDictionary dictionary];
	QueueItem *newItem;
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDir = NO;
	if (![fileManager fileExistsAtPath:path isDirectory:&isDir] || ![fileManager isReadableFileAtPath:path] || isDir){
		NSString *errorMsg = [NSString stringWithFormat:@"%@ does not exist or is not readable", path];
		[errorDict setObject:errorMsg forKey:NSLocalizedDescriptionKey];
		*outError = [[[NSError alloc] initWithDomain:@"QMErrors" code:100 userInfo:errorDict] autorelease];
		return NO;
	}
	
	NSString *extensionList = [[NSUserDefaults standardUserDefaults] objectForKey:@"allowedExtensions"];
	NSArray *extensions = [extensionList componentsSeparatedByString:@","];
	NSString *fileExtension = [path pathExtension];
	BOOL validExtension = NO;
	if (fileExtension != nil && ![fileExtension isEqualToString:@""]){
		for(NSString *ext in extensions){
			if ([ext isEqualToString:fileExtension]) {
				validExtension = YES;
				break;
			}
		}
	}

	
	if (validExtension == NO){
		NSString *errorMsg = [NSString stringWithFormat:@"%@ does not have an allowed extension", path];
		[errorDict setObject:errorMsg forKey:NSLocalizedDescriptionKey];
		*outError = [[[NSError alloc] initWithDomain:@"QMErrors" code:101 userInfo:errorDict] autorelease];
		return NO;		
	}

	NSManagedObjectContext *moc = [self managedObjectContext];
	NSEntityDescription *queueEntity = [NSEntityDescription entityForName:@"QueueItem" inManagedObjectContext:moc];
	if(queueEntity){
		newItem = [[NSManagedObject alloc] initWithEntity:queueEntity insertIntoManagedObjectContext:moc];
		[newItem setValue:path forKey:@"input"];
		QueueItem *lastItem = [self lastQueueItem];
		[newItem setSortOrder:[NSNumber numberWithInt:[[lastItem sortOrder] intValue] + 1]];
		 
		// Set output path
		NSString *basename = [[path lastPathComponent] stringByDeletingPathExtension];
		NSString *outputPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"outputFolder"];
		[newItem setOutput:[NSString stringWithFormat:@"%@/%@.m4v", outputPath, basename]];
		if (![self processFileName:newItem error:outError]) {
			NSLog(@"Unable to process filename");
		}

		if([self updateMetadata:newItem error:outError] == NO){
			NSLog(@"Unable to process metadata");
		}
	}
	
	[self saveAction:nil];
	[queueController rearrangeTable];
	
	// Start the queue if necessary
	[self runQueue];
	return newItem;
}

- (BOOL) processFileName: (QueueItem *)anItem error:(NSError **) outError {
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	
	NSMutableArray *patterns = [[NSMutableArray alloc] init];
	[patterns addObject:@"(.+)[sS][eE]*\\s*(\\d+)[eE]\\s*(\\d+)"];
	[patterns addObject:@"(.+)[sS][eE]*\\s*(\\d+)\\s*-\\s*[eE]\\s*(\\d+)"];
	[patterns addObject:@"(.+)Season\\s*(\\d+)\\s*Episode\\s*(\\d+)"];
	[patterns addObject:@"(.+?)([0-9][0-9])x([0-9][0-9]?)"];
	[patterns addObject:@"(.+?)([0-9])x([0-9][0-9]?)"];
	[patterns autorelease];

	NSString *filename = [[anItem input] lastPathComponent];
	NSLog(@"Checking filename %@", filename);
	NSString *showName = nil;
	NSString *episodeString = nil;
	NSString *seasonString = nil;
	for(NSString *pattern in patterns) {
		if([filename getCapturesWithRegexAndReferences:pattern, @"${1}", &showName, @"${2}", &seasonString, @"${3}", &episodeString, nil]){
			NSLog(@"Matched on pattern %@", pattern);
			if(showName == nil || seasonString == nil){
				continue;
			}
			
			// Try some cleanup on the show name
			showName = [showName stringByReplacingOccurrencesOfString:@"." withString:@" "];
			showName = [showName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			
			[anItem setType: [NSNumber numberWithInt:ItemTypeTV]];
			[anItem setTitle: [NSString stringWithFormat:@"%@ S%dE%d", showName, seasonString, episodeString]];
			[anItem setShowName:showName];
			[anItem setSeason:[formatter numberFromString:seasonString]];
			[anItem setEpisode:[formatter numberFromString:episodeString]];
			NSLog(@"Show: %@", showName);
			NSLog(@"Season: %@", seasonString);
			NSLog(@"Episode: %@", episodeString);
			return YES;
		}else{
			NSLog(@"Did not match with pattern %@", pattern);
		}
	}
	
	// See if its a movie
	[patterns removeAllObjects];
	[patterns addObject:@"(.+)\\s*(\\d{4})"];
	NSString *yearString = nil;
	for(NSString *pattern in patterns) {
		if([filename getCapturesWithRegexAndReferences:pattern, @"${1}", &showName, @"${2}", &yearString, nil]){
			NSLog(@"Matched on pattern %@", pattern);
			if(showName == nil || yearString == nil){
				continue;
			}
			
			// Try some cleanup on the show name
			showName = [showName stringByReplacingOccurrencesOfString:@"." withString:@" "];
			showName = [showName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			
			[anItem setType: [NSNumber numberWithInt:ItemTypeMovie]];
			[anItem setTitle:showName];
			[anItem setShowName:showName];
			NSLog(@"Show: %@", showName);
			NSLog(@"Year: %@", yearString);
			return YES;
		}else{
			NSLog(@"Did not match with pattern %@", pattern);
		}
	}
	
	//Take everything before the dash and use that as the title, assume movie
	[patterns removeAllObjects];
	[patterns addObject:@"(.+)\\s*-.*"];
	for(NSString *pattern in patterns) {
		if([filename getCapturesWithRegexAndReferences:pattern, @"${1}", &showName, nil]){
			NSLog(@"Matched on pattern %@", pattern);
			if(showName == nil){
				continue;
			}
			
			// Try some cleanup on the show name
			showName = [showName stringByReplacingOccurrencesOfString:@"." withString:@" "];
			showName = [showName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			
			[anItem setType: [NSNumber numberWithInt:ItemTypeMovie]];
			[anItem setTitle:showName];
			[anItem setShowName:showName];
			NSLog(@"Show: %@", showName);
			return YES;
		}else{
			NSLog(@"Did not match with pattern %@", pattern);
			[anItem setTitle:filename];
			[anItem setShowName:filename];
			[anItem setType: [NSNumber numberWithInt:ItemTypeMovie]];
		}
	}
	
	
	// return yes because there was no error even if we could not figure anything out
	return YES;
}

- (BOOL) updateMetadata: (QueueItem *)anItem error:(NSError **) outError {
	if ([[anItem type] intValue] == ItemTypeTV) {
		TheTVDBProvider *ttdProvider = [[TheTVDBProvider alloc] initWithAnItem:anItem];
		if ([ttdProvider applyMetadata] == NO) {
			NSMutableDictionary *errorDict = [NSMutableDictionary dictionary];
			NSString *errorMsg = [NSString stringWithFormat:@"Could not get metadata for item"];
			[errorDict setObject:errorMsg forKey:NSLocalizedDescriptionKey];
			*outError = [[[NSError alloc] initWithDomain:@"QMErrors" code:110 userInfo:errorDict] autorelease];
			return NO;
		};		
	}else{
		//TODO: Implemente movie api
	}
	
	return YES;
}

- (NSArray *)queueItems{
	NSLog(@"Someone asked for queueItems");
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSFetchRequest *request = [[NSFetchRequest alloc] init] ;
	NSEntityDescription *entity = [NSEntityDescription entityForName: @"QueueItem"
											  inManagedObjectContext: moc];
	[request setEntity: entity];
	NSSortDescriptor *sortOrder = [[NSSortDescriptor alloc]
									  initWithKey: @"sortOrder" ascending:YES] ;
	NSArray *sortDescriptors = [NSArray arrayWithObjects: sortOrder, nil];
	[request setSortDescriptors: sortDescriptors];
	[sortOrder release];
	NSError *anyError;
	NSArray *fetchedObjects = [moc executeFetchRequest: request
													  error: &anyError] ;
	[request release] ;
	if( fetchedObjects == nil ) { /* do something with anyError */ }	
	return fetchedObjects;
}

- (QueueItem *)nextQueueItem{
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSFetchRequest *request = [[NSFetchRequest alloc] init] ;
	NSEntityDescription *entity = [NSEntityDescription entityForName: @"QueueItem"
											  inManagedObjectContext: moc];
	[request setEntity: entity];
	NSPredicate *condition = [NSPredicate predicateWithFormat:@"status = 0"];
	[request setPredicate:condition];
	[request setFetchLimit:1];
	NSSortDescriptor *sortOrder = [[NSSortDescriptor alloc]
								   initWithKey: @"sortOrder" ascending:YES] ;
	NSArray *sortDescriptors = [NSArray arrayWithObjects: sortOrder, nil];
	[request setSortDescriptors: sortDescriptors];
	[sortOrder release];
	NSError *anyError;
	NSArray *fetchedObjects = [moc executeFetchRequest: request
												 error: &anyError] ;
	[request release] ;
	if([fetchedObjects count] == 1){
		return [fetchedObjects objectAtIndex:0];
	}
	
	return nil;
}

- (QueueItem *)nextQueueItemAfterItem: (QueueItem *)prevItem{
	NSArray *queueItems = [self queueItems];
	BOOL foundPrevious = NO;
	for(QueueItem *item in queueItems){
		if (foundPrevious == YES) {
			return item;
		}else if (item == prevItem) {
			foundPrevious = YES;
		}
	}
	return nil;
}

- (QueueItem *)lastQueueItem{
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSFetchRequest *request = [[NSFetchRequest alloc] init] ;
	NSEntityDescription *entity = [NSEntityDescription entityForName: @"QueueItem"
											  inManagedObjectContext: moc];
	[request setEntity: entity];
//	NSPredicate *condition = [NSPredicate predicateWithFormat:@"status < 255"];
//	[request setPredicate:condition];
	[request setFetchLimit:1];
	NSSortDescriptor *sortOrder = [[NSSortDescriptor alloc]
								   initWithKey: @"sortOrder" ascending:NO] ;
	NSArray *sortDescriptors = [NSArray arrayWithObjects: sortOrder, nil];
	[request setSortDescriptors: sortDescriptors];
	[sortOrder release];
	NSError *anyError;
	NSArray *fetchedObjects = [moc executeFetchRequest: request
												 error: &anyError] ;
	[request release] ;
	if([fetchedObjects count] == 1){
		return [fetchedObjects objectAtIndex:0];
	}
	
	return nil;
}

- (BOOL)moveItemUp:(QueueItem *)anItem{
	// Get the item before this one
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSFetchRequest *request = [[NSFetchRequest alloc] init] ;
	NSEntityDescription *entity = [NSEntityDescription entityForName: @"QueueItem"
											  inManagedObjectContext: moc];
	[request setEntity: entity];
	NSPredicate *condition = [NSPredicate predicateWithFormat:@"sortOrder < %d AND status == 0", [[anItem sortOrder] intValue]];
	[request setPredicate:condition];
	[request setFetchLimit:1];
	NSSortDescriptor *sortOrder = [[NSSortDescriptor alloc]
								   initWithKey: @"sortOrder" ascending:NO] ;
	NSArray *sortDescriptors = [NSArray arrayWithObjects: sortOrder, nil];
	[request setSortDescriptors: sortDescriptors];
	[sortOrder release];
	NSError *anyError;
	NSArray *fetchedObjects = [moc executeFetchRequest: request
												 error: &anyError] ;
	[request release];
	NSLog(@"Looking up item matching: %@", condition);
	
	if ([fetchedObjects count] == 1) {
		QueueItem *prevItem = [fetchedObjects objectAtIndex:0];
		NSNumber *prevSortOrder = [prevItem sortOrder];
		NSLog(@"Found item with previous sort order %@", prevSortOrder);
		[prevItem setSortOrder: [anItem sortOrder]];
		[anItem setSortOrder: prevSortOrder];
		[self saveAction:nil];
		return TRUE;
	}
	
	return FALSE;
}

- (BOOL)moveItemDown:(QueueItem *)anItem{
	// Get the item after this one
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSFetchRequest *request = [[NSFetchRequest alloc] init] ;
	NSEntityDescription *entity = [NSEntityDescription entityForName: @"QueueItem"
											  inManagedObjectContext: moc];
	[request setEntity: entity];
	NSPredicate *condition = [NSPredicate predicateWithFormat:@"sortOrder > %d AND status == 0", [[anItem sortOrder] intValue]];
	[request setPredicate:condition];
	[request setFetchLimit:1];
	NSSortDescriptor *sortOrder = [[NSSortDescriptor alloc]
								   initWithKey: @"sortOrder" ascending:YES] ;
	NSArray *sortDescriptors = [NSArray arrayWithObjects: sortOrder, nil];
	[request setSortDescriptors: sortDescriptors];
	[sortOrder release];
	NSError *anyError;
	NSArray *fetchedObjects = [moc executeFetchRequest: request
												 error: &anyError] ;
	[request release];
	NSLog(@"Looking up item matching: %@", condition);
	
	if ([fetchedObjects count] == 1) {
		QueueItem *nextItem = [fetchedObjects objectAtIndex:0];
		NSNumber *nextSortOrder = [nextItem sortOrder];
		NSLog(@"Found item with next sort order %@", nextSortOrder);
		[nextItem setSortOrder: [anItem sortOrder]];
		[anItem setSortOrder: nextSortOrder];
		[self saveAction:nil];
		return TRUE;
	}
	
	return FALSE;
}

#pragma mark ===== UI Methods ======

- (IBAction) showPreferencesWindow: (id) sender{
	[prefController showWindow];
}

- (IBAction) showQueueWindow: (id) sender{
    NSWindow *window = [prefController window];
    if (![window isVisible])
        [window center];
	
    [window makeKeyAndOrderFront: nil];
}

#pragma mark ===== FolderActions ======

- (BOOL) areFolderActionsEnabledOn: (NSString *)path{
	SystemEventsApplication *sysEventsApp = [SBApplication
											 applicationWithBundleIdentifier:@"com.apple.systemevents"];
	NSString *faPath = [[NSString stringWithFormat:@"file://localhost%@", path] stringByAddingPercentEscapesUsingEncoding:
						NSASCIIStringEncoding];
	BOOL enabled = FALSE;
	NSLog(@"Checking path %@", faPath);
	SBElementArray *folderActions = [sysEventsApp folderActions];
	if ([folderActions count] > 0) {
		for(SystemEventsFolderAction *fa in folderActions){
			NSString *pathString = [[fa path] absoluteString];
			NSLog(@"Folder action name %@", [fa name]);
			NSLog(@"Folder action path %@", [fa path]);
			NSLog(@"Folder action path string %@", pathString);
			NSLog(@"Folder action volume %@", [fa volume]);
			if ([faPath isEqual:pathString]) {
				if ([fa enabled]){
					SBElementArray *scripts = [fa scripts];
					if ([scripts count] > 0) {
						for(SystemEventsScript *script in scripts){
							NSLog(@"Script named %@", [script name]);
							if ([[script name] isEqual:FolderActionScriptName]) {
								NSLog(@"Found folder action");
								enabled = TRUE;
							}
						}
					}
				}
			}
		}
	}
	
	return enabled;
}

- (void)disableFolderActionOn: (NSString *)path{
	SystemEventsApplication *sysEventsApp = [SBApplication
											 applicationWithBundleIdentifier:@"com.apple.systemevents"];
	NSString *faPath = [[NSString stringWithFormat:@"file://localhost%@", path] stringByAddingPercentEscapesUsingEncoding:
						NSASCIIStringEncoding];

	NSLog(@"Checking path %@", faPath);
	SBElementArray *folderActions = [sysEventsApp folderActions];
	if ([folderActions count] > 0) {
		for(SystemEventsFolderAction *fa in folderActions){
			NSString *pathString = [[fa path] absoluteString];
			NSLog(@"Folder action name %@", [fa name]);
			NSLog(@"Folder action path %@", pathString);
			if ([faPath isEqual:pathString]) {
				if ([fa enabled]){
					SBElementArray *scripts = [fa scripts];
					if ([scripts count] > 0) {
						for(SystemEventsScript *script in scripts){
							NSLog(@"Script named %@", [script name]);
							if ([[script name] isEqual:FolderActionScriptName]) {
								NSLog(@"Found folder action");
								[[fa scripts] removeObject:script];
							}
						}
					}
				}
			}
		}
	}
}

- (void)enableFolderActionOn: (NSString *)path{
	SystemEventsApplication *sysEventsApp = [SBApplication
											 applicationWithBundleIdentifier:@"com.apple.systemevents"];
	if ([sysEventsApp folderActionsEnabled] != YES) {
		[sysEventsApp setFolderActionsEnabled:YES];
	}
	NSString *faPath = [[NSString stringWithFormat:@"file://localhost%@", path] stringByAddingPercentEscapesUsingEncoding:
						NSASCIIStringEncoding];
	SystemEventsFolderAction *folderAction = nil;
	
	NSLog(@"Checking path %@", faPath);
	SBElementArray *folderActions = [sysEventsApp folderActions];
	if ([folderActions count] > 0) {
		for(SystemEventsFolderAction *fa in folderActions){
			NSString *pathString = [[fa path] absoluteString];
			NSLog(@"Folder action name %@", [fa name]);
			NSLog(@"Folder action path %@", [fa path]);
			NSLog(@"Folder action path string %@", pathString);
			NSLog(@"Folder action volume %@", [fa volume]);
			if ([faPath isEqual:pathString]) {
				folderAction = fa;
				if(![fa enabled]){
					[fa setEnabled:TRUE];
				}
			}
		}
	}

	if (folderAction == nil) {
		// Add a new folder actions object
		NSDictionary *props = [NSDictionary dictionaryWithObjectsAndKeys:
							   path,            @"path",
							   nil];
		
		folderAction = [[[sysEventsApp classForScriptingClass:@"folder action"] 
												alloc] 
											   initWithProperties: props];
		[[sysEventsApp folderActions] addObject:folderAction];
		[folderAction setEnabled:TRUE];
	}
	

	SystemEventsScript *newScript = [[[sysEventsApp classForScriptingClass:@"script"] alloc] init];
	[[folderAction scripts] addObject:newScript];
	[newScript setName:FolderActionScriptName];
	[newScript setEnabled:TRUE];
}

#pragma mark scripting support

- (NSScriptObjectSpecifier *)objectSpecifier{
	NSLog(@"Object specifier was called");
	
	return nil;
}

- (NSArray *)items{
	NSLog(@"items was called");
	
	return [self queueItems];
}

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key{
	NSLog(@"asked to handle key: %@", key);
	return [key isEqual:@"queueItems"];
}
@end
