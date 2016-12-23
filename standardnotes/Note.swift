//
//  Note.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/20/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import Foundation

class Note : Structure {
    
    var title: String!
    var text: String!
    
    override func mapContentToLocalProperties() {
        super.mapContentToLocalProperties()
        self.title = self.content["title"].string!
        self.text = self.content["text"].string!
        
        print("Set title: \(self.title) text: \(self.text)")
    }
    
}
