// 
//  QueueItem.m
//  QueueManager
//
//  Created by Cory Powers on 12/28/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "QueueItem.h"
#import "AppController.h"


@implementation QueueItem 

@dynamic copyright;
@dynamic coverArt;
@dynamic episode;
@dynamic genre;
@dynamic hdVideo;
@dynamic input;
@dynamic longDescription;
@dynamic network;
@dynamic output;
@dynamic releaseDate;
@dynamic season;
@dynamic showName;
@dynamic sortOrder;
@dynamic status;
@dynamic summary;
@dynamic title;
@dynamic type;

@dynamic message;

-(NSString *)shortName{
	return [[self input] lastPathComponent];
}

-(NSString *)episodeId{
	if ([self type] == [NSNumber numberWithInt:ItemTypeTV]) {
		return [NSString stringWithFormat:@"%d%.2d", [[self season] intValue], [[self episode] intValue]];
	}
	return [NSString string];
}

- (NSData *)statusImage{
	NSString* imageName;
	if([[self status] intValue] == 0){
		imageName = [[NSBundle mainBundle] pathForResource:@"EncodePending" ofType:@"png"];
	}else if ([[self status] intValue] == 1) {
		imageName = [[NSBundle mainBundle] pathForResource:@"EncodeWorking" ofType:@"png"];
	}else if ([[self status] intValue] == 255) {
		imageName = [[NSBundle mainBundle] pathForResource:@"EncodeComplete" ofType:@"png"];
	}else{
		imageName = [[NSBundle mainBundle] pathForResource:@"EncodeCanceled" ofType:@"png"];
	}
	return [NSData dataWithContentsOfFile:imageName];
}

- (NSScriptObjectSpecifier *)objectSpecifier{
	
	NSLog(@"Object specifier was called");

	AppController *appController = [NSApp delegate];
    NSArray *queueItems = [appController queueItems];
    unsigned index = [queueItems indexOfObjectIdenticalTo:self];
	
	NSScriptClassDescription *appClassDesc = (NSScriptClassDescription *)[NSScriptClassDescription classDescriptionForClass:[NSApp class]];

	NSIndexSpecifier *indexSpecifier = [[NSIndexSpecifier alloc] 
										initWithContainerClassDescription:appClassDesc 
										containerSpecifier:nil 
										key:@"queueItems" 
										index:index];
	NSLog(@"Sending specifier: %@", indexSpecifier);
	return indexSpecifier;

}
@end
