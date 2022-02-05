//
//  RLMSectionedResults.m
//  
//
//  Created by Lee Maguire on 03/02/2022.
//

#import "RLMSectionedResults_Private.hpp"
#import "RLMResults.h"
#import "RLMResults_Private.hpp"

@implementation RLMSectionedResults

- (instancetype)initWithResults:(realm::Results)results
                 sectionKeyPath:(NSString *)sectionKey {
    if (self = [super init]) {
        _results = std::move(results);
        _results.section_by_key_path(std::string(sectionKey.UTF8String));
    }
    return self;
}

- (NSUInteger)countByEnumeratingWithState:(nonnull NSFastEnumerationState *)state objects:(__unsafe_unretained id  _Nullable * _Nonnull)buffer count:(NSUInteger)len {
    return 1;
}

//- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
//                                  objects:(__unused __unsafe_unretained id [])buffer
//                                    count:(NSUInteger)len {
//    if (!_info) {
//        return 0;
//    }
//    if (state->state == 0) {
//        translateRLMResultsErrors([&] {
//            _results.evaluate_query_if_needed();
//        });
//    }
//    return RLMFastEnumerate(state, len, self);
//}

//NSUInteger RLMFastEnumerate(NSFastEnumerationState *state,
//                            NSUInteger len,
//                            id<RLMFastEnumerable> collection) {
//    __autoreleasing RLMFastEnumerator *enumerator;
//    if (state->state == 0) {
//        enumerator = collection.fastEnumerator;
//        state->extra[0] = (long)enumerator;
//        state->extra[1] = collection.count;
//    }
//    else {
//        enumerator = (__bridge id)(void *)state->extra[0];
//    }
//
//    return [enumerator countByEnumeratingWithState:state count:len];
//}
@end
