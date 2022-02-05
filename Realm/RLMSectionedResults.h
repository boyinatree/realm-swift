//
//  RLMSectionedResults.h
//  
//
//  Created by Lee Maguire on 03/02/2022.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class RLMResults<RLMObjectType>;

@interface RLMSectionValues<RLMObjectType> : NSObject<NSFastEnumeration>

@end


@interface RLMSection<RLMObjectType> : NSObject<NSFastEnumeration>

@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) RLMSectionValues<RLMObjectType> *values;

@end



@interface RLMSectionedResults<RLMObjectType> : NSObject<NSFastEnumeration>

@property (nonatomic, readonly, assign) NSUInteger count;


@end

NS_ASSUME_NONNULL_END
