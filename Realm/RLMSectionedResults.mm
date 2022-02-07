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

@interface RLMSectionedResults () <RLMFastEnumerable>
@end

@implementation RLMSectionedResults {
    RLMRealm *_realm;
    RLMClassInfo *_info;
}

- (instancetype)initWithResults:(realm::Results)results
                     objectInfo:(RLMClassInfo&)objectInfo
                 sectionKeyPath:(NSString *)sectionKey {
    if (self = [super init]) {
        _info = &objectInfo;
        _results = std::move(results);
        _results.section_by_key_path(std::string(sectionKey.UTF8String));
    }
    return self;
}

- (NSUInteger)count {
    return translateRLMResultsErrors([&] { return _results.section_indicies->size(); });
}

- (RLMFastEnumerator *)fastEnumerator {
    return translateRLMResultsErrors([&] {
        return [[RLMFastEnumerator alloc] initWithResults:_results collection:self
                                                classInfo:*_info];
    });
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
    if (state->state == 0) {
        translateRLMResultsErrors([&] {
            _results.evaluate_query_if_needed();
        });
    }
    return RLMSectionedResultsFastEnumerate(state, len, self);
}

- (id)objectAtIndexedSubscript:(NSUInteger)index {
    return [self objectAtIndex:index];
}

- (id)objectAtIndex:(NSUInteger)index {
    return [[RLMSection alloc] initWithResults:std::make_shared<realm::Results>(_results)
                                    objectInfo:*_info
                                  sectionIndex:index];
}

@end

@interface RLMSection () <RLMFastEnumerable>
@end

@implementation RLMSection {
    RLMRealm *_realm;
    RLMClassInfo *_info;
    NSUInteger _sectionIndex;
}

- (instancetype)initWithResults:(std::shared_ptr<realm::Results>)results
                     objectInfo:(RLMClassInfo&)objectInfo
                   sectionIndex:(NSUInteger)sectionIndex {
    if (self = [super init]) {
        _info = &objectInfo;
        _results = results;
        _sectionIndex = sectionIndex;
    }
    return self;
}

- (id)objectAtIndexedSubscript:(NSUInteger)index {
    return [self objectAtIndex:index];
}

- (id)objectAtIndex:(NSUInteger)index {
    RLMAccessorContext ctx(*_info);
    return translateRLMResultsErrors([&] {
        auto offset = _results->section_indicies->at(_sectionIndex);
        return _results->get(ctx, index + offset);
    });
}

- (NSUInteger)count {
    return translateRLMResultsErrors([&] {
        if ((_sectionIndex + 1) < _results->section_indicies->size()) {
            return _results->section_indicies->at(_sectionIndex+1) - _results->section_indicies->at(_sectionIndex);
        } else {
            return _results->section_indicies->at(_sectionIndex) - _results->section_indicies->size();
        }
    });
}

- (RLMFastEnumerator *)fastEnumerator {
    return translateRLMResultsErrors([&] {
        return [[RLMFastEnumerator alloc] initWithResults:*_results
                                               collection:self
                                                classInfo:*_info];
    });
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

    return RLMSectionResultsFastEnumerate(state, len, self, _sectionIndex);
}

@end
