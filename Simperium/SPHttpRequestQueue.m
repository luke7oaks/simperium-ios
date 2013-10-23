//
//  SPHttpRequestQueue.m
//  Simperium
//
//  Created by Jorge Leandro Perez on 10/21/13.
//  Copyright (c) 2013 Simperium. All rights reserved.
//

#import "SPHttpRequestQueue.h"
#import "SPHttpRequest+Internals.h"



#pragma mark ====================================================================================
#pragma mark Constants
#pragma mark ====================================================================================

static NSInteger const SPHttpRequestsMaxConcurrentDownloads = 10;


#pragma mark ====================================================================================
#pragma mark Private Methods
#pragma mark ====================================================================================

@interface SPHttpRequestQueue ()
@property (nonatomic, strong, readwrite) dispatch_queue_t queueLock;
@property (nonatomic, strong, readwrite) NSMutableArray *pendingRequests;
@property (nonatomic, strong, readwrite) NSMutableArray *activeRequests;

-(void)processNextRequest;
@end


#pragma mark ====================================================================================
#pragma mark SPHttpRequestQueue
#pragma mark ====================================================================================

@implementation SPHttpRequestQueue

-(id)init
{
    if((self = [super init]))
    {
        self.queueLock = dispatch_queue_create("com.simperium.SPHttpRequestQueue", NULL);
		self.enabled = true;
		self.maxConcurrentConnections = SPHttpRequestsMaxConcurrentDownloads;
        self.pendingRequests = [NSMutableArray array];
        self.activeRequests = [NSMutableArray array];
    }
    
    return self;
}

#pragma mark ====================================================================================
#pragma mark Public Methods
#pragma mark ====================================================================================

-(void)enqueueHttpRequest:(SPHttpRequest*)httpRequest
{
    dispatch_sync(self.queueLock, ^(void) {
					httpRequest.httpRequestQueue = self;
                    [self.pendingRequests addObject:httpRequest];
                  });
    
    [self processNextRequest];
}

-(void)dequeueHttpRequest:(SPHttpRequest*)httpRequest
{
	[httpRequest stop];
	
    dispatch_sync(self.queueLock, ^(void) {
                      if([self.pendingRequests containsObject:httpRequest]) {
                          [self.pendingRequests removeObject:httpRequest];
					  }
                      
                      if([self.activeRequests containsObject:httpRequest]) {
                          [self.activeRequests removeObject:httpRequest];
                      }
                  });
    
    [self processNextRequest];
}

-(void)processNextRequest
{
    if((self.pendingRequests.count == 0) || (self.activeRequests.count >= _maxConcurrentConnections) || (self.enabled == false)) {
        return;
    }
    
    dispatch_sync(self.queueLock, ^(void) {
                      SPHttpRequest* nextRequest = [self.pendingRequests objectAtIndex:0];
                      
                      [self.activeRequests addObject:nextRequest];
                      [self.pendingRequests removeObjectAtIndex:0];
                      
					  [nextRequest begin];
                  });
}

-(void)setEnabled:(BOOL)enabled
{
	_enabled = enabled;
	if(enabled) {
		[self processNextRequest];
	} else {
		// No active requests?. We're cool then.
		if(self.activeRequests.count == 0) {
			return;
		}
		
		// Re-enqueue all active requests
		[self.activeRequests makeObjectsPerformSelector:@selector(stop)];
		
		dispatch_sync(self.queueLock, ^(void) {
			[self.pendingRequests addObjectsFromArray:self.activeRequests];
			[self.activeRequests removeAllObjects];
		});
	}
}

-(void)cancelAllRequest
{
	if( (self.activeRequests.count == 0) && (self.pendingRequests.count == 0) ) {
		return;
	}
		
    [self.activeRequests makeObjectsPerformSelector:@selector(stop)];
    [self.pendingRequests makeObjectsPerformSelector:@selector(stop)];
	
    dispatch_sync(self.queueLock, ^(void) {
                      [self.activeRequests removeAllObjects];
                      [self.pendingRequests removeAllObjects];
                  });
}

-(void)cancelRequestsWithURL:(NSURL *)url
{
	NSSet *pendingCancelled = [self cancelRequestsWithURL:url fromQueue:self.activeRequests];
	NSSet *activeCancelled = [self cancelRequestsWithURL:url fromQueue:self.activeRequests];
		
    dispatch_sync(self.queueLock, ^(void) {
		[self.activeRequests removeObjectsInArray:activeCancelled.allObjects];
		[self.pendingRequests removeObjectsInArray:pendingCancelled.allObjects];
	});
}

-(BOOL)hasRequestWithTag:(NSString *)tag
{
	NSMutableSet *allRequests = [NSMutableSet set];
	[allRequests addObjectsFromArray:self.activeRequests];
	[allRequests addObjectsFromArray:self.pendingRequests];
	
	for(SPHttpRequest *request in allRequests) {
		if([request.tag isEqualToString:tag]) {
			return YES;
		}
	}
	
	return NO;
}


#pragma mark ====================================================================================
#pragma mark Private Helpers
#pragma mark ====================================================================================

-(NSSet *)cancelRequestsWithURL:(NSURL *)url fromQueue:(NSArray *)queue
{
	NSMutableSet *cancelled = [NSMutableSet set];
	
	for (SPHttpRequest *request in queue){
		if([request.url isEqual:url]) {
			[request stop];
			[cancelled addObject:request];
		}
	}
	
	return cancelled;
}

@end