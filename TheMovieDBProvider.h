//
//  TheMovieDBProvider.h
//  TranscodingMachine
//
//  Created by Cory Powers on 3/29/10.
//  Copyright 2010 UversaInc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MetadataProvider.h"


@interface TheMovieDBProvider : MetadataProvider {
	int tmdbId;
}

@end
