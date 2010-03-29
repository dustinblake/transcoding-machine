//
//  MetadataProvider.h
//  TranscodingMachine
//
//  Created by Cory Powers on 1/15/10.
//  Copyright 2010 UversaInc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "QueueItem.h"
#import "MediaItem.h"

@interface MetadataProvider : NSObject {
	MediaItem *item;
}
- (id)initWithAnItem: (MediaItem *)anItem;
- (BOOL)applyMetadata;
- (NSString *)stringFromNode: (NSXMLNode *)node usingXPath: (NSString *)xpath;

@end
