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
        print("Creating Crypto instance.")
        return Crypto()
    }()
    
    func defaultPasswordGenerationParams() -> [String : Any] {
        return [
              "pw_func" : "pbkdf2",
              "pw_alg": "sha512",
              "pw_key_size": 512,
              "pw_cost": 60000
        ]
    }
    
    func pbkdf2(hash :CCPBKDFAlgorithm, password: String, salt: String, keyByteCount: Int, rounds: Int) -> String? {
        print("Running pbkdf2 with \(password), \(salt), \(keyByteCount), \(rounds)")
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
    
    
    func decrypt(message base64String: String, hexKey: String) -> String {
        let base64Data = Data(base64Encoded: base64String)
        let resultData = AES128CBC("decrypt", base64Data, hexKey.toHexadecimalData())
        let resultString = String(data: resultData!, encoding: .utf8)
        return resultString!
    }
    
    func encrypt(message plainTextMessage: String, key hexKey: String) -> String {
        let resultData = AES128CBC("encrypt", plainTextMessage.data(using: .utf8), hexKey.toHexadecimalData())
        let base64String = resultData!.base64EncodedString()
        return base64String
    }
    
    func encryptionParams(forItem item: Item) -> [String : String] {
        var params = [String : String]()
        let message = item.createContentJSONFromProperties().rawString()!
        if item.encItemKey == nil {
            setKey(forItem: item)
        }
        let keys = itemKeys(fromEncryptedKey: item.encItemKey!)
        params["content"] = encrypt(message: message, key: keys["ek"]!)
        params["enc_item_key"] = item.encItemKey!
        params["auth_hash"] = authHashString(encryptedContent: params["content"]!, authKey: keys["ak"]!)
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
    
    func setKey(forItem item: Item) {
        // key required to be 512 bits
        let hex = generateRandomHexKey(size: 512)
        print("Generated random key for item: \(hex)")
        // encrypt key with master key
        item.encItemKey = encrypt(message: hex, key: UserManager.sharedInstance.mk)
    }
    
    func itemKeys(fromEncryptedKey key: String) -> [String : String] {
        let item_key = decrypt(message: key, hexKey: UserManager.sharedInstance.mk)
        let ek = item_key.firstHalf()
        let ak = item_key.secondHalf()
        return ["ek" : ek, "ak" : ak]
    }
    
    func decryptItems(items: inout [JSON]){
        for index in 0..<items.count {
            var item = items[index]
            if let enc_key = item["enc_item_key"].string {
                let keys = itemKeys(fromEncryptedKey: enc_key)
                let ek = keys["ek"]!
                let ak = keys["ak"]!
                
                let content = item["content"].string!
                let contentData = content.data(using: .utf8)!
                let akHexData = ak.toHexadecimalData()!
//                print("Taking hmac of \(String(data: contentData, encoding: .utf8)!) using key \(akHexData.hexEncodedString())")

                let computedData = HMAC256(contentData, akHexData)
                let authHash = computedData!.hexEncodedString()
//                print("Computed auth hash: \(authHash). Should be \(expectedHash)")
                if(authHash != item["auth_hash"].string!) {
                    print("Auth hash does not match, continuing")
                    continue
                }
                
                let decryptedContent = decrypt(message: item["content"].string!, hexKey: ek)
                items[index]["content"] = JSON(decryptedContent)
                
//                print("Decrypted content \(decryptedContent) JSON body: \(item["content"].string)")
            }
        }
        
//        print("Before returning: \(items)")
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


extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
