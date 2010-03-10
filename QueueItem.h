//
//  QueueItem.h
//  QueueManager
//
//  Created by Cory Powers on 12/28/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>

#define ItemTypeTV 1
#define ItemTypeMovie 2

@interface QueueItem :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * copyright;
@property (nonatomic, retain) NSData * coverArt;
@property (nonatomic, retain) NSNumber * episode;
@property (nonatomic, retain) NSString * genre;
@property (nonatomic, retain) NSNumber * hdVideo;
@property (nonatomic, retain) NSString * input;
@property (nonatomic, retain) NSString * longDescription;
@property (nonatomic, retain) NSString * network;
@property (nonatomic, retain) NSString * output;
@property (nonatomic, retain) NSString * releaseDate;
@property (nonatomic, retain) NSNumber * season;
@property (nonatomic, retain) NSString * showName;
@property (nonatomic, retain) NSNumber * sortOrder;
@property (nonatomic, retain) NSNumber * status;
@property (nonatomic, retain) NSString * summary;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSNumber * type;
@property (nonatomic, retain) NSString * message;


@property (readonly) NSString *shortName;
@property (readonly) NSString *episodeId;
@property (readonly) NSData *statusImage;

- (NSScriptObjectSpecifier *)objectSpecifier;
@end



