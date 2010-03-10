//
//  TheTVDBProvider.h
//  TranscodingMachine
//
//  Created by Cory Powers on 1/15/10.
//  Copyright 2010 UversaInc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MetadataProvider.h"

@interface TheTVDBProvider : MetadataProvider {
	NSString *mirrorUrl;
	int lastUpdateTime;
	int seriesId;	
}

@end
