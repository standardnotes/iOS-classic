//
//  Item+CoreDataProperties.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/19/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import Foundation
import CoreData


extension Item {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Item> {
        return NSFetchRequest<Item>(entityName: "Item");
    }

    @NSManaged public var uuid: String!
    @NSManaged public var content: String?
    @NSManaged public var contentType: String!
    @NSManaged public var encItemKey: String?
    @NSManaged public var url: String?
    @NSManaged public var presentationName: String?
    @NSManaged public var dirty: Bool
    @NSManaged public var draft: Bool
}
