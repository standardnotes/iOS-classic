//
//  AccountViewController.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/23/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import UIKit

class AccountViewController: UITableViewController {
    
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var registerButton: UIButton!
    @IBOutlet weak var serverTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signOutButton: UIButton!
    
    var accountStatusChanged: ((Bool) -> ())!
   
    let ActionIndex = 3
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {


        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func reloadData() {
        
        if UserManager.sharedInstance.signedIn {
            self.signInButton.isEnabled = false
            self.registerButton.isEnabled = false
            self.signOutButton.isEnabled = true
        } else {
            self.signInButton.isEnabled = true
            self.registerButton.isEnabled = true
            self.signOutButton.isEnabled = false
        }

        
        self.serverTextField.isEnabled = !UserManager.sharedInstance.signedIn
        self.emailTextField.isEnabled = !UserManager.sharedInstance.signedIn
        self.passwordTextField.isEnabled = !UserManager.sharedInstance.signedIn
        
        self.serverTextField.text = UserManager.sharedInstance.server
        self.emailTextField.text = UserManager.sharedInstance.email
        self.passwordTextField.text = UserManager.sharedInstance.password
    }
    
    func saveFields() {
        UserManager.sharedInstance.server = self.serverTextField.text!
        UserManager.sharedInstance.email = self.emailTextField.text!
        UserManager.sharedInstance.password = self.passwordTextField.text!
        UserManager.sharedInstance.save()
    }
    
    @IBAction func signOutPressed(_ sender: Any) {
        signOut()
    }
    
    func signOut() {
        
        func performSignout() {
            UserManager.sharedInstance.clear()
            ItemManager.sharedInstance.signOut()
            reloadData()
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: UserManager.LogoutNotification), object: nil)
        }
        
        let dirtyItems = ItemManager.sharedInstance.fetchDirty()
        if dirtyItems.count > 0 {
            self.showConfirmationAlert(title: "Unsaved Changes", message: "You have unsaved changes. Are you sure you want to log out and remove all data from this device?", confirmString: "Log Out", confirmBlock: {
                performSignout()
            })
        } else {
            performSignout()
        }
    }
    

    
    var email: String? {
        return UserManager.sharedInstance.email
    }
    
    var password: String? {
        return UserManager.sharedInstance.password
    }
    
    @IBAction func signInPressed(_ sender: Any) {
        saveFields()
        
        if email == nil || password == nil {
            return
        }
        
        signIn()
    }

    @IBAction func registerPressed(_ sender: Any) {
        saveFields()
        
        if email == nil || password == nil {
            return
        }
        
        register()
    }
    
    func register() {
        ApiController.sharedInstance.register(email: email!, password: password!) { (error) in
            if error != nil {
                self.showAlert(title: "Oops", message: error!.localizedDescription)
                return
            }
            self.accountStatusChanged(true)
            self.reloadData()
        }
    }
    
    
    func signIn() {
        
        ApiController.sharedInstance.signInUser(email: email!, password: password!) { (error) in
            if error != nil {
                self.showAlert(title: "Oops", message: error!.localizedDescription)
                return
            }
            self.accountStatusChanged(true)
            self.reloadData()
        }
    }
}

