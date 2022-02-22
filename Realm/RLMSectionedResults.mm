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

        block(collection, [[RLMSectionedResultsChange alloc] initWithChanges:changes], nil);

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
        token->_token = collection->_sectionedResults.add_notification_callback({CollectionCallbackWrapper{block, collection, false}, collection->_sectionedResults}, std::move(keyPathArray));
        return token;
    }

    return token;
}

struct SectionedResultsComparison {
    RLMClassInfo *_info;
    RLMSectionResultsComparionBlock _comparisonBlock;
    NSString *keyPath;
    BOOL isSwift;

    bool operator()(realm::Mixed first, realm::Mixed second) {
        RLMAccessorContext context(*_info);
        if (isSwift) {
            return _comparisonBlock(context.box(first), context.box(second));
        } else {
            return _comparisonBlock([context.box(first) valueForKeyPath:keyPath], [context.box(second) valueForKeyPath:keyPath]);
        }
    }
};

@interface RLMSectionedResults () <RLMFastEnumerable>
@end

@implementation RLMSectionedResults {
    RLMRealm *_realm;
    RLMClassInfo *_info;
    RLMResults *_results;

//    SectionedResultsComparison _comparison;
}

- (instancetype)initWithResults:(RLMResults *)results
                     objectInfo:(RLMClassInfo&)objectInfo
                comparisonBlock:(RLMSectionResultsComparionBlock)comparisonBlock
      sortedResultsUsingKeyPath:(NSString *)sortKeyPath
                      ascending:(BOOL)ascending
                        isSwift:(BOOL)isSwift {
    if (self = [super init]) {
        _info = &objectInfo;
        _results = results;
        _realm = results.realm;
//        _comparison = {_info, comparisonBlock}; // dont store in ivar
        // capture _info pointer by value
        _sectionedResults = _results->_results.sectioned_results(std::string(sortKeyPath.UTF8String),
                                              ascending,
                                              SectionedResultsComparison {_info, comparisonBlock, sortKeyPath, isSwift});
    }
    return self;
}

- (RLMRealm *)realm {
    return _realm;
}

- (NSUInteger)count {
    return translateRLMResultsErrors([&] { return _sectionedResults.size(); });
}

- (RLMFastEnumerator *)fastEnumerator {
//    return translateRLMResultsErrors([&] {
//        return [[RLMFastEnumerator alloc] initWithResults:_results collection:self
//                                                classInfo:*_info];
//    });
}

NSUInteger RLMSectionedResultsFastEnumerate(NSFastEnumerationState *state,
                                            NSUInteger len,
                                            id<RLMFastEnumerable> collection) {
    __autoreleasing RLMFastEnumerator *enumerator;
    if (state->state == 0) {
        enumerator = collection.fastEnumerator;
        state->extra[0] = (long)enumerator;
        state->extra[1] = collection.count;
    }
    else {
        enumerator = (__bridge id)(void *)state->extra[0];
    }

    return [enumerator sectionedCountByEnumeratingWithState:state count:len];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    if (!_info) {
        return 0;
    }
//    if (state->state == 0) {
//        translateRLMResultsErrors([&] {
//            _results.evaluate_query_if_needed();
//        });
//    }
    return RLMSectionedResultsFastEnumerate(state, len, self);
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

@interface RLMSection () <RLMFastEnumerable>
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
        return _resultsSection.get(ctx, index);
    });
}

- (NSUInteger)count {
    return translateRLMResultsErrors([&] {
        return _resultsSection.size();
    });
}

- (RLMFastEnumerator *)fastEnumerator {
//    return translateRLMResultsErrors([&] {
//        return [[RLMFastEnumerator alloc] initWithResults:*_results
//                                               collection:self
//                                                classInfo:*_info];
//    });
}


NSUInteger RLMSectionResultsFastEnumerate(NSFastEnumerationState *state,
                                            NSUInteger len,
                                            id<RLMFastEnumerable> collection,
                                            NSUInteger section_index) {
    __autoreleasing RLMFastEnumerator *enumerator;
    if (state->state == 0) {
        enumerator = collection.fastEnumerator;
        state->extra[0] = (long)enumerator;
        state->extra[1] = collection.count;
    }
    else {
        enumerator = (__bridge id)(void *)state->extra[0];
    }

    return [enumerator sectionCountByEnumeratingWithState:state count:len sectionIndex:section_index];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(__unused __unsafe_unretained id [])buffer
                                    count:(NSUInteger)len {
    if (!_info) {
        return 0;
    }

//    return RLMSectionResultsFastEnumerate(state, len, self, _sectionIndex);
}

@end
