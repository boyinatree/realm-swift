//
//  Header.h
//  
//
//  Created by Lee Maguire on 04/02/2022.
//

#import "RLMSectionedResults.h"
#import "RLMClassInfo.hpp"

#import <realm/object-store/results.hpp>

#ifndef Header_h
#define Header_h

typedef BOOL(^RLMSectionResultsComparionBlock)(id, id);

@interface RLMSectionedResults () {
    @public
    realm::SectionedResults _sectionedResults;
}

- (instancetype)initWithResults:(RLMResults *)results
                     objectInfo:(RLMClassInfo&)objectInfo
                comparisonBlock:(RLMSectionResultsComparionBlock)comparisonBlock
      sortedResultsUsingKeyPath:(NSString *)sortKeyPath
                      ascending:(BOOL)ascending
                        isSwift:(BOOL)isSwift;

- (RLMRealm *)realm;

@end

@interface RLMSection ()

- (instancetype)initWithResultsSection:(realm::ResultsSection&&)resultsSection
                            objectInfo:(RLMClassInfo&)objectInfo;

@end

#endif /* Header_h */
