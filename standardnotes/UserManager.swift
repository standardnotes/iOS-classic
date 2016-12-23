//
//  UserManager.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/23/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import Foundation

class UserManager {
    
    static let sharedInstance : UserManager = {
        return UserManager()
    }()

    init() {
        email = UserDefaults.standard.object(forKey: "email") as! String?
        password = UserDefaults.standard.object(forKey: "password") as! String?
        server = UserDefaults.standard.object(forKey: "server") as! String?
        jwt = UserDefaults.standard.object(forKey: "jwt") as! String?
        mk = UserDefaults.standard.object(forKey: "mk") as! String?
    }
    
    var email: String!
    var password: String! {
        didSet {
            print("didSet password: \(password)")
        }
    }
    var server: String!
    var mk: String!
    var jwt: String!

    
    func save() {
        UserDefaults.standard.set(email, forKey: "email")
        UserDefaults.standard.set(password, forKey: "password")
        UserDefaults.standard.set(server, forKey: "server")
        UserDefaults.standard.set(jwt, forKey: "jwt")
        UserDefaults.standard.set(mk, forKey: "mk")
        
        persist()
    }
    
    func persist() {
        print("Saving \(email), \(password), \(server), \(jwt), \(mk)")
        UserDefaults.standard.synchronize()
    }
    
    var signedIn : Bool {
        return self.jwt != nil
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: "email")
        UserDefaults.standard.removeObject(forKey: "password")
        UserDefaults.standard.removeObject(forKey: "server")
        UserDefaults.standard.removeObject(forKey: "jwt")
        UserDefaults.standard.removeObject(forKey: "mk")
        
        self.email = nil
        self.mk = nil
        self.jwt = nil
        self.password = nil
        self.server = nil
        
        persist()
    }
}
