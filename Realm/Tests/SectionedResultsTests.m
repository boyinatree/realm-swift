////////////////////////////////////////////////////////////////////////////
//
// Copyright 2022 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "RLMTestCase.h"

#import "RLMSectionedResults.h"
#import "RLMTestObjects.h"

#import <objc/runtime.h>

@interface SectionedResultsTests : RLMTestCase
@end

@implementation SectionedResultsTests

- (void)createObjects {
    RLMRealm *realm = self.realmWithTestPath;
    [realm transactionWithBlock:^{
        StringObject *strObj = [[StringObject alloc] initWithValue:@[@"foo"]];
        [AllTypesObject createInRealm:realm withValue:[AllTypesObject values:1 stringObject:strObj]];
        [AllTypesObject createInRealm:realm withValue:[AllTypesObject values:1 stringObject:strObj]];
        [AllTypesObject createInRealm:realm withValue:[AllTypesObject values:1 stringObject:strObj]];
        [AllTypesObject createInRealm:realm withValue:[AllTypesObject values:2 stringObject:strObj]];
        [AllTypesObject createInRealm:realm withValue:[AllTypesObject values:2 stringObject:strObj]];
        [AllTypesObject createInRealm:realm withValue:[AllTypesObject values:2 stringObject:strObj]];
        [AllTypesObject createInRealm:realm withValue:[AllTypesObject values:3 stringObject:strObj]];
        [AllTypesObject createInRealm:realm withValue:[AllTypesObject values:3 stringObject:strObj]];
        [AllTypesObject createInRealm:realm withValue:[AllTypesObject values:3 stringObject:strObj]];
    }];
}

- (void)createPrimitiveObject {
    RLMRealm *realm = self.realmWithTestPath;
    [realm transactionWithBlock:^{
        AllPrimitiveArrays *arrObj = [AllPrimitiveArrays new];
        [arrObj.stringObj addObject:@"foo"];
        [arrObj.stringObj addObject:@"fab"];
        [arrObj.stringObj addObject:@"bar"];
        [arrObj.stringObj addObject:@"baz"];
        [realm addObject:arrObj];
    }];

}

- (void)testCreationFromResults {
    [self createObjects];
    RLMRealm *realm = self.realmWithTestPath;

    RLMResults<AllTypesObject *> *results = [AllTypesObject allObjectsInRealm:realm];
    RLMObjectSchema *schema = [[realm schema] schemaForClassName:@"AllTypesObject"];

    NSMutableArray *supportedKeyPaths = [NSMutableArray new];

    for (RLMProperty *p in schema.properties) {
        if (!(p.type == RLMPropertyTypeData || p.type == RLMPropertyTypeObject)) {
            [supportedKeyPaths addObject:p.name];
        }
    }

    for (NSString *kp in supportedKeyPaths) {
        // keyPaths of type NSData and RLMObject are no supported.
        // keyPaths must be a property managed by the Realm.
        RLMSectionedResults<AllTypesObject *> *sr = [results sectionedResultsSortedUsingKeyPath:kp
                                                                                      ascending:YES
                                                                                comparisonBlock:^id<RLMValue>(id value) {
            return value;
        }];
        XCTAssertNotNil(sr);
        XCTAssertGreaterThan(sr.count, 0);
        XCTAssertGreaterThan(sr[0].count, 0);
    }

    RLMSectionedResults<AllTypesObject *> *sr = [results sectionedResultsSortedUsingKeyPath:@"objectCol.stringCol"
                                                                                  ascending:YES
                                                                            comparisonBlock:^id<RLMValue>(id value) {
        return value;
    }];
    XCTAssertNotNil(sr);
    XCTAssertGreaterThan(sr.count, 0);
    XCTAssertGreaterThan(sr[0].count, 0);
}

- (void)testCreationFromPrimitiveResults {
    [self createPrimitiveObject];
    RLMRealm *realm = self.realmWithTestPath;

    AllPrimitiveArrays *obj = [AllPrimitiveArrays allObjectsInRealm:realm][0];
    RLMResults *results = [obj.stringObj sortedResultsUsingKeyPath:@"self" ascending:YES];

    RLMSectionedResults *sr = [results sectionedResultsSortedUsingKeyPath:@"self"
                                                                ascending:YES
                                                          comparisonBlock:^id<RLMValue> (id value) {
        return value;
    }];

    XCTAssertNotNil(sr);
    XCTAssertGreaterThan(sr.count, 0);
    XCTAssertGreaterThan(sr[0].count, 0);
}


- (NSDictionary *)expectedValuesForType:(RLMPropertyType)type {
    switch (type) {
        case RLMPropertyTypeInt:
            return @{
                @1: @[@1, @1, @1, @3, @3, @3],
                @0: @[@2, @2, @2]
            };
        case RLMPropertyTypeBool:
            return @{
                @NO: @[@NO, @NO, @NO],
                @YES: @[@YES, @YES, @YES, @YES, @YES, @YES]
            };
        case RLMPropertyTypeFloat:
            return @{
                @(1.1f): @[@(1.1f * 1), @(1.1f * 1), @(1.1f * 1)],
                @(2.2f): @[@(1.1f * 2), @(1.1f * 2), @(1.1f * 2), @(1.1f * 3), @(1.1f * 3), @(1.1f * 3)]
            };
        case RLMPropertyTypeDouble:
            return @{
                @(1.11): @[@(1.11 * 1), @(1.11 * 1), @(1.11 * 1)],
                @(2.2): @[@(1.11 * 2), @(1.11 * 2), @(1.11 * 2), @(1.11 * 3), @(1.11 * 3), @(1.11 * 3)]
            };
        default:
            break;
    }
}

- (id<RLMValue>)sectionKeyForValue:(id<RLMValue>)value {
    switch (value.rlm_valueType) {
        case RLMPropertyTypeInt:
            return [NSNumber numberWithInt:(((NSNumber *)value).intValue % 2)];
        case RLMPropertyTypeBool:
            return value;
        case RLMPropertyTypeFloat:
            return [(NSNumber *)value isEqualToNumber:@(1.1f * 1)] ? @(1.1f) : @(2.2f);
        case RLMPropertyTypeDouble:
            return [(NSNumber *)value isEqualToNumber:@(1.11 * 1)] ? @(1.11) : @(2.2);
        default:
            break;
    }
}

- (void)testAllSupportedTypes {
    [self createObjects];
    RLMRealm *realm = self.realmWithTestPath;
    RLMResults<AllTypesObject *> *results = [AllTypesObject allObjectsInRealm:realm];

    void(^testBlock)(NSString *, RLMPropertyType) = ^(NSString *keyPath, RLMPropertyType type) {
        RLMSectionedResults<AllTypesObject *> *sr = [results sectionedResultsSortedUsingKeyPath:keyPath
                                                                                      ascending:YES
                                                                                comparisonBlock:^id<RLMValue>(id value) {
            return [self sectionKeyForValue:[value valueForKeyPath:keyPath]];
        }];

        NSDictionary *values = [self expectedValuesForType:type];
        for (RLMSection *section in sr) {
            NSArray *a = values[section.key];
            for (NSUInteger i = 0; i < section.count; i++) {
                XCTAssertEqualObjects(a[i], [section[i] valueForKeyPath:keyPath]);
            }
        }
    };

    testBlock(@"intCol", RLMPropertyTypeInt);
    testBlock(@"boolCol", RLMPropertyTypeBool);
    testBlock(@"floatCol", RLMPropertyTypeFloat);
    testBlock(@"doubleCol", RLMPropertyTypeDouble);

    /*
     @property NSString     *stringCol;
     @property NSData       *binaryCol;
     @property NSDate       *dateCol;
     @property bool          cBoolCol;
     @property int64_t       longCol;
     @property RLMDecimal128 *decimalCol;
     @property RLMObjectId  *objectIdCol;
     @property NSUUID       *uuidCol;
     @property StringObject *objectCol;
     @property MixedObject  *mixedObjectCol;
     @property (readonly) RLMLinkingObjects *linkingObjectsCol;
     @property id<RLMValue> anyCol;
     */
}


/*

 test plan:

 test bad path, e.g improper keyPath supplied

 all supported value types, optionals
 update then access
 notifications, SR and section
 section with links
 description
 add sort descriptors
 fast enumeration
 */

@end
