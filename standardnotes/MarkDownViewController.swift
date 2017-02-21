//
//  MarkDownViewController.swift
//  standardnotes
//
//  Created by Jay Zisch on 2017/02/21.
//  Copyright © 2017 Standard Notes. All rights reserved.
//

import UIKit

class MarkDownViewController: UIViewController {
    
    fileprivate var markDown = Markdown()
    weak var note: Note?
    fileprivate var changesOccuredToNote = false
    fileprivate var observsersAdded = false
    
    @IBOutlet weak var webView: UIWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        load(note: note)
        addObservers()
    }
    
    func addObservers() {
        guard !observsersAdded else { return }
        observsersAdded = true
        note?.addObserver(self, forKeyPath: "text", options: [.new], context: nil)
        note?.addObserver(self, forKeyPath: "title", options: [.new], context: nil)
    }
    
    func removeObservsers() {
        guard observsersAdded else { return }
        observsersAdded = false
        note?.removeObserver(self, forKeyPath: "text")
        note?.removeObserver(self, forKeyPath: "title")
    }
    
    fileprivate func configureNavBar() {
        if let title = title{
            let size = title.size(attributes: navigationController?.navigationBar.titleTextAttributes)
            let rectForTitleLabel = CGRect(origin: CGPoint.zero, size: size)
            let titleLabel = UILabel(frame: rectForTitleLabel)
            titleLabel.attributedText = NSAttributedString(string: title, attributes: navigationController?.navigationBar.titleTextAttributes)
            titleLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(navBarTitleTapped(tapGesture:))))
            titleLabel.isUserInteractionEnabled = true
            tabBarController?.navigationItem.titleView = titleLabel
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "text" || keyPath == "title" {
            changesOccuredToNote = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        load(note: note)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        configureNavBar()
    }
    
    func load(note: Note?) {
        guard let note = note else { return }
        let safeTitle = note.safeTitle()
        let safeText = note.safeText()
        var markDownTextWithTitle = note.safeText()
        if safeTitle != "" {
            markDownTextWithTitle = "#\(safeTitle)\n\n\(safeText)"
        }
        let html = markDown.transform(markDownTextWithTitle)
        webView.loadHTMLString(html, baseURL: nil)
        changesOccuredToNote = false
    }
    
    deinit {
        removeObservsers()
    }
    
    func navBarTitleTapped(tapGesture: UITapGestureRecognizer) {
        tabBarController?.selectedIndex = 0
    }
}
