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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNote()
        configureNavBar()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if self.note.title != nil {
            self.titleTextField.text = self.note.safeTitle()
            self.textView.text = self.note.safeText()
            self.textView.becomeFirstResponder()
        } else {
            self.titleTextField.becomeFirstResponder()
        }
    }
    
    func configureNavBar() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelPressed))
        self.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(savePressed)),
            UIBarButtonItem(title: "Tags", style: .plain, target: self, action: #selector(tagsPressed))
        ]
    }
    
    func configureNote() {
        if self.note == nil {
            self.note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: AppDelegate.sharedContext) as! Note
            self.note.dirty = true
            self.note.draft = true
        }        
    }
    
    func tagsPressed() {
        let tags = self.storyboard?.instantiateViewController(withIdentifier: "Tags") as! TagsViewController
        tags.setInitialSelectedTags(tags: self.note.tags?.allObjects as! [Tag])
        tags.selectionCompletion = { tags in
            self.note.replaceTags(withTags: tags)
        }
        let nav = UINavigationController(rootViewController: tags)
        self.present(nav, animated: true, completion: nil)
    }

    func cancelPressed(_ sender: Any) {
        AppDelegate.sharedInstance.saveContext()
        self.dismiss(animated: true, completion: nil)
    }
   
    func savePressed(_ sender: Any) {
        self.note.title = self.titleTextField.text
        self.note.text = self.textView.text
        self.note.draft = false
        self.note.dirty = true
        AppDelegate.sharedInstance.saveContext()
        self.dismiss(animated: true, completion: nil)
    }

}
