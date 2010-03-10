//
//  MetadataProvider.m
//  TranscodingMachine
//
//  Created by Cory Powers on 1/15/10.
//  Copyright 2010 UversaInc. All rights reserved.
//

#import "MetadataProvider.h"


@implementation MetadataProvider
- (id)init{
	return nil;
}

- (id)initWithAnItem:(QueueItem *)anItem{
    self = [super init];
    if( !self ){
        return nil;
    }
	
	item = [anItem retain];
	return self;
}

- (QueueItem *)item{
	return item;
}

- (void)setItem: (QueueItem *)anItem {
	[item release];
	item = [anItem retain];
}

- (void)dealloc{
	[item release];
	[super dealloc];
}

- (BOOL)applyMetadata{
	return NO;
}

- (NSString *)stringFromNode: (NSXMLNode *)node usingXPath: (NSString *)xpath{
	NSArray *nodes;
	NSError *error;
	nodes = [[node nodesForXPath:xpath error:&error] retain];
	if(!nodes || [nodes count] == 0){
		NSLog(@"Error extracting string from xpath %@: %@", xpath, error);
		return [NSString string];
	}
	return [[nodes objectAtIndex:0] stringValue];
	
}
@end
