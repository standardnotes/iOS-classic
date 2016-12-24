//
//  ViewController+Util.swift
//  standardnotes
//
//  Created by mo on 12/23/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import UIKit

extension UIViewController {
    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "Ok", style: .default, handler: {
            (action : UIAlertAction!) -> Void in
            
        })
        alertController.addAction(defaultAction)
        self.present(alertController, animated: true, completion: nil)
    }
}
