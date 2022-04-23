////
////  File.swift
////  
////
////  Created by Lee Maguire on 18/02/2022.
////
//
//import Foundation
//import Realm
//
//public struct SectionedResults<Element: Object, Key>: Sequence, IteratorProtocol {
//
//    let collection: RLMSectionedResults<Element>
//    let keyPath: KeyPath<Element, Key>
//
//    internal init(rlmSectionedResults: RLMSectionedResults<Element>, keyPath: KeyPath<Element, Key>) {
//        self.collection = rlmSectionedResults
//        self.keyPath = keyPath
//    }
//
//    public subscript(_ index: Int) -> Section<Element, Key> {
//        return Section<Element, Key>(rlmSection: collection[UInt(index)] as! RLMSection<Element>, keyPath: keyPath)
//    }
//
//    public subscript(indexPath indexPath: IndexPath) -> Element {
//        return self[indexPath.section][indexPath.item]
//    }
//
//    public var count: Int { Int(collection.count) }
//
//    public func observe(on queue: DispatchQueue? = nil,
//                        _ block: @escaping (RealmSectionedResultsChange<Self>) -> Void) -> NotificationToken {
//        fatalError()
//    }
//
//    public func next() -> Section<Element, Key>? {
//        nil
//    }
//}
//
//public struct Section<Element: Object, Key> {
//
//    let collection: RLMSection<Element>
//
//    let keyPath: KeyPath<Element, Key>
//
//    public var key: Key {
//        return self[0][keyPath: keyPath]
//    }
//
//    internal init(rlmSection: RLMSection<Element>, keyPath: KeyPath<Element, Key>) {
//        self.collection = rlmSection
//        self.keyPath = keyPath
//    }
//
//    public subscript(_ index: Int) -> Element {
//        return collection[UInt(index)]
//    }
//
//    public var count: Int { Int(collection.count) }
//}
//
//@frozen public enum RealmSectionedResultsChange<CollectionType> {
//   /**
//    `.initial` indicates that the initial run of the query has completed (if
//    applicable), and the collection can now be used without performing any
//    blocking work.
//    */
//   case initial(CollectionType)
//
//   /**
//    `.update` indicates that a write transaction has been committed which
//    either changed which objects are in the collection, and/or modified one
//    or more of the objects in the collection.
//
//    All three of the change arrays are always sorted in ascending order.
//
//    - parameter deletions:     The indices in the previous version of the collection which were removed from this one.
//    - parameter insertions:    The indices in the new collection which were added in this version.
//    - parameter modifications: The indices of the objects which were modified in the previous version of this collection.
//    */
//   case update(CollectionType, deletions: [Int], insertions: [Int], modifications: [Int])
//
//   /**
//    If an error occurs, notification blocks are called one time with a `.error`
//    result and an `NSError` containing details about the error. This can only
//    currently happen if opening the Realm on a background thread to calcuate
//    the change set fails. The callback will never be called again after it is
//    invoked with a .error value.
//    */
//   case error(Error)
//}
