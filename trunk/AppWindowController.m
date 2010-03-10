//
//  AppWindowController.m
//  QueueManager
//
//  Created by Cory Powers on 12/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "AppWindowController.h"
#import "AppController.h"

@implementation AppWindowController
- (id)initWithController: (AppController *)controller withNibName: (NSString *)nibName {
	if (self = [super initWithWindowNibName:nibName]){
		appController = controller;
	}
	return self;
}

- (id)initWithController: (AppController *)controller {
	if (self = [super init]){
		appController = controller;
	}
	return self;
}

- (NSManagedObjectContext *)managedObjectContext{
	return [appController managedObjectContext];
}

@end
