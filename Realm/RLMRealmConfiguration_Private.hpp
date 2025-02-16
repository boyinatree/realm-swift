////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
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

#import "RLMRealmConfiguration_Private.h"

#import <realm/object-store/shared_realm.hpp>

@interface RLMRealmConfiguration ()
- (realm::Realm::Config)config;
- (realm::Realm::Config&)configRef;
- (std::string const&)path;

@property (nonatomic) realm::SchemaMode schemaMode;
- (void)updateSchemaMode;
@end
