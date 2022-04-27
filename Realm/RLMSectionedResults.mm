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
#import "RLMObservation.hpp"
#import "RLMThreadSafeReference_Private.hpp"

#include <map>
#include <set>

namespace {
struct CollectionCallbackWrapper {
    void (^block)(id, RLMSectionedResultsChange *, NSError *);
    id collection;
    bool ignoreChangesInInitialNotification = true;

    void operator()(realm::SectionedResultsChangeSet const& changes, std::exception_ptr err) {
        if (err) {
            try {
                rethrow_exception(err);
            }
            catch (...) {
                NSError *error = nil;
                RLMRealmTranslateException(&error);
                block(nil, nil, error);
                return;
            }
        }

        if (ignoreChangesInInitialNotification) {
            ignoreChangesInInitialNotification = false;
            block(collection, nil, nil);
        }

        block(collection, [[RLMSectionedResultsChange alloc] initWithChanges:changes], nil);

    }
};
} // anonymous namespace

realm::SectionedResults& RLMGetBackingCollection(RLMSectionedResults *self) {
    return self->_sectionedResults;
}

RLMNotificationToken *RLMAddNotificationBlock(RLMSectionedResults *collection,
                                              void (^block)(id, RLMSectionedResultsChange *, NSError *),
                                              NSArray<NSString *> *keyPaths,
                                              dispatch_queue_t queue) {
    RLMRealm *realm = collection.realm;
    if (!realm) {
        @throw RLMException(@"Linking objects notifications are only supported on managed objects.");
    }
    auto token = [[RLMCancellationToken alloc] init];

    RLMClassInfo *info = collection.objectInfo;
    realm::KeyPathArray keyPathArray = RLMKeyPathArrayFromStringArray(realm, info, keyPaths);

    if (!queue) {
        [realm verifyNotificationsAreSupported:true];
        token->_realm = realm;
        token->_token = RLMGetBackingCollection(collection).add_notification_callback(CollectionCallbackWrapper{block, collection}, std::move(keyPathArray));
        return token;
    }

    RLMThreadSafeReference *tsr = [RLMThreadSafeReference referenceWithThreadConfined:collection];
    token->_realm = realm;
    RLMRealmConfiguration *config = realm.configuration;
    dispatch_async(queue, ^{
        std::lock_guard<std::mutex> lock(token->_mutex);
        if (!token->_realm) {
            return;
        }
        NSError *error;
        RLMRealm *realm = token->_realm = [RLMRealm realmWithConfiguration:config queue:queue error:&error];
        if (!realm) {
            block(nil, nil, error);
            return;
        }
        RLMSectionedResults *collection = [realm resolveThreadSafeReference:tsr];
        token->_token = RLMGetBackingCollection(collection).add_notification_callback(CollectionCallbackWrapper{block, collection}, std::move(keyPathArray));
    });
    return token;
}

@implementation RLMSectionedResultsChange {
    realm::SectionedResultsChangeSet _indices;
}

- (instancetype)initWithChanges:(realm::SectionedResultsChangeSet)indices {
    self = [super init];
    if (self) {
        _indices = std::move(indices);
    }
    return self;
}

- (NSDictionary<NSNumber *, NSArray<NSIndexPath *> *> *)indexesFromIndexMap:(std::map<size_t, std::vector<size_t>>&)indexMap {
    NSMutableDictionary<NSNumber *, NSArray<NSIndexPath *> *> *d = [NSMutableDictionary dictionaryWithCapacity:indexMap.size()];
    for (auto& kv : indexMap) {
        NSMutableArray<NSIndexPath *> *a = [NSMutableArray arrayWithCapacity:kv.second.size()];
        for(auto& idx : kv.second) {
            [a addObject:[[NSIndexPath alloc] initWithIndex:idx]];
        }
        d[@(kv.first)] = a;
    }
    return d;
}


- (NSDictionary<NSNumber *, NSArray<NSIndexPath *> *> *)insertions {
    return [self indexesFromIndexMap:_indices.insertions];
}

- (NSDictionary<NSNumber *, NSArray<NSIndexPath *> *> *)deletions {
    return [self indexesFromIndexMap:_indices.deletions];
}

- (NSDictionary<NSNumber *, NSArray<NSIndexPath *> *> *)modifications {
    return [self indexesFromIndexMap:_indices.modifications];
}

/// Returns the index paths of the deletion indices in the given section.
- (NSArray<NSIndexPath *> *)deletionsInSection:(NSUInteger)section {
    return self.deletions[@(section)];
}

/// Returns the index paths of the insertion indices in the given section.
- (NSArray<NSIndexPath *> *)insertionsInSection:(NSUInteger)section {
    return self.insertions[@(section)];
}

/// Returns the index paths of the modification indices in the given section.
- (NSArray<NSIndexPath *> *)modificationsInSection:(NSUInteger)section {
    return self.modifications[@(section)];

}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RLMSectionedResultsChange: %p> insertions: %@, deletions: %@, modifications: %@",
            (__bridge void *)self, self.insertions, self.deletions, self.modifications];
}

@end

struct SectionedResultsComparison {
    RLMClassInfo *_info;
    RLMSectionResultsComparionBlock _comparisonBlock;

    realm::Mixed operator()(realm::Mixed first, realm::SharedRealm) {
        RLMAccessorContext context(*_info);
        id value = _comparisonBlock(context.box(first));
        return context.unbox<realm::Mixed>(value);
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
}

- (instancetype)initWithResults:(RLMResults *)results
                     objectInfo:(RLMClassInfo&)objectInfo
                comparisonBlock:(RLMSectionResultsComparionBlock)comparisonBlock {
    if (self = [super init]) {
        _info = &objectInfo;
        _realm = results.realm;
        _sectionedResults = results->_results.sectioned_results(SectionedResultsComparison {_info, comparisonBlock});
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

- (RLMClassInfo *)objectInfo {
    return _info;
}

#pragma mark - Thread Confined Protocol Conformance

- (realm::ThreadSafeReference)makeThreadSafeReference {
    return _sectionedResults.thread_safe_reference();
}

- (id)objectiveCMetadata {
    return nil;
}

- (instancetype)initFromThreadSafeReference:(realm::SectionedResults&&)reference {
    if (self = [super init]) {
//        _sectionedResults = std::move(reference);
    }
    return self;
}

+ (instancetype)objectWithThreadSafeReference:(realm::ThreadSafeReference)reference
                                     metadata:(__unused id)metadata
                                        realm:(RLMRealm *)realm {
    auto results = reference.resolve<realm::Results>(realm->_realm);
//    return [[RLMSectionedResults alloc] initFromThreadSafeReference:std::move(sectionedResults)];
}

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
