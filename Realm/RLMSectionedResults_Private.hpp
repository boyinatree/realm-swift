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


@interface RLMSectionedResults () {
@protected
    realm::Results _results;
}

- (instancetype)initWithResults:(realm::Results)results
                     objectInfo:(RLMClassInfo&)objectInfo
                     sectionKeyPath:(NSString *)sectionKey;

@end

@interface RLMSection () {
@protected
    std::shared_ptr<realm::Results> _results;
}

- (instancetype)initWithResults:(std::shared_ptr<realm::Results>)results
                     objectInfo:(RLMClassInfo&)objectInfo
                   sectionIndex:(NSUInteger)sectionIndex;

@end

#endif /* Header_h */
