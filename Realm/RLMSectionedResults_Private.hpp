//
//  Header.h
//  
//
//  Created by Lee Maguire on 04/02/2022.
//

#import "RLMSectionedResults.h"
#import "RLMClassInfo.hpp"

#ifndef Header_h
#define Header_h

@protocol RLMValue;

namespace realm {
class SectionedResults;
class ResultsSection;
};

typedef id<RLMValue>(^RLMSectionResultsComparionBlock)(id);

@interface RLMSectionedResultsEnumerator : NSObject

@property (nonatomic, readonly) RLMSectionedResults *sectionedResults;
@property (nonatomic, readonly) RLMSection *resultsSection;

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                    count:(NSUInteger)len;

- (instancetype)initWithSectionedResults:(RLMSectionedResults *)sectionedResults;
- (instancetype)initWithResultsSection:(RLMSection *)resultsSection;

@end

@interface RLMSectionedResults ()

- (instancetype)initWithResults:(RLMResults *)results
                     objectInfo:(RLMClassInfo&)objectInfo
                comparisonBlock:(RLMSectionResultsComparionBlock)comparisonBlock
                      ascending:(BOOL)ascending
                        isSwift:(BOOL)isSwift;

- (RLMRealm *)realm;

- (RLMSectionedResultsEnumerator *)fastEnumerator;

NSUInteger RLMFastEnumerate(NSFastEnumerationState *state,
                            NSUInteger len,
                            RLMSectionedResults *collection);

@end

@interface RLMSection ()

- (instancetype)initWithResultsSection:(realm::ResultsSection&&)resultsSection
                            objectInfo:(RLMClassInfo&)objectInfo;

- (RLMSectionedResultsEnumerator *)fastEnumerator;

NSUInteger RLMFastEnumerate(NSFastEnumerationState *state,
                            NSUInteger len,
                            RLMSection *collection);

@end

#endif /* Header_h */
