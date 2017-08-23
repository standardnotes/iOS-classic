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
    
    func showConfirmationAlert(style: UIAlertControllerStyle, sourceView: UIView?, title: String, message: String, confirmString: String, confirmBlock: @escaping (() -> ())) {
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: style)
        if style == .actionSheet {
            alertController.popoverPresentationController?.sourceView = sourceView
        }
        
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
    
    
    func topMostViewController() -> UIViewController {
        // Handling Modal views
        if let presentedViewController = self.presentedViewController {
            return presentedViewController.topMostViewController()
        }
            // Handling UIViewController's added as subviews to some other views.
        else {
            for view in self.view.subviews
            {
                // Key property which most of us are unaware of / rarely use.
                if let subViewController = view.next {
                    if subViewController is UIViewController {
                        let viewController = subViewController as! UIViewController
                        return viewController.topMostViewController()
                    }
                }
            }
            return self
        }
    }


}

extension UIAlertController {
	
	class func showConfirmationAlertOnRootController(title: String, message: String, confirmString: String, confirmBlock: @escaping (() -> ())) {
		
		AppDelegate.sharedInstance.window?.rootViewController?.showConfirmationAlert(style: .alert, sourceView: nil, title: title, message: message, confirmString: confirmString, confirmBlock: confirmBlock)
		
	}
	
	class func showAlertOnRootController(title: String, message: String) {
		AppDelegate.sharedInstance.window?.rootViewController?.showAlert(title: title, message: message)
	}
	
}
