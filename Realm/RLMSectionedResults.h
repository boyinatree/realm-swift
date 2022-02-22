//
//  RLMSectionedResults.h
//  
//
//  Created by Lee Maguire on 03/02/2022.
//

#import <Foundation/Foundation.h>
#import "RLMCollection.h"

NS_ASSUME_NONNULL_BEGIN

@class RLMResults<RLMObjectType>;

@interface RLMSection<RLMObjectType> : NSObject<NSFastEnumeration>
/// An array containing all objects in the section.
@property (nonatomic, strong) NSArray<RLMObjectType> *values;
/// The count of objects in this section.
@property (nonatomic, readonly, assign) NSUInteger count;
/// Returns the object for a given index in the section.
- (RLMObjectType)objectAtIndexedSubscript:(NSUInteger)index;
/// Returns the object for a given index in the section.
- (RLMObjectType)objectAtIndex:(NSUInteger)index;

@end

@interface RLMSectionedResults<RLMObjectType> : NSObject<NSFastEnumeration>
/// The total amount of sections in this collection.
@property (nonatomic, readonly, assign) NSUInteger count;
/// Returns the section at a given index.
- (RLMSection *)objectAtIndexedSubscript:(NSUInteger)index;
/// Returns the section at a given index.
- (RLMObjectType)objectAtIndex:(NSUInteger)index;

- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSectionedResults *, RLMSectionedResultsChange *, NSError *))block;
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSectionedResults *, RLMSectionedResultsChange *, NSError *))block queue:(dispatch_queue_t)queue;
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSectionedResults *, RLMSectionedResultsChange *, NSError *))block keyPaths:(NSArray<NSString *> *)keyPaths;
- (RLMNotificationToken *)addNotificationBlock:(void (^)(RLMSectionedResults *, RLMSectionedResultsChange *, NSError *))block
                                      keyPaths:(NSArray<NSString *> *)keyPaths
                                         queue:(dispatch_queue_t)queue;
@end

NS_ASSUME_NONNULL_END
