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
    
    func showConfirmationAlert(title: String, message: String, confirmString: String, confirmBlock: @escaping (() -> ())) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let confirmAction = UIAlertAction(title: confirmString, style: .default, handler: {
            (action : UIAlertAction!) -> Void in
            confirmBlock()
        })
        alertController.addAction(cancelAction)
        alertController.addAction(confirmAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func showDestructiveAlert(title: String, message: String, buttonString: String, block: @escaping (() -> ())) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let confirmAction = UIAlertAction(title: buttonString, style: .destructive, handler: {
            (action : UIAlertAction!) -> Void in
            block()
        })
        alertController.addAction(cancelAction)
        alertController.addAction(confirmAction)
        self.present(alertController, animated: true, completion: nil)
    }
}
