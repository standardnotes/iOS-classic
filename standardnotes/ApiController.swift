//
//  ApiController.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/19/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import Foundation
import Alamofire
import CoreData

class ApiController {

    private static var _sharedInstance: ApiController!
    
    static let DirtyChangeMadeNotification = "DirtyChangeMadeNotification"
    
    init() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: ApiController.DirtyChangeMadeNotification), object: nil, queue: OperationQueue.main) { (notification) in
            self.saveDirtyItems {
                
            }
        }
    }
    
    static let sharedInstance : ApiController = {
        _sharedInstance = ApiController()
        return _sharedInstance
    }()
    
    func getCurrentUser(completion: @escaping (User) -> ()) {
        
    }
    
    func getAuthParams(email: String, completion: @escaping (JSON) -> ()) {
        let parameters: Parameters = [
            "email": email,
            ]
        Alamofire.request("\(self.server)/auth/params", method: .get, parameters: parameters).responseJSON { response in
             let json = JSON(data: response.data!)
            completion(json)
            
        }
    }
    
    var server: String {
        return UserManager.sharedInstance.server
    }
    
    func signInUser(email: String, password: String, completion: @escaping () -> ()) {
        getAuthParams(email: email) { (authParams) in

            let result = Crypto.sharedInstance.pbkdf2(hash: CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512), password: password, salt: authParams["pw_salt"].string!, keyByteCount: authParams["pw_key_size"].int!/8, rounds: authParams["pw_cost"].int!)!
            let pw = result.firstHalf()
            let mk = result.secondHalf()
            UserManager.sharedInstance.mk = mk
            UserManager.sharedInstance.save()
            
            let parameters: Parameters = [
                "user" : [
                    "email": email,
                    "password" : pw,
                    ]
                ]
            
            Alamofire.request("\(self.server)/auth/sign_in", method: .post, parameters: parameters).responseJSON { response in
                let json = JSON(data: response.data!)
                UserManager.sharedInstance.jwt = json["token"].string!
                UserManager.sharedInstance.save()
                var jsonItems = json["items"].array!
                let _ = self.handleItemsResponse(responseItems: &jsonItems)
                completion()
            }
        }
    }
    
    func headers() -> HTTPHeaders {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(UserManager.sharedInstance.jwt!)"
        ]
        return headers
    }
    
    func refreshItems(completion: @escaping ([Item]) -> ()) {
        Alamofire.request("\(self.server)/items", headers: headers()).responseJSON { response in
            if(response.result.error != nil) {
                print("Error \(response.result.error)")
            } else {
                let json = JSON(data: response.data!)
//                print("Refresh items response: \(response)")
                var jsonItems = json["items"].array!
                let items = self.handleItemsResponse(responseItems: &jsonItems)
                completion(items)
            }
        }
    }
    
    func saveDirtyItems(completion: @escaping () -> ()) {
        let dirty = ItemManager.sharedInstance.fetchDirty()
        if dirty.count == 0 {
            completion()
            return
        }
        
        saveItems(items: dirty, completion: { (items) in
            ItemManager.sharedInstance.clearDirty(items: items)
            print("Items after setting dirty = false: \(items)")
            completion()
        })
    }
    
    func saveItems(items: [Item], completion: @escaping ([Item]) -> ()) {
        let itemParams = items.map { (item) -> [String : String] in
            return self.createParamsFromItem(item: item)
        }
        print("Saving items: \(itemParams)")
        Alamofire.request("\(self.server)/items", method: .post, parameters: ["items" : itemParams], headers: headers()).responseJSON { response in
            if let error = response.result.error {
                print("Error saving items: \(error)")
            } else {
                let json = JSON(data: response.data!)
                print("\nSave items response: \(json)")
                var jsonItems = json["items"].array!
                let items = self.handleItemsResponse(responseItems: &jsonItems)
                completion(items)
            }
        }
    }
    
    func createParamsFromItem(item: Item) -> [String : String] {
        var params = [String : String]()
        params["content_type"] = item.contentType
        params["uuid"] = item.uuid
        if(item.isPublic) {
            // send decrypted
            params["enc_item_key"] = nil
            params["content"] = item.createContentJSONFromProperties().rawString()
        } else {
            // send encrypted
            let encryptedParams = Crypto.sharedInstance.encryptionParams(forItem: item)
            params.merge(with: encryptedParams)
        }
        return params
    }
    
    func handleItemsResponse(responseItems: inout [JSON]) -> [Item] {
        Crypto.sharedInstance.decryptItems(items: &responseItems)
        let items = ItemManager.sharedInstance.mapResponseItemsToLocalItems(responseItems: responseItems)
//        print("Response Items After Mapping: \(items)")
        return items
    }
    
}

extension Dictionary {
    
    mutating func merge(with dictionary: Dictionary) {
        dictionary.forEach { updateValue($1, forKey: $0) }
    }
    
    func merged(with dictionary: Dictionary) -> Dictionary {
        var dict = self
        dict.merge(with: dictionary)
        return dict
    }
}
