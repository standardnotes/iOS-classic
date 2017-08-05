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
            self.sync { error in
                
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: UserManager.LogoutNotification), object: nil, queue: OperationQueue.main) { (notification) in
            self.syncToken = nil
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
      
        Alamofire.request("\(self.server)/auth/params", method: .get, parameters: parameters)
        .validate(statusCode: 200..<300)
        .responseJSON { response in
            let json = JSON(data: response.data!)
            if response.result.error != nil {
                completion(json, response.result.error)
                return
            }
            completion(json, nil)
        }
    }
    
    var server: String {
        return UserManager.sharedInstance.server
    }
    
    func createRegistrationAuthParams(forEmail email: String) -> [String : AnyObject] {
        let pwParams = Crypto.sharedInstance.defaultPasswordGenerationParams()
        let nonce = Crypto.sharedInstance.generateRandomHexKey(size: 256)
        let salt = Crypto.sharedInstance.sha1(message: [email, nonce].joined(separator: ":"));
        return pwParams.merged(with: ["pw_salt" : salt]) as [String : AnyObject]
    }
    
    func splitKeysFromKey(key: String) -> [String] {
        let resultLength = key.characters.count
        let splitLength = resultLength/3
        let pw = key.substring(with: Range.init(uncheckedBounds: (lower: 0, upper: splitLength)))
        let mk = key.substring(with: Range.init(uncheckedBounds: (lower: splitLength, upper: splitLength * 2)))
        let ak = key.substring(with: Range.init(uncheckedBounds: (lower: splitLength * 2, upper: splitLength * 3)))
        return [pw, mk, ak]
    }
    
    func register(email: String, password: String, completion: @escaping (String?) -> ()) {
        
        var authParams = createRegistrationAuthParams(forEmail: email)
        let salt = authParams["pw_salt"] as! String
        let cost = authParams["pw_cost"] as! Int
        
        let result = Crypto.sharedInstance.pbkdf2(password: password, salt: salt, rounds: cost)!
        
        let splitKeys = splitKeysFromKey(key: result)
        let pw = splitKeys[0], mk = splitKeys[1], ak = splitKeys[2]
        
        UserManager.sharedInstance.mk = mk
        UserManager.sharedInstance.ak = ak
        UserManager.sharedInstance.save()
        
        let parameters: Parameters = ["email": email, "password" : pw].merged(with: authParams)
        
        Alamofire.request("\(self.server)/auth", method: .post, parameters: parameters)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                let json = JSON(data: response.data!)
                if response.result.error != nil {
                    let error = json["error"].dictionary
                    completion(error?["message"]?.string)
                    return
                }
                UserManager.sharedInstance.jwt = json["token"].string!
                UserManager.sharedInstance.authParams = authParams
                UserManager.sharedInstance.save()
                completion(nil)
        }
    }
    
    func costMinimumForVersion(version: String) -> Int {
        return 3000
    }
	
    func signInUser(email: String, password: String, completion: @escaping (String?, Bool) -> ()) {
        getAuthParams(email: email) { (json, error) in
            
            if error != nil {
                let error = json?["error"].dictionary
                completion(error?["message"]?.string, false)
                return
            }
            
            let authParams = json
            
            let salt = authParams!["pw_salt"].string!
            let cost = authParams!["pw_cost"].int!
            let version = authParams!["version"].string!
            
            let supportedVersions = ["001", "002"]
            if !supportedVersions.contains(version) {
                UIAlertController.showAlertOnRootController(title: "Unsupported Account", message: "The protocol version associated with your account is outdated and no longer supported by this application. Please visit standardnotes.org/help/security-update for more information.")
                return
            }
			
            let minimum = self.costMinimumForVersion(version: version)
			if cost < minimum {
				UIAlertController.showAlertOnRootController(title: "Insecure Parameters", message: "Unable to login due to insecure password parameters. Please visit standardnotes.org/help/password-upgrade for more information.")
				return
			}

            let result = Crypto.sharedInstance.pbkdf2(password: password, salt: salt, rounds: cost)!
            
            let splitKeys = self.splitKeysFromKey(key: result)
            let pw = splitKeys[0], mk = splitKeys[1], ak = splitKeys[2]
            
            UserManager.sharedInstance.mk = mk
			UserManager.sharedInstance.ak = ak
            UserManager.sharedInstance.save()
			
            let parameters: Parameters = ["email": email, "password" : pw]
            
            Alamofire.request("\(self.server)/auth/sign_in", method: .post, parameters: parameters)
                .validate(statusCode: 200..<300)
                .responseJSON { response in
                    let json = JSON(data: response.data!)
                    if response.result.error != nil {
                        let responseString = String(data: response.data!, encoding: .utf8)
                        print("Sign in error: \(responseString!)")
                        
                        let error = json["error"].dictionary
                        completion(error?["message"]?.string, false)
                        return
                    }
                    
                    UserManager.sharedInstance.jwt = json["token"].string!
                    UserManager.sharedInstance.authParams = authParams?.object as! [String : Any]?
                    UserManager.sharedInstance.save()
                    completion(nil, true)
            }
        }
			
    }
    
    func headers() -> HTTPHeaders {
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(UserManager.sharedInstance.jwt!)"
        ]
        return headers
    }
    
    var _syncToken: String?
    var syncToken: String? {
        get {
            if _syncToken == nil {
                _syncToken = UserDefaults.standard.object(forKey: "syncToken") as! String?
            }
            return _syncToken
        }
        
        set {
            _syncToken = newValue
            UserDefaults.standard.set(newValue, forKey: "syncToken")
        }
    }
    
    func sync(completion: @escaping (Error?) -> ()) {
        if UserManager.sharedInstance.signedIn == false {
            ItemManager.sharedInstance.saveContext()
            completion(nil)
            return
        }
        
        let dirty = ItemManager.sharedInstance.fetchDirty()
        
        let itemParams = dirty.map { (item) -> [String : Any] in
            return self.createParamsFromItem(item: item)
        }
        
        var params = ["items" : itemParams] as [String : Any]
        if(syncToken != nil) {
            params["sync_token"] = syncToken!
        }
        
        Alamofire.request("\(self.server)/items/sync", method: .post, parameters: params, encoding: JSONEncoding.default, headers: headers())
        .validate(statusCode: 200..<300)
        .responseJSON { response in
            if let error = response.result.error {
                print("Error saving items: \(error)")
                ItemManager.sharedInstance.saveContext()
                completion(error)
            } else {
                ItemManager.sharedInstance.clearDirty(items: dirty)
                let json = JSON(data: response.data!)
                
                print("Retrieved items: \(json["retrieved_items"].array!.count) Saved items: \(json["saved_items"].array!.count)")
                
                // merge retreived items completely
                let _ = self.handleItemsResponse(responseItems: json["retrieved_items"].array!, omitFields: nil)
                // merge only metadata for saved items
                let _ = self.handleItemsResponse(responseItems: json["saved_items"].array!, omitFields: ["content", "enc_item_key", "auth_hash"])
                // handle unsaved items
                if let unsaved = json["unsaved"].array, unsaved.count > 0 {
                    self.handleUnsavedItems(responseMapping: unsaved)
                }
                completion(nil)
                
                self.syncToken = json["sync_token"].string!
            }
        }
    }
    
    func handleItemsResponse(responseItems: [JSON], omitFields: [String]?) -> [Item] {
        var _responseItems = responseItems
        Crypto.sharedInstance.decryptItems(items: &_responseItems)
        let items = ItemManager.sharedInstance.mapResponseItemsToLocalItems(responseItems: _responseItems, omitFields: omitFields)
        return items
    }
    
    func handleUnsavedItems(responseMapping: [JSON]) {
        var performSync = false
        
        for mapping in responseMapping {
            let itemDic = mapping["item"];
            if itemDic["deleted"].boolValue {
                continue
            }
            let error = mapping["error"]
            if error["tag"] == "sync_conflict" {
                var items = [itemDic]
                Crypto.sharedInstance.decryptItems(items: &items)
                var conflicted = items[0]
                if let original = ItemManager.sharedInstance.findItem(uuid: conflicted["uuid"].string!, contentType: conflicted["content_type"].string!) {
                    // if item in question differs from the original, create a new item, otherwise discard changes
                    let content = JSON(conflicted["content"].string!.data(using: .utf8, allowLossyConversion: false)!)
                
                    if original.createContentJSONFromProperties() != content {
                        conflicted["uuid"] = JSON(UUID().uuidString)
                        let dup = ItemManager.sharedInstance.createItem(json: conflicted)
                        dup.dirty = true
                        performSync = true
                    }
                }
            }
        }
        
        if performSync {
            ItemManager.sharedInstance.saveContext()
            SyncController.sharedInstance.performSync()
        }
    }
    
    func createParamsFromItem(item: Item) -> [String : Any] {
        return createParamsFromItem(item: item, encrypted: true)
    }
    
    func exportParamsForItem(item: Item, encrypted: Bool) -> [String : Any] {
        var params = createParamsFromItem(item: item, encrypted: encrypted)
        params["created_at"] = item.stringFromDate(date: item.createdAt)
        params["updated_at"] = item.stringFromDate(date: item.updatedAt)
        if !encrypted {
            params["content"] = item.createContentJSONFromProperties().object
        }
        return params
    }
    
    func createParamsFromItem(item: Item, encrypted: Bool) -> [String : Any] {
        var params = [String : Any]()
        params["content_type"] = item.contentType
        params["uuid"] = item.uuid
        params["deleted"] = item.modelDeleted
        
		let version = UserManager.sharedInstance.protocolVersion()
        
        if(encrypted) {
            // send encrypted
            let encryptedParams = Crypto.sharedInstance.encryptionParams(forItem: item, version: version)
            if(encryptedParams != nil) {
                params.merge(with: encryptedParams!)
            }
        } else {
            // send decrypted
            params["enc_item_key"] = NSNull()
            params["auth_hash"] = NSNull()
            params["content"] = "000" + Crypto.sharedInstance.base64(message: item.createContentJSONFromProperties().rawString()!)
        }
        
        return params
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
    func sync() {
        ApiController.sharedInstance.sync { error in
            
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
