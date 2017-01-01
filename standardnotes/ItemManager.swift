//
//  ItemManager.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/20/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import Foundation
import CoreData

class ItemManager {
    
    let context: NSManagedObjectContext!
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    private static var _sharedInstance: ItemManager!
    
    static let sharedInstance : ItemManager = {
        return _sharedInstance
    }()
    
    static func initializeSharedInstance(context: NSManagedObjectContext) {
        _sharedInstance = ItemManager(context: context)
    }
    
    func mapResponseItemsToLocalItems(responseItems: [JSON], omitFields: [String]?) -> [Item] {
        var items: [Item] = []
        for var responseItem in responseItems {
            if responseItem["deleted"].boolValue == true {
                let item = findItem(uuid: responseItem["uuid"].string!, contentType: responseItem["content_type"].string!)
                if item != nil {
                    context.delete(item!)
                }
                continue
            }
            let item = findOrCreateItem(uuid: responseItem["uuid"].string!, contentType: responseItem["content_type"].string!)
            if omitFields != nil {
                for omitField in omitFields! {
                    responseItem[omitField] = JSON.null
                }
            }
            item.updateFromJSON(json: responseItem)
            if responseItem["content"] != JSON.null {
                resolveReferences(forItem: item)
            }
            items.append(item)
        }
        self.saveContext()
        return items
    }
    
    func findOrCreateItem(uuid: String, contentType: String) -> Item {
        var item = findItem(uuid: uuid, contentType: contentType)
        if item == nil {
            print("Did not find item for \(uuid), creating.")
            item = NSEntityDescription.insertNewObject(forEntityName: contentType, into: self.context) as? Item
        }
        
        assert(item != nil)
        return item!
    }
    
    func findItem(uuid: String, contentType: String) -> Item? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: contentType)
        fetchRequest.predicate = NSPredicate(format: "uuid = %@", uuid)
        do {
            let results = try self.context.fetch(fetchRequest)
            if results.count > 0 {
                return results.first as? Item
            }
        }
        catch {
            print("Error finding item: \(error)")
        }
        
        return nil
    }
    
    func findTag(byTitle title: String) -> Tag? {
        let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
        fetchRequest.predicate = NSPredicate(format: "title = %@", title)
        do {
            let results = try self.context.fetch(fetchRequest)
            if results.count > 0 {
                return results.first! as Tag
            }
        }
        catch {
            print("Error finding item: \(error)")
        }
        
        return nil
    }
    
    func createTag(title: String) -> Tag {
        let tag = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: self.context) as! Tag
        tag.title = title
        return tag
    }
    
    func fetchDirty() -> [Item] {
        let dirty = NSFetchRequest<Item>(entityName: "Item")
        dirty.predicate = NSPredicate(format: "dirty == true AND draft == false")
        do {
            let items = try AppDelegate.sharedContext.fetch(dirty)
            return items
        }
        catch {
            fatalError("Error fetching items.")
        }
    }

    func clearDirty(items: [Item]) {
        for item in items {
            item.dirty = false
        }
        saveContext()
    }
    
    func resolveReferences(forItem item: Item) {
        item.clearReferences()
        let references = item.contentObject["references"].arrayValue
        for reference in references {
            let uuid = reference["uuid"].stringValue
            let contentType = reference["content_type"].stringValue
            let referencedItem = findItem(uuid: uuid, contentType: contentType)
            if referencedItem != nil {
                item.addItemAsRelationship(item: referencedItem!)
            } else {
                print("Unable to find referenced item.")
            }
        }
    }
    
    func saveContext () {
        if context.hasChanges {
            do {
                try context.save()
                print("Successfully saved context.")
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func setItemToBeDeleted(item: Item) {
        item.modelDeleted = true
        item.dirty = true
    }
    
    func removeItemFromCoreData(item: Item) {
        context.delete(item)
        saveContext()
    }
    
    func deleteAllItemsForEntityName(name: String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        let coordinator = AppDelegate.sharedInstance.persistentContainer.persistentStoreCoordinator
        do {
            try coordinator.execute(deleteRequest, with: context)
        } catch let error as NSError {
            print("Error deleting items: \(error)")
        }
    }
    
    func signOut() {
        deleteAllItemsForEntityName(name: "Item")
    }
    
    func exportParamsForItem(item: Item) -> [String : Any] {
        var params = [String : Any]()
        params["content_type"] = item.contentType
        params["uuid"] = item.uuid
        
        if item.presentationName != nil {
            params["presentation_name"] = item.presentationName
        }
        
        params["content"] = item.createContentJSONFromProperties().dictionaryObject
        return params
    }
    
    func JSONStringify(value: Any) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: value)
            let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            return string as! String
        } catch {
            fatalError("Unable to stringify.")
        }
    }

    func itemsExportJSONData() -> Data {
        let fetchRequest = NSFetchRequest<Item>(entityName: "Item")
        do {
            let items = try AppDelegate.sharedContext.fetch(fetchRequest)
            let params = items.map { (item) -> JSON in
                return JSON(exportParamsForItem(item: item))
            }
            let json = JSON(params)
            let data = try JSONSerialization.data(withJSONObject: json.object)
            return data
        }
        catch {
            fatalError("Error fetching items.")
        }

    }
}
