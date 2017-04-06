//
//  Item+CoreDataClass.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/19/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import Foundation
import CoreData

public class Item: NSManagedObject {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        if self.uuid == nil {
            self.uuid = UUID().uuidString
        }
        
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    func updateFromJSON(json: JSON) {
        self.uuid = json["uuid"].string!
        self.contentType = json["content_type"].string!

        if json["enc_item_key"] != JSON.null {
            self.encItemKey = json["enc_item_key"].string
        }
        
        self.createdAt = dateFromString(string: json["created_at"].string!)
        self.updatedAt = dateFromString(string: json["updated_at"].string!)

        if json["content"] != JSON.null {
            self.content = json["content"].string!
            mapContentToLocalProperties(contentObject: contentObject)
        }
    }
    
    func dateFromString(string: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        let date = dateFormatter.date(from: string)
        return date != nil ? date! : Date()
    }
    
    func stringFromDate(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        let string = dateFormatter.string(from: date)
        return string
    }
    
    func humanReadableCreateDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        let string = dateFormatter.string(from: self.createdAt)
        return string
    }
    
    var contentObject: JSON {
        return JSON(content!.data(using: .utf8, allowLossyConversion: false)!)
    }
    
    func createContentJSONFromProperties() -> JSON {
        return self.buildFullContentObject()
    }
    
    func canDelete() -> Bool {
        return true
    }
    
    // called when sharing an item and related items should be synced as well
    func markRelatedItemsAsDirty() {
        // override
    }
    
    func mapContentToLocalProperties(contentObject: JSON) {
        
    }
    
    func addItemAsRelationship(item: Item) {

    }
    
    func clearReferences() {
        
    }
    
    func buildFullContentObject() -> JSON {
        var params = [String : Any]()
        params.merge(with: structureParams())
        return JSON(params)
    }
    
    func referencesParams() -> [[String : String]] {
        fatalError("This method must be overridden")
    }
    
    func structureParams() -> [String : Any] {
        return ["references" : referencesParams()]
    }
    
    var encryptionEnabled: Bool {
        return self.encItemKey != nil
    }

}
