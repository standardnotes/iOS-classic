//
//  Note+CoreDataClass.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/20/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import Foundation
import CoreData


public class Note: Item {
  
    override func mapContentToLocalProperties(contentObject: JSON) {
        super.mapContentToLocalProperties(contentObject: contentObject)
        self.title = contentObject["title"].string
        self.text = contentObject["text"].string
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.contentType = "Note"
    }

    override func structureParams() -> [String : Any] {
        return [
            "title" : safeTitle(),
            "text" : safeText()
        ].merged(with: super.structureParams())
    }
    
    override func referencesParams() -> [[String : String]] {
        var references = [[String : String]]()
        for tag in self.tags?.allObjects as! [Tag] {
            references.append(["uuid" : tag.uuid, "content_type" : tag.contentType])
        }
        return references
    }
    
    override func addItemAsRelationship(item: Item) {
        if item.contentType == "Tag" {
            self.addToTags(item as! Tag)
        }
        super.addItemAsRelationship(item: item)
    }
    
    func replaceTags(withTags tags: [Tag]) {
        for currentTag in self.tags?.allObjects as! [Tag] {
            currentTag.dirty = true
        }
        for newTag in tags {
            newTag.dirty = true
        }
        self.removeFromTags(self.tags!)
        self.addToTags(NSSet(array: tags))
    }
    
    override func markRelatedItemsAsDirty() {
        
    }
    
    override func clearReferences() {
        self.removeFromTags(self.tags!)
        super.clearReferences()
    }
    
    func safeTitle() -> String {
        return (self.title != nil) ? self.title! : ""
    }
    
    func safeText() -> String {
        return (self.text != nil) ? self.text! : ""
    }
    
}
