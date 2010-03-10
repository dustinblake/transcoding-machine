//
//  MetadataProvider.h
//  TranscodingMachine
//
//  Created by Cory Powers on 1/15/10.
//  Copyright 2010 UversaInc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "QueueItem.h"

@interface MetadataProvider : NSObject {
	QueueItem *item;
}
- (id)initWithAnItem: (QueueItem *)anItem;
- (BOOL)applyMetadata;
- (NSString *)stringFromNode: (NSXMLNode *)node usingXPath: (NSString *)xpath;

@end
