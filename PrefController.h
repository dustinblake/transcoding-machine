//
//  PrefController.h
//  QueueManager
//
//  Created by Cory Powers on 12/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AppWindowController.h"

@interface PrefController : AppWindowController {
	NSString *folderActionEnabled;
	IBOutlet NSTextField *enabledLabel;
	IBOutlet NSTextField *monitoredFolderField;
	IBOutlet NSTextField *outputFolderField;
	IBOutlet NSButton *monitoringButton;
	IBOutlet NSTextField *transcoderField;
	IBOutlet NSTextField *transcoderArgsField;
	IBOutlet NSTextField *fileExtensionsField;
}

+ (void)registerUserDefaults: (NSString *)appSupportDir;
- (id)initWithController: (AppController *)controller;
- (IBAction)savePrefs:(id)sender;
- (IBAction)toggleMonitoring:(id)sender;
- (void)setMonitorFields;
- (void)showWindow;
- (IBAction)closeWindow:(id)sender;
@end
