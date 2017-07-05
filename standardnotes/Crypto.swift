//
//  Crypto.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/20/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import Foundation

class Crypto {
    
    static let sharedInstance : Crypto = {
        return Crypto()
    }()
	
	let MinimumCost = 3000
    
    func defaultPasswordGenerationParams() -> [String : Any] {
        return [
            "pw_cost": 5000
        ]
    }
    
    func pbkdf2(hash :CCPBKDFAlgorithm, password: String, salt: String, keyByteCount: Int, rounds: Int) -> String? {
        let saltData = salt.data(using: .utf8)!
        let passwordData = password.data(using:String.Encoding.utf8)!
        var derivedKeyData = Data(repeating:0, count:keyByteCount)
        
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes {derivedKeyBytes in
            saltData.withUnsafeBytes { saltBytes in
                
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password, passwordData.count,
                    saltBytes, saltData.count,
                    hash,
                    UInt32(rounds),
                    derivedKeyBytes, derivedKeyData.count)
            }
        }
        if (derivationStatus != 0) {
            print("Error: \(derivationStatus)")
            return nil;
        }
         
        return derivedKeyData.hexEncodedString()
    }
    
    func sha1(message: String) -> String {
        let result = SHA1(message.data(using: .utf8))
        return result!.hexEncodedString()
    }
    
    func base64(message: String) -> String {
        return message.data(using: .utf8)!.base64EncodedString()
    }
    
    func base64decode(base64String: String) -> String? {
        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }
        return String(data: data, encoding: .utf8)!
    }
    
    func decrypt(stringToAuth: String?, message base64String: String, hexKey: String, iv hexIV: String?, authHash: String?, authKey: String?, authRequired: Bool) -> String? {
        if(authRequired && authHash == nil) {
            print("Auth hash is required.")
            return nil
        }
        
        if(authHash != nil) {
            let localAuthHash = authHashString(encryptedContent: stringToAuth!, authKey: authKey!)
            if localAuthHash != authHash {
                print("Auth hash does not match.")
                return nil
            }
        }
        
        let base64Data = Data(base64Encoded: base64String)
        let resultData = AES128CBC("decrypt", base64Data, hexKey.toHexadecimalData(), hexIV?.toHexadecimalData())
        let resultString = String(data: resultData!, encoding: .utf8)
        return resultString
    }
    
    func decryptFromComponents(components: EncryptionComponents, keys: Keys) -> String? {
        return decrypt(stringToAuth: components.stringToAuth, message: components.ciphertext, hexKey: keys.encryptionKey, iv: components.iv, authHash: components.authHash, authKey: keys.authKey, authRequired: true)
    }
    
    func encrypt(message plainTextMessage: String, key hexKey: String, iv hexIV: String?) -> String {
        let resultData = AES128CBC("encrypt", plainTextMessage.data(using: .utf8), hexKey.toHexadecimalData(), hexIV?.toHexadecimalData())
        let base64String = resultData!.base64EncodedString()
        return base64String
    }
    
    func encryptionParams(forItem item: Item, version: String) -> [String : Any]? {
        var params = [String : Any]()
        let itemKey = generateRandomHexKey(size: 512)
        if(version == "001") {
            // legacy
            item.encItemKey = encrypt(message: itemKey, key: UserManager.sharedInstance.mk, iv: nil)
        } else {
            let iv = generateRandomHexKey(size: 128)
            let cipherText = encrypt(message: itemKey, key: UserManager.sharedInstance.keys.encryptionKey, iv: iv)
            let stringToAuth = [version, item.uuid, iv, cipherText].joined(separator: ":")
            let authHash = authHashString(encryptedContent: stringToAuth, authKey: UserManager.sharedInstance.keys.authKey)
            item.encItemKey = [version, authHash, item.uuid, iv, cipherText].joined(separator: ":")
        }
        
        params["enc_item_key"] = item.encItemKey!
        
        let ek = itemKey.firstHalf()
        let ak = itemKey.secondHalf()
        let message = item.createContentJSONFromProperties().rawString()!
        if(version == "001") {
            // legacy
            params["content"] = version + encrypt(message: message, key: ek, iv: nil)
            params["auth_hash"] = authHashString(encryptedContent: params["content"] as! String, authKey: ak)
        } else {
            let iv = generateRandomHexKey(size: 128)
            let cipherText = encrypt(message: message, key: ek, iv: iv)
            let stringToAuth = [version, item.uuid, iv, cipherText].joined(separator: ":")
            let authHash = authHashString(encryptedContent: stringToAuth, authKey: ak)
            params["content"] = [version, authHash, item.uuid, iv, cipherText].joined(separator: ":")
            params["auth_hash"] = NSNull()
        }
        return params
    }
    
    func authHashString(encryptedContent base64string: String, authKey hexKey: String) -> String {
        let messageData = base64string.data(using: .utf8)
        let authKeyData = hexKey.toHexadecimalData()
        let result = HMAC256(messageData, authKeyData)
        return result!.hexEncodedString()
    }
    
    func generateRandomHexKey(size: Int) -> String {
        var data = Data(count: size/8)
        let _ = data.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, data.count, mutableBytes)
        }
        return data.hexEncodedString()
    }
    
    func generateAndSetNewEncryptionKey(forItem item: Item) {
        // key required to be 512 bits
        let hex = generateRandomHexKey(size: 512)
        // encrypt key with master key
        item.encItemKey = encrypt(message: hex, key: UserManager.sharedInstance.mk, iv: nil)
    }
    
    struct EncryptionComponents {
        var version: String
        var authHash: String
        var uuid: String?
        var iv: String?
        var ciphertext: String
        var stringToAuth: String
    }
    
    func encryptionComponents(fromString string: String) -> EncryptionComponents {
        let comps = string.components(separatedBy: ":")
        let version = comps[0], authHash = comps[1], uuid = comps[2], iv = comps[3], ciphertext = comps[4]
        let stringToAuth = [version, uuid, iv, ciphertext].joined(separator: ":")
        return EncryptionComponents.init(version: version, authHash: authHash, uuid: uuid, iv: iv, ciphertext: ciphertext, stringToAuth: stringToAuth)
    }
    
	func itemKeys(fromEncryptedKey key: String, itemUUID: String) -> Keys? {
        var decryptedKey: String?
        if(key.hasPrefix("002") == false) {
            // legacy
            decryptedKey = decrypt(stringToAuth: nil, message: key, hexKey: UserManager.sharedInstance.mk, iv: nil,
                                   authHash: nil, authKey: nil, authRequired: false)
        } else {
            let components = encryptionComponents(fromString: key)
            let keys = UserManager.sharedInstance.keys
            if(keys.authKey == nil) {
                // user needs to sign out and sign back in
                return nil
            }
			
			if(components.uuid! != itemUUID) {
				return nil
			}
			
            decryptedKey = decryptFromComponents(components: components, keys: keys)
        }

        if(decryptedKey == nil) {
            return nil
        }
        
        let ek = decryptedKey!.firstHalf()
        let ak = decryptedKey!.secondHalf()
        return Keys.init(encryptionKey: ek, authKey: ak)
    }
    
    func decryptItems(items: inout [JSON]){
        for index in 0..<items.count {
            var item = items[index]
            
            if item["deleted"].boolValue == true {
                continue
            }
            
            let encryptionVersion = item["content"].string?.substring(to: 3)
            
            if (encryptionVersion == "001" || encryptionVersion == "002"), let enc_key = item["enc_item_key"].string {
            
				let keys = itemKeys(fromEncryptedKey: enc_key, itemUUID: item["uuid"].string!)
                if(keys == nil) {
					items[index]["error_decrypting"] = true
                    print("Error decrypting item, continuing.")
                    continue
                }
                
                let content = item["content"].string!
                let contentToDecrypt = content.substring(from: 3)
                
                var encryptionComps: EncryptionComponents
                if(encryptionVersion == "001") {
                    encryptionComps = EncryptionComponents.init(version: encryptionVersion!, authHash: item["auth_hash"].string!, uuid: nil,
                                                                iv: nil, ciphertext: contentToDecrypt, stringToAuth: content)
                } else {
                    encryptionComps = encryptionComponents(fromString: content)
					if(encryptionComps.uuid! != item["uuid"].string!) {
						items[index]["error_decrypting"] = true
						print("UUID does not match, skipping decryption.")
						continue
					}
                }
				
                let decryptedContent = decryptFromComponents(components: encryptionComps, keys: keys!)
                if(decryptedContent != nil) {
                    items[index]["content"] = JSON(decryptedContent!)
				} else {
					items[index]["error_decrypting"] = true
				}
            } else {
                if let contentToDecode = item["content"].string?.substring(from: 3) {
                    if let decoded = Crypto.sharedInstance.base64decode(base64String: contentToDecode) {
                        items[index]["content"] = JSON(decoded)
                    }
                }
            }
        }
    }
}

extension String {
    
    func firstHalf() -> String {
        return self.substring(to: self.index(self.startIndex, offsetBy: self.characters.count/2))
    }
    
    func secondHalf() -> String {
        return self.substring(from: self.index(self.startIndex, offsetBy: self.characters.count/2))
    }
    
    /// Create `Data` from hexadecimal string representation
    ///
    /// This takes a hexadecimal representation and creates a `Data` object. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.
    
    func toHexadecimalData() -> Data? {
        var data = Data(capacity: characters.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, options: [], range: NSMakeRange(0, characters.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else {
            return nil
        }
        
        return data
    }
}

extension String {
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }
    
    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return substring(from: fromIndex)
    }
    
    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return substring(to: toIndex)
    }
    
    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return substring(with: startIndex..<endIndex)
    }
}


extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
