//
//  AccountViewController.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/23/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import UIKit
import MessageUI
import LocalAuthentication
import CoreData
import SafariServices

class AccountViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var registerButton: UIButton!
    @IBOutlet weak var serverTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signOutButton: UIButton!
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var touchIDButton: UIButton!
    @IBOutlet weak var feedbackButton: UIButton!
    @IBOutlet weak var encryptionStatusButton: UIButton!
    @IBOutlet weak var serverLabel: UILabel!
    @IBOutlet weak var advancedButton: UIButton!
    
    var password: String?
    
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
        
        let signedIn = UserManager.sharedInstance.signedIn
        
        signInButton.isEnabled = !signedIn
        registerButton.isEnabled = !signedIn
        
        signOutButton.isEnabled = signedIn
        exportButton.isEnabled = signedIn
        encryptionStatusButton.isEnabled = signedIn;
        
        if(signedIn) {
            let itemCount = getItemCount()
            encryptionStatusButton.setTitle("\(itemCount)/\(itemCount) Items Encrypted", for: .normal)
        } else {
            encryptionStatusButton.setTitle("Sign in or register to enable encryption.", for: .normal)
        }
        
        var error : NSError?
        let touchIDContext = LAContext()
        self.touchIDButton.isEnabled = touchIDContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if !touchIDButton.isEnabled {
            touchIDButton.setTitle("Touch ID not available.", for: .normal)
        } else {
            if UserManager.sharedInstance.touchIDEnabled {
                touchIDButton.setTitle("Disable Touch ID", for: .normal)
            } else {
                touchIDButton.setTitle("Enable Touch ID", for: .normal)
            }
        }
        
        self.serverTextField.isEnabled = !signedIn
        self.emailTextField.isEnabled = !signedIn
        self.passwordTextField.isEnabled = !signedIn
        
        self.serverTextField.text = UserManager.sharedInstance.server
        self.emailTextField.text = UserManager.sharedInstance.email
        self.passwordTextField.text = self.password
        
        tableView.reloadData()
        
        serverTextField.isHidden = true
        serverLabel.isHidden = true
        advancedButton.isHidden = false
    }
    
    func getItemCount() -> Int {
        let request = NSFetchRequest<NSFetchRequestResult>()
        request.entity = NSEntityDescription.entity(forEntityName: "Item", in: AppDelegate.sharedContext)
        do {
            let count = try AppDelegate.sharedContext.count(for: request)
            return count
        } catch {
            print("Count error: \(error)")
            return 0
        }
    }
    
    func saveFields() {
        UserManager.sharedInstance.server = self.serverTextField.text!
        UserManager.sharedInstance.email = self.emailTextField.text!
        UserManager.sharedInstance.save()
        
        password = self.passwordTextField.text!
    }
    
    @IBAction func signOutPressed(_ sender: Any) {
        signOut()
    }
    
    func signOut() {
        
        func performSignout() {
            UserManager.sharedInstance.clear()
            ItemManager.sharedInstance.signOut()
            self.password = nil
            reloadData()
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: UserManager.LogoutNotification), object: nil)
        }
        
        let dirtyItems = ItemManager.sharedInstance.fetchDirty()
        if dirtyItems.count > 0 {
            self.showConfirmationAlert(style: .alert, sourceView: nil, title: "Unsaved Changes", message: "You have unsaved changes. Are you sure you want to log out and remove all data from this device?", confirmString: "Sign Out", confirmBlock: {
                performSignout()
            })
        } else {
            self.showConfirmationAlert(style: .actionSheet, sourceView: signOutButton, title: "Sign out?", message: "Signing out will remove all items from this device.", confirmString: "Sign Out", confirmBlock: {
                performSignout()
            })
        }
    }
    
    var server: String? {
        return UserManager.sharedInstance.server
    }
    
    var email: String? {
        return UserManager.sharedInstance.email
    }
    
    func validateForm() -> Bool {
        
        if(server?.characters.count == 0) {
            self.showAlert(title: "Incomplete Form", message: "Please enter a valid server URL.")
            return false
        }
        
        if(email?.characters.count == 0) {
            self.showAlert(title: "Incomplete Form", message: "Please enter a valid email.")
            return false
        }
        
        if(password?.characters.count == 0) {
            self.showAlert(title: "Incomplete Form", message: "Please enter a valid password.")
            return false
        }
        
        return true
    }
    
    @IBAction func signInPressed(_ sender: Any) {
        saveFields()
        
        if !validateForm() {
            return
        }
        
        signIn()
    }

    @IBAction func registerPressed(_ sender: Any) {
        saveFields()
        
        if !validateForm() {
            return
        }
        
        showPasswordConfirmationAlert { (confirmation) in
            if(confirmation == self.password!) {
                self.register()
            } else {
                self.showAlert(title: "Incorrect Confirmation", message: "The two passwords you entered do not match.")
            }
        }
    }
    
    func showPasswordConfirmationAlert(completion: @escaping (String?) -> ()) {
        let alertController = UIAlertController(title: "Confirm Password", message: "Note that because your notes are encrypted on your device using your password, Standard Notes does not have a password reset option. You cannot forget your password.", preferredStyle: .alert)
        
        let saveAction = UIAlertAction(title: "Confirm", style: .default, handler: {
            alert -> Void in
            let textField = alertController.textFields![0] as UITextField
            let text = textField.text!
            completion(text)
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: {
            (action : UIAlertAction!) -> Void in
            completion(nil)
        })
        
        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "Confirm password"
            textField.isSecureTextEntry = true
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func exportDataPressed(_ sender: Any) {
        
        if(!MFMailComposeViewController.canSendMail() ) {
            self.showAlert(title: "Oops", message: "Your device cannot send email.")
            return
        }
        
        let alertController = UIAlertController(title: "Choose data format:", message: nil, preferredStyle: .actionSheet)
        
        alertController.popoverPresentationController?.sourceView = exportButton
        
        let encryptedAction = UIAlertAction(title: "Encrypted", style: .default, handler: {
            alert -> Void in
            let data = ItemManager.sharedInstance.itemsExportJSONData(encrypted: true)
            self.showEmailComposerWithData(data: data)
        })
        
        let decryptedAction = UIAlertAction(title: "Decrypted", style: .destructive, handler: {
            alert -> Void in
            let data = ItemManager.sharedInstance.itemsExportJSONData(encrypted: false)
            self.showEmailComposerWithData(data: data)
        })

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {
            (action : UIAlertAction!) -> Void in
            
        })

        alertController.addAction(encryptedAction)
        alertController.addAction(decryptedAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func showEmailComposerWithData(data: Data) {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setSubject("Standard Notes Data Backup - \(Date())")
        mailComposer.addAttachmentData(data, mimeType: "application/json", fileName: "notes")
        self.present(mailComposer, animated: true, completion: nil)
    }
    
    func showFeedbackComposer() {
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setSubject("Feedback on iOS app (v\(versionNumber).\(buildNumber))")
        mailComposer.setToRecipients(["ios@standardnotes.org"])
        self.present(mailComposer, animated: true, completion: nil)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func encryptionStatusPressed(_ sender: Any) {
        self.showAlert(title: "Encryption Enabled", message: "All your data, including your notes and tags, are encrypted on your device before being sent to the cloud. This means no one can read your notes: not us, not a hacker, and not someone spying on your network.")
    }
    
    @IBAction func learnMorePressed(_ sender: Any) {
        let sf = SFSafariViewController(url: URL(string: "https://standardnotes.org")!)
        sf.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        self.present(sf, animated: true, completion: nil)
    }
    
    func register() {
        ApiController.sharedInstance.register(email: email!, password: password!) { (error) in
            if error != nil {
                self.showAlert(title: "Oops", message: error!)
                return
            }
            self.accountStatusChanged(true)
            self.reloadData()
        }
    }
    
    func signIn() {
        
        ApiController.sharedInstance.signInUser(email: email!, password: password!) { (error, success) in
            if success == false {
                self.showAlert(title: "Oops", message: error != nil ? error! : "An unknown server error occurred.")
                return
            }
            self.accountStatusChanged(true)
            self.reloadData()
        }
    }
    
    @IBAction func showAdvancedPressed(_ sender: UIButton) {
        serverTextField.isHidden = false
        serverLabel.isHidden = false
        sender.isHidden = true
    }
    
    @IBAction func feedbackPressed(_ sender: Any) {
        if(!MFMailComposeViewController.canSendMail() ) {
            self.showAlert(title: "Oops", message: "Your device cannot send email. Please send feedback to ios@standardnotes.org.")
            return
        }
        showFeedbackComposer()
    }
    
    @IBAction func toggleTouchID(toggleButton: UIButton) {
        UserManager.sharedInstance.toggleTouchID()
        if UserManager.sharedInstance.touchIDEnabled {
            touchIDButton.setTitle("Disable Touch ID", for: .normal)
        } else {
             touchIDButton.setTitle("Enable Touch ID", for: .normal)
        }
    }
    
    @IBOutlet var accountHeaderView: UIView!
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if(UserManager.sharedInstance.signedIn) {
            return nil
        }
        if(section == 0) {
            let headerView = UIView()
            headerView.addSubview(accountHeaderView)
            return headerView
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let defaultHeight: CGFloat = 35.0
        if(UserManager.sharedInstance.signedIn) {
            return defaultHeight
        }
        if(section == 0) {
            return 70
        }
        return defaultHeight
    }
    
}

