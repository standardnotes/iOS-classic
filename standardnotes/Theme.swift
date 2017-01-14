//
//  Theme.swift
//  standardnotes
//
//  Created by Mo Bitar on 1/14/17.
//  Copyright © 2017 Standard Notes. All rights reserved.
//

import UIKit

class Theme {
    
    static func Initialize() {
        let red = UIColor(red: 250.0/255.0, green: 20.0/255.0, blue: 27.0/255.0, alpha: 1.0)
        UINavigationBar.appearance().tintColor = red
        UITabBar.appearance().tintColor = red
        UIButton.appearance().tintColor = red
    
        UITextField.appearance().tintColor = red
        UITextView.appearance().tintColor = red
    }
    
}
