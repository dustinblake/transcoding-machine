//
//  TheTVDBProvider.m
//  TranscodingMachine
//
//  Created by Cory Powers on 1/15/10.
//  Copyright 2010 UversaInc. All rights reserved.
//

#import "TheTVDBProvider.h"

@interface TheTVDBProvider (hidden) 
- (BOOL)getMirrorUrl;
- (BOOL)getLastUpdateTime;
- (BOOL)getSeriesId;
- (BOOL)getSeriesInfo;
- (BOOL)getEpisodeInfo;
@end


@implementation TheTVDBProvider

- (BOOL)applyMetadata{
	// We only handle TV shows
	if ([[item type] intValue] != ItemTypeTV ) {
		return NO;
	}
	
	if ([self getMirrorUrl] == NO){
		return NO;
	}
	
	if ([self getLastUpdateTime] == NO){
		return NO;
	}

	if ([self getSeriesId] == NO){
		return NO;
	}
	
	if ([self getSeriesInfo] == NO){
		return NO;
	}

	if ([self getEpisodeInfo] == NO){
		return NO;
	}

	return YES;
}

- (void)dealloc{
	if(mirrorUrl){
		[mirrorUrl release];
	}
	[super dealloc];
}

@end

@implementation TheTVDBProvider (hidden)

- (BOOL)getMirrorUrl{
	NSXMLDocument *doc;
	NSArray *mirrors;
	NSString *apiKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"ttdApiKey"];
	NSString *urlString = [NSString stringWithFormat:@"http://www.thetvdb.com/api/%@/mirrors.xml", apiKey];
	NSLog(@"Downloading mirrors from %@", urlString);
	NSURL *url = [NSURL URLWithString:urlString];

	NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url 
												cachePolicy:NSURLRequestReturnCacheDataElseLoad
											timeoutInterval:30];
	
	NSData *urlData;
	NSURLResponse *response;
	NSError *error;
	urlData = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
	if(!urlData){
		NSLog(@"Error getting mirrors: %@", error);
		return NO;
	}
	
	doc = [[NSXMLDocument alloc] initWithData:urlData options:0 error:&error];
	NSLog(@"Mirror Document\n%@", doc);
	if(!doc){
		NSLog(@"Error processing xml: %@", error);
		return NO;
	}
	
	mirrors = [[doc nodesForXPath:@"Mirrors/Mirror" error:&error] retain];
	if(!mirrors){
		NSLog(@"Error extracting mirrors: %@", error);
		return NO;
	}
	
	for (NSXMLNode *node in mirrors) {
		NSArray *mpNodes = [node nodesForXPath:@"mirrorpath" error:&error];
		if(!mpNodes){
			NSLog(@"Error extracting mirrorpath: %@", error);
			return NO;
		}
		
		if([mpNodes count] > 0){
			mirrorUrl = [[[mpNodes objectAtIndex:0] stringValue] retain];
			NSLog(@"Using mirror url: %@", mirrorUrl);
			return YES;
		}
		
	}
	
	return NO;
}

- (BOOL)getLastUpdateTime{
	NSXMLDocument *doc;
	NSArray *items;
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	NSURL *url = [NSURL URLWithString:@"http://www.thetvdb.com/api/Updates.php?type=none"];
	
	NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url 
												cachePolicy:NSURLRequestReturnCacheDataElseLoad
											timeoutInterval:30];
	
	NSData *urlData;
	NSURLResponse *response;
	NSError *error;
	urlData = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
	if(!urlData){
		NSLog(@"Error getting update time: %@", error);
		return NO;
	}
	
	doc = [[NSXMLDocument alloc] initWithData:urlData options:0 error:&error];
	NSLog(@"Last Update Document\n%@", doc);
	if(!doc){
		NSLog(@"Error processing xml: %@", error);
		return NO;
	}
	
	items = [[doc nodesForXPath:@"Items" error:&error] retain];
	if(!items){
		NSLog(@"Error extracting items: %@", error);
		return NO;
	}
	
	for (NSXMLNode *node in items) {
		NSArray *timeNodes = [node nodesForXPath:@"Time" error:&error];
		if(!timeNodes){
			NSLog(@"Error extracting Time: %@", error);
			return NO;
		}
		
		if([timeNodes count] > 0){
			lastUpdateTime = [[formatter numberFromString:[[timeNodes objectAtIndex:0] stringValue]] intValue];
			NSLog(@"Using last update time: %d", lastUpdateTime);
			return YES;
		}
		
	}
	
	return NO;
}

- (BOOL)getSeriesId{
	NSXMLDocument *doc;
	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	NSArray *series;
	NSString *urlString = [NSString stringWithFormat:@"http://www.thetvdb.com/api/GetSeries.php?seriesname=%@", [[item showName] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	NSLog(@"Downloading series from %@", urlString);
	NSURL *url = [NSURL URLWithString:urlString];
	
	NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url 
												cachePolicy:NSURLRequestReturnCacheDataElseLoad
											timeoutInterval:30];
	
	NSData *urlData;
	NSURLResponse *response;
	NSError *error;
	urlData = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
	if(!urlData){
		NSLog(@"Error getting series: %@", error);
		return NO;
	}
	
	doc = [[NSXMLDocument alloc] initWithData:urlData options:0 error:&error];
	NSLog(@"Series Document\n%@", doc);
	if(!doc){
		NSLog(@"Error processing xml: %@", error);
		return NO;
	}
	
	series = [[doc nodesForXPath:@"Data/Series" error:&error] retain];
	if(!series || [series count] == 0){
		NSLog(@"Error extracting series: %@", error);
		return NO;
	}
	
	for (NSXMLNode *node in series) {
		NSArray *seriesIdNodes = [node nodesForXPath:@"seriesid" error:&error];
		if(!seriesIdNodes){
			NSLog(@"Error extracting seriesid: %@", error);
			return NO;
		}
		
		if([seriesIdNodes count] > 0){
			seriesId = [[formatter numberFromString:[[seriesIdNodes objectAtIndex:0] stringValue]] intValue];
			NSLog(@"Using series id: %d", seriesId);
			return YES;
		}
		
	}
	
	return NO;
}

- (BOOL)getSeriesInfo{
	NSXMLDocument *doc;
	NSString *apiKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"ttdApiKey"];
	NSString *urlString = [NSString stringWithFormat:@"http://www.thetvdb.com/api/%@/series/%d/en.xml", apiKey, seriesId];
	NSLog(@"Downloading series info from %@", urlString);
	NSURL *url = [NSURL URLWithString:urlString];
	
	NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url 
												cachePolicy:NSURLRequestReturnCacheDataElseLoad
											timeoutInterval:30];
	
	NSData *urlData;
	NSURLResponse *response;
	NSError *error;
	urlData = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
	if(!urlData){
		NSLog(@"Error getting series info: %@", error);
		return NO;
	}
	
	doc = [[NSXMLDocument alloc] initWithData:urlData options:0 error:&error];
	NSLog(@"Series Document\n%@", doc);
	if(!doc){
		NSLog(@"Error processing xml: %@", error);
		return NO;
	}
	
	[item setShowName: [self stringFromNode:doc usingXPath:@"Data/Series/SeriesName"]];

	[item setSummary: [self stringFromNode:doc usingXPath:@"Data/Series/Overview"]];
	
	[item setNetwork: [self stringFromNode:doc usingXPath:@"Data/Series/Network"]];
	
	return YES;
}

- (BOOL)getEpisodeInfo{
	NSXMLDocument *doc;
	NSString *apiKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"ttdApiKey"];
	NSString *urlString = [NSString stringWithFormat:@"http://www.thetvdb.com/api/%@/series/%d/default/%d/%d/en.xml", apiKey, seriesId, [[item season] intValue], [[item episode] intValue]];
	NSLog(@"Downloading episode info from %@", urlString);
	NSURL *url = [NSURL URLWithString:urlString];
	
	NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url 
												cachePolicy:NSURLRequestReturnCacheDataElseLoad
											timeoutInterval:30];
	
	NSData *urlData;
	NSURLResponse *response;
	NSError *error;
	urlData = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
	if(!urlData){
		NSLog(@"Error getting episode info: %@", error);
		return NO;
	}
	
	doc = [[NSXMLDocument alloc] initWithData:urlData options:0 error:&error];
	NSLog(@"Episode Document\n%@", doc);
	if(!doc){
		NSLog(@"Error processing xml: %@", error);
		return NO;
	}
		
	[item setLongDescription: [self stringFromNode:doc usingXPath:@"Data/Episode/Overview"]];
	
	[item setTitle: [self stringFromNode:doc usingXPath:@"Data/Episode/EpisodeName"]];
	
	[item setReleaseDate: [self stringFromNode:doc usingXPath:@"Data/Episode/FirstAired"]];

	// Download image
	NSString *imageUrl = [self stringFromNode:doc usingXPath:@"Data/Episode/filename"];
	if (imageUrl != nil && ![imageUrl isEqual:[NSString string]]) {
		NSString *imageUrlString = [NSString stringWithFormat:@"http://www.thetvdb.com/banners/%@", imageUrl];
		NSLog(@"Downloading episode image from %@", imageUrlString);
		NSURL *imageUrl = [NSURL URLWithString:imageUrlString];
		
		NSURLRequest *imageUrlRequest = [NSURLRequest requestWithURL:imageUrl 
													cachePolicy:NSURLRequestReturnCacheDataElseLoad
												timeoutInterval:30];
		NSData *imageData;
		NSURLResponse *response;
		imageData = [NSURLConnection sendSynchronousRequest:imageUrlRequest returningResponse:&response error:&error];
		if (imageData) {
			[item setCoverArt:imageData];
		}
	}
	
	
	return YES;	
}
@end
