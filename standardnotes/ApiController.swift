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
import UIKit

class ApiController {

    private static var _sharedInstance: ApiController!
    
    static let DirtyChangeMadeNotification = "DirtyChangeMadeNotification"
    
    init() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: ApiController.DirtyChangeMadeNotification), object: nil, queue: OperationQueue.main) { (notification) in
            self.saveDirtyItems { error in
                
            }
        }
    }
    
    static let sharedInstance : ApiController = {
        _sharedInstance = ApiController()
        return _sharedInstance
    }()
    
    func getAuthParams(email: String, completion: @escaping (JSON?, Error?) -> ()) {
        let parameters: Parameters = [
            "email": email,
            ]
        Alamofire.request("\(self.server)/auth/params", method: .get, parameters: parameters).responseJSON { response in
            if response.result.error != nil {
                completion(nil, response.result.error)
                return
            }
             let json = JSON(data: response.data!)
            completion(json, nil)
            
        }
    }
    
    var server: String {
        return UserManager.sharedInstance.server + "/api"
    }
    
    func createRegistrationAuthParams(forEmail email: String) -> [String : AnyObject] {
        let pwParams = Crypto.sharedInstance.defaultPasswordGenerationParams()
        let nonce = Crypto.sharedInstance.generateRandomHexKey(size: 256)
        let salt = Crypto.sharedInstance.sha1(message: email + "SN" + nonce);
        return pwParams.merged(with: ["pw_salt" : salt, "pw_nonce" : nonce]) as [String : AnyObject]
    }
    
    func register(email: String, password: String, completion: @escaping (Error?) -> ()) {

        let authParams = createRegistrationAuthParams(forEmail: email)
        let result = Crypto.sharedInstance.pbkdf2(hash: CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512), password: password, salt: authParams["pw_salt"] as! String, keyByteCount: (authParams["pw_key_size"] as! Int)/8, rounds: authParams["pw_cost"] as! Int)!
        
        let pw = result.firstHalf()
        let mk = result.secondHalf()
        UserManager.sharedInstance.mk = mk
        UserManager.sharedInstance.save()
        
        let parameters: Parameters = ["email": email, "password" : pw].merged(with: authParams)
        
        Alamofire.request("\(self.server)/auth", method: .post, parameters: parameters)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
            if response.result.error != nil {
                completion(response.result.error)
                return
            }
            let json = JSON(data: response.data!)
            UserManager.sharedInstance.jwt = json["token"].string!
            UserManager.sharedInstance.save()
            if var jsonItems = json["items"].array {
                let _ = self.handleItemsResponse(responseItems: &jsonItems)
            }
            completion(nil)
        }
        
    }
    
    
    func signInUser(email: String, password: String, completion: @escaping (Error?) -> ()) {
        getAuthParams(email: email) { (authParams, error) in
            
            if error != nil {
                completion(error)
                return
            }

            let result = Crypto.sharedInstance.pbkdf2(hash: CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512), password: password, salt: authParams!["pw_salt"].string!, keyByteCount: authParams!["pw_key_size"].int!/8, rounds: authParams!["pw_cost"].int!)!
            let pw = result.firstHalf()
            let mk = result.secondHalf()
            UserManager.sharedInstance.mk = mk
            UserManager.sharedInstance.save()
            
            let parameters: Parameters = ["email": email, "password" : pw]
            
            Alamofire.request("\(self.server)/auth/sign_in.json", method: .post, parameters: parameters)
                .validate(statusCode: 200..<300)
                .responseJSON { response in
                if response.result.error != nil {
                    completion(response.result.error)
                    return
                }
                let json = JSON(data: response.data!)
                UserManager.sharedInstance.jwt = json["token"].string!
                UserManager.sharedInstance.save()
                var jsonItems = json["items"].array!
                let _ = self.handleItemsResponse(responseItems: &jsonItems)
                completion(nil)
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
    
    func saveDirtyItems(completion: @escaping (Error?) -> ()) {
        if UserManager.sharedInstance.signedIn == false {
            completion(nil)
            return
        }
        
        let dirty = ItemManager.sharedInstance.fetchDirty()
        if dirty.count == 0 {
            completion(nil)
            return
        }
        
        saveItems(items: dirty, completion: { (items, error) in
            if error == nil {
                ItemManager.sharedInstance.clearDirty(items: items!)
            }
            completion(error)
        })
    }
    
    func saveItems(items: [Item], completion: @escaping ([Item]?, Error?) -> ()) {
        let itemParams = items.map { (item) -> [String : Any] in
            return self.createParamsFromItem(item: item)
        }
        
//        print("Saving items \(itemParams)")

        Alamofire.request("\(self.server)/items", method: .post, parameters: ["items" : itemParams], encoding: JSONEncoding.default,  headers: headers()).responseJSON { response in
            if let error = response.result.error {
                print("Error saving items: \(error)")
                completion(nil, error)
            } else {
                let json = JSON(data: response.data!)
                var jsonItems = json["items"].array!
                let items = self.handleItemsResponse(responseItems: &jsonItems)
                completion(items, nil)
            }
        }
    }
    
    func createParamsFromItem(item: Item) -> [String : Any] {
        var params = [String : Any]()
        params["content_type"] = item.contentType
        params["uuid"] = item.uuid
        
        if item.presentationName != nil {
            params["presentation_name"] = item.presentationName
        } else {
            params["presentation_name"] = NSNull()
        }
        
        params["deleted"] = item.modelDeleted
        
        if(item.isPublic) {
            // send decrypted
            params["enc_item_key"] = NSNull()
            params["auth_hash"] = NSNull()
            params["content"] = "000" + Crypto.sharedInstance.base64(message: item.createContentJSONFromProperties().rawString()!)
            
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
        return items
    }
    
    
    func shareItem(item: Item, completion: @escaping (Error?) -> ()) {
        item.presentationName = "_auto_"
        item.dirty = true
        item.markRelatedItemsAsDirty()
        saveDirtyItems { (error) in
            completion(error)
        }
    }
    
    func unshareItem(item: Item, completion: @escaping (Error?) -> ()) {
        item.presentationName = nil
        item.dirty = true
        item.markRelatedItemsAsDirty()
        saveDirtyItems { (error) in
            completion(error)
        }
    }
    
    func deleteItem(item: Item, completion: @escaping ((Error?) -> ())) {
        Alamofire.request("\(self.server)/items/\(item.uuid)", method: .delete, headers: headers()).responseJSON { response in
            if let error = response.result.error {
                print("Error deleting item: \(error)")
            }
            completion(response.result.error)
        }
    }
    
}

extension UIViewController {
    func saveDirty() {
        ApiController.sharedInstance.saveDirtyItems { error in
            
        }
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

func delay(_ delay:Double, closure:@escaping ()->()) {
    let when = DispatchTime.now() + delay
    DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
}
