//
//  Tag+CoreDataClass.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/22/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import Foundation
import CoreData


public class Tag: Item {
   
    override func mapContentToLocalProperties(contentObject: JSON) {
        super.mapContentToLocalProperties(contentObject: contentObject)
        self.title = contentObject["title"].string!
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.contentType = "Tag"
    }
    
    override func structureParams() -> [String : Any] {
        return [
            "title" : safeTitle(),
        ].merged(with: super.structureParams())
    }
    
    override func referencesParams() -> [[String : String]] {
        var references = [[String : String]]()
        for note in self.notes?.allObjects as! [Note] {
            references.append(["uuid" : note.uuid, "content_type" : note.contentType])
        }
        return references
    }
    
    override func addItemAsRelationship(item: Item) {
        if item.contentType == "Note" {
            self.addToNotes(item as! Note)
        }
    }
    
    override func markRelatedItemsAsDirty() {
        for note in self.notes!.allObjects as! [Note] {
            note.dirty = true
        }
    }
    
    override func clearReferences() {
        self.removeFromNotes(self.notes!)
        super.clearReferences()
    }
    
    override func canDelete() -> Bool {
        return self.notes!.count == 0
    }
    
    func safeTitle() -> String {
        return (self.title != nil) ? self.title! : ""
    }
}
