//
//  RLMSectionedResults.m
//  
//
//  Created by Lee Maguire on 03/02/2022.
//

#import "RLMSectionedResults_Private.hpp"
#import "RLMResults.h"
#import "RLMResults_Private.hpp"
#import "RLMCollection_Private.hpp"
#import "RLMAccessor.hpp"
#import "RLMRealm_Private.hpp"

#import <realm/object-store/sectioned_results.hpp>

#include <map>
#include <set>

namespace {
struct CollectionCallbackWrapper {
    void (^block)(id, RLMSectionedResultsChange *, NSError *);
    id collection;
    bool ignoreChangesInInitialNotification;

    void operator()(realm::SectionedResultsChangeSet const& changes, std::exception_ptr err) {
        if (err) {
            try {
                rethrow_exception(err);
            }
            catch (...) {
                NSError *error = nil;
//                RLMRealmTranslateException(&error);
                block(nil, nil, error);
                return;
            }
        }

        if (ignoreChangesInInitialNotification) {
            ignoreChangesInInitialNotification = false;
            block(collection, nil, nil);
        }

//        block(collection, [[RLMSectionedResultsChange alloc] initWithChanges:changes], nil);

    }
};
} // anonymous namespace

RLMNotificationToken *RLMAddNotificationBlock(RLMSectionedResults *collection,
                                              void (^block)(id, RLMSectionedResultsChange *, NSError *),
                                              NSArray<NSString *> *keyPaths,
                                              dispatch_queue_t queue) {
    RLMRealm *realm = collection.realm;
    auto token = [[RLMCancellationToken alloc] init];
    realm::KeyPathArray keyPathArray;

    if (!queue) {
        token->_realm = realm;
//        token->_token = collection->_sectionedResults.add_notification_callback({CollectionCallbackWrapper{block, collection, false}, collection->_sectionedResults}, std::move(keyPathArray));
        return token;
    }

    return token;
}

struct SectionedResultsComparison {
    RLMClassInfo *_info;
    RLMSectionResultsComparionBlock _comparisonBlock;

    realm::Mixed operator()(realm::Mixed first, realm::SharedRealm) {
        RLMAccessorContext context(*_info);
        return context.unbox<realm::Mixed>(_comparisonBlock(context.box(first)));
    }
};

@interface RLMSectionedResultsEnumerator() {
    // The buffer supplied by fast enumeration does not retain the objects given
    // to it, but because we create objects on-demand and don't want them
    // autoreleased (a table can have more rows than the device has memory for
    // accessor objects) we need a thing to retain them.
    id _strongBuffer[16];
    BOOL _isSection;
}
@end

@implementation RLMSectionedResultsEnumerator

- (instancetype)initWithSectionedResults:(RLMSectionedResults *)sectionedResults {
    if (self = [super init]) {
        _sectionedResults = sectionedResults;
        _isSection = NO;
        return self;
    }
    return nil;
}

- (instancetype)initWithResultsSection:(RLMSection *)resultsSection {
    if (self = [super init]) {
        _resultsSection = resultsSection;
        _isSection = YES;
        return self;
    }
    return nil;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                    count:(NSUInteger)len {
    NSUInteger batchCount = 0, count = _isSection ? [_resultsSection count] : [_sectionedResults count];
    for (NSUInteger index = state->state; index < count && batchCount < len; ++index) {
        if (_isSection) {
            id obj = [_resultsSection objectAtIndex:index];
            _strongBuffer[batchCount] = obj;
        } else {
            auto section = [_sectionedResults objectAtIndex:index];
            _strongBuffer[batchCount] = section;
        }

        batchCount++;
    }

    for (NSUInteger i = batchCount; i < len; ++i) {
        _strongBuffer[i] = nil;
    }

    if (batchCount == 0) {
        // Release our data if we're done, as we're autoreleased and so may
        // stick around for a while
        if (_sectionedResults) {
            _sectionedResults = nil;
        }
    }


    state->itemsPtr = (__unsafe_unretained id *)(void *)_strongBuffer;
    state->state += batchCount;
    state->mutationsPtr = state->extra+1;

    return batchCount;
}

@end

NSUInteger RLMFastEnumerate(NSFastEnumerationState *state,
                            NSUInteger len,
                            RLMSectionedResults *collection) {
    __autoreleasing RLMSectionedResultsEnumerator *enumerator;
    if (state->state == 0) {
        enumerator = collection.fastEnumerator;
        state->extra[0] = (long)enumerator;
        state->extra[1] = collection.count;
    }
    else {
        enumerator = (__bridge id)(void *)state->extra[0];
    }

    return [enumerator countByEnumeratingWithState:state count:len];
}

NSUInteger RLMFastEnumerate(NSFastEnumerationState *state,
                            NSUInteger len,
                            RLMSection *collection) {
    __autoreleasing RLMSectionedResultsEnumerator *enumerator;
    if (state->state == 0) {
        enumerator = collection.fastEnumerator;
        state->extra[0] = (long)enumerator;
        state->extra[1] = collection.count;
    }
    else {
        enumerator = (__bridge id)(void *)state->extra[0];
    }

    return [enumerator countByEnumeratingWithState:state count:len];
}

@interface RLMSectionedResults ()
@end

@implementation RLMSectionedResults {
    RLMRealm *_realm;
    RLMClassInfo *_info;
    RLMResults *_rlmResults;
    realm::SectionedResults _sectionedResults;
}

- (instancetype)initWithResults:(RLMResults *)results
                     objectInfo:(RLMClassInfo&)objectInfo
                comparisonBlock:(RLMSectionResultsComparionBlock)comparisonBlock
                      ascending:(BOOL)ascending
                        isSwift:(BOOL)isSwift {
    if (self = [super init]) {
        _info = &objectInfo;
        _rlmResults = results;
        _realm = results.realm;
        _sectionedResults = _rlmResults->_results.sectioned_results(SectionedResultsComparison {_info, comparisonBlock});
    }
    return self;
}

- (RLMSectionedResultsEnumerator *)fastEnumerator {
    return [[RLMSectionedResultsEnumerator alloc] initWithSectionedResults:self];
}

- (RLMRealm *)realm {
    return _realm;
}

- (NSUInteger)count {
    return translateRLMResultsErrors([&] {
        return _sectionedResults.size();
    });
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    return RLMFastEnumerate(state, len, self);
}

- (id)objectAtIndexedSubscript:(NSUInteger)index {
    return [self objectAtIndex:index];
}

- (id)objectAtIndex:(NSUInteger)index {
    return [[RLMSection alloc] initWithResultsSection:_sectionedResults[index]
                                           objectInfo:*_info];
}

// The compiler complains about the method's argument type not matching due to
// it not having the generic type attached, but it doesn't seem to be possible
// to actually include the generic type
// http://www.openradar.me/radar?id=6135653276319744
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMResults *, RLMSectionedResultsChange *, NSError *))block {
    return RLMAddNotificationBlock(self, block, nil, nil);
}
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMResults *, RLMSectionedResultsChange *, NSError *))block queue:(dispatch_queue_t)queue {
    return RLMAddNotificationBlock(self, block, nil, queue);
}

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMResults *, RLMSectionedResultsChange *, NSError *))block keyPaths:(NSArray<NSString *> *)keyPaths {
    return RLMAddNotificationBlock(self, block, keyPaths, nil);
}

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMResults *, RLMSectionedResultsChange *, NSError *))block
                                      keyPaths:(NSArray<NSString *> *)keyPaths
                                         queue:(dispatch_queue_t)queue {
    return RLMAddNotificationBlock(self, block, keyPaths, queue);
}
#pragma clang diagnostic pop

@end

@interface RLMSection ()
@end

@implementation RLMSection {
    RLMRealm *_realm;
    RLMClassInfo *_info;
    realm::ResultsSection _resultsSection;
}

- (instancetype)initWithResultsSection:(realm::ResultsSection&&)resultsSection
                            objectInfo:(RLMClassInfo&)objectInfo
{
    if (self = [super init]) {
        _info = &objectInfo;
        _resultsSection = std::move(resultsSection);
    }
    return self;
}

- (id)objectAtIndexedSubscript:(NSUInteger)index {
    return [self objectAtIndex:index];
}

- (id)objectAtIndex:(NSUInteger)index {
    RLMAccessorContext ctx(*_info);
    return translateRLMResultsErrors([&] {
        return ctx.box(_resultsSection[index]);
//        return _resultsSection.get(ctx, index);
    });
}

- (NSUInteger)count {
    return translateRLMResultsErrors([&] {
        return _resultsSection.size();
    });
}

- (id<RLMValue>)key {
    return translateRLMResultsErrors([&] {
        return RLMMixedToObjc(_resultsSection.key());
    });
}

- (RLMSectionedResultsEnumerator *)fastEnumerator {
    return [[RLMSectionedResultsEnumerator alloc] initWithResultsSection:self];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    return RLMFastEnumerate(state, len, self);
}


@end
