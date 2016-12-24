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
    }
    
    func updateFromJSON(json: JSON) {
        self.uuid = json["uuid"].string!
        self.contentType = json["content_type"].string!
        self.encItemKey = json["enc_item_key"].string
        self.presentationName = json["presentation_name"].string
        self.content = json["content"].string!
        self.url = json["presentation_url"].string

        mapContentToLocalProperties(contentObject: contentObject)
    }
    
    var contentObject: JSON {
        return JSON(content!.data(using: .utf8, allowLossyConversion: false)!)
    }
    
    func createContentJSONFromProperties() -> JSON {
        return self.buildFullContentObject()
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
    
    var isPublic: Bool {
        return self.presentationName != nil
    }
    
    var encryptionEnabled: Bool {
        return self.encItemKey != nil
    }

}
