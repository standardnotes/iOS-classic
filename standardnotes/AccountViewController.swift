//
//  AccountViewController.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/23/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import UIKit

class AccountViewController: UITableViewController {
    
    @IBOutlet weak var serverTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    @IBOutlet weak var accountActionLabel: UILabel!
   
    let ActionIndex = 3
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        reloadData()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == ActionIndex {
            if UserManager.sharedInstance.signedIn {
                signOut()
            } else {
                signIn()
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func reloadData() {
        if UserManager.sharedInstance.signedIn {
            self.accountActionLabel.text = "Sign Out"
        } else {
            self.accountActionLabel.text = "Sign In"
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
    
    func signOut() {
//        self.serverTextField.text = nil
//        self.emailTextField.text = nil
//        self.passwordTextField.text = nil
        UserManager.sharedInstance.clear()
        reloadData()
    }
    
    var email: String? {
        return UserManager.sharedInstance.email
    }
    
    var password: String? {
        return UserManager.sharedInstance.password
    }
    
    func signIn() {
        
        saveFields()
        
        if email == nil || password == nil {
            return
        }
        
        ApiController.sharedInstance.signInUser(email: email!, password: password!) { (user) in
            self.reloadData()
        }
    }
}

