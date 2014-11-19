//
//  SPStorageObserverAdapter.h
//  Simperium
//
//  Created by Jorge Leandro Perez on 11/18/14.
//  Copyright (c) 2014 Simperium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPStorage.h"
#import "SPStorageObserver.h"


typedef void (^SPStorageObserverCallback)(NSSet *inserted, NSSet *updated, NSSet *deleted);

#pragma mark ====================================================================================
#pragma mark SPStorageObserverAdapter
#pragma mark ====================================================================================

// Note: This class was designed only for Unit Testing purposes. By all means, do *NOT* use this in live code.
@interface SPStorageObserverAdapter : NSObject <SPStorageObserver>
@property (nonatomic,   copy) SPStorageObserverCallback willSaveCallback;
@property (nonatomic,   copy) SPStorageObserverCallback didSaveCallback;
@end
