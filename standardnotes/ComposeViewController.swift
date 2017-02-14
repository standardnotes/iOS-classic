//
//  ComposeViewController.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/21/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import UIKit
import CoreData

class ComposeViewController: UIViewController {

    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var textView: UITextView!
    var note: Note!
    var saving: Bool = false
    var saved: Bool = false
    var saveTimer: Timer!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
        
        textView.layoutManager.delegate = self
        textView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12)

        configureNote()
        configureNavBar()
        configureKeyboardNotifications()
        
        titleTextField.text = self.note?.safeTitle()
        textView.text = self.note?.safeText()
    }
    
    func configureKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWasShown(aNotification:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillBeHidden(aNotification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    func keyboardWasShown(aNotification:NSNotification) {
        let info = aNotification.userInfo
        let infoNSValue = info![UIKeyboardFrameEndUserInfoKey] as! NSValue
        let kbSize = infoNSValue.cgRectValue.size
        let contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0)
        textView.contentInset = contentInsets
        textView.scrollIndicatorInsets = contentInsets
    }
    
    func keyboardWillBeHidden(aNotification:NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        textView.contentInset = contentInsets
        textView.scrollIndicatorInsets = contentInsets
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.note.text == nil {
            self.textView.becomeFirstResponder()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func configureNavBar() {
        let tagsTitle = note.tags!.count > 0 ? "Tags (\(note.tags!.count))" : "Tags"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: tagsTitle, style: .plain, target: self, action: #selector(tagsPressed))
    }
    
    func reloadTitle(offline: Bool) {
        let titleString = NSMutableAttributedString(string: "Compose" + (saving || saved ? "\n" : ""), attributes: [NSFontAttributeName: UIFont.boldSystemFont(ofSize: 17.0)])
        
        if saving || saved {
            let subtitleAttribute = [NSForegroundColorAttributeName: offline ? UIColor.red : UIColor.gray , NSFontAttributeName: UIFont.systemFont(ofSize: 12.0)]
            let string = offline ? "Offline" : (saving ? "Saving..." : "All changes saved")
            let subtitleString = NSAttributedString(string: string, attributes: subtitleAttribute)
            titleString.append(subtitleString)
        }
        
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: titleString.size().width, height: 44))
        label.numberOfLines = 0
        label.textAlignment = NSTextAlignment.center
        label.attributedText = titleString
        self.navigationItem.titleView = label
    }
    
    let NoteTitlePlaceholder = ""
    
    func configureNote() {
        if self.note == nil {
            self.note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: AppDelegate.sharedContext) as! Note
            self.note.title = NoteTitlePlaceholder
            self.note.dirty = true
            self.note.draft = true
        }        
    }
    
    func tagsPressed() {
        let tags = self.storyboard?.instantiateViewController(withIdentifier: "Tags") as! TagsViewController
        tags.setInitialSelectedTags(tags: self.note.tags?.allObjects as! [Tag])
        tags.selectionCompletion = { tags in
            self.note.replaceTags(withTags: tags)
            self.configureNavBar()
            self.save()
        }

        self.navigationController?.pushViewController(tags, animated: true)
    }
    
    var didShowErrorAlert: Bool = false

    func save() {
        saving = true
        saved = false
        reloadTitle(offline: false)
        self.note.title = self.titleTextField.text
        self.note.text = self.textView.text
        self.note.draft = false
        self.note.dirty = true
        ApiController.sharedInstance.sync { error in
            self.saving = false
            self.saved = true

            if error == nil {
                delay(0.1, closure: {
                    self.reloadTitle(offline: false)
                })
            } else {
                delay(0.2, closure: {
                    self.reloadTitle(offline: true)
                })
                if(!self.didShowErrorAlert) {
                    self.showAlert(title: "Oops", message: "There was an error saving your data to the server. Please check your server settings and try again.")
                    self.didShowErrorAlert = true
                }
            }
        }
    }
    
    @IBAction func titleFieldEditingChanged(_ sender: Any) {
        beginSaveTimer()
    }
    
}

extension ComposeViewController : NSLayoutManagerDelegate {
  
    func layoutManager(_ layoutManager: NSLayoutManager, lineSpacingAfterGlyphAt glyphIndex: Int, withProposedLineFragmentRect rect: CGRect) -> CGFloat {
        return 2
    }
    
}

extension ComposeViewController : UITextViewDelegate {
    func beginSaveTimer() {
        if saveTimer != nil {
            saveTimer.invalidate()
        }
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false, block: { (timer) in
            self.save()
        })
    }
    
    func textViewDidChange(_ textView: UITextView) {
        beginSaveTimer()
        
    }
}
