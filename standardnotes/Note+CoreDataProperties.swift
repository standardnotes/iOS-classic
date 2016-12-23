//
//  Note+CoreDataProperties.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/20/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import Foundation
import CoreData


extension Note {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Note> {
        return NSFetchRequest<Note>(entityName: "Note");
    }

    @NSManaged public var title: String?
    @NSManaged public var text: String?
    
    @NSManaged public var tags: NSSet?

}

// MARK: Generated accessors for tags
extension Note {
    
    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)
    
    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)
    
    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)
    
    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
    
}
