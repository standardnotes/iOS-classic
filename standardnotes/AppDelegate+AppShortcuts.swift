//
//  AppDelegate+AppShortcuts.swift
//  standardnotes
//
//  Created by Seishinryoku on 02.05.17.
//  Copyright © 2017 Standard Notes. All rights reserved.
//

import Foundation
import UIKit

enum ApplicationShortCut:String {
    case newNote = "org.standardnotes.standardnotes.new-note"
    case listNotes = "org.standardnotes.standardnotes.list-notes"
}

extension AppDelegate {
    
    // MARK: - 3D Touch Application shortcut handling
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(handleShortcut(item:shortcutItem))
    }
    
    func handleShortcut(item:UIApplicationShortcutItem) -> Bool {
        print(item.type)
        guard let shortCut = ApplicationShortCut.init(rawValue: item.type) else {
            return false
        }
        
        var succeeded = false
        switch shortCut {
        case .newNote:
            navigateToViewControllerFor(shortcut: shortCut)
            succeeded = true
        case .listNotes:
            navigateToViewControllerFor(shortcut: shortCut)
            succeeded = true
        }
        return succeeded
    }
    
    func navigateToViewControllerFor(shortcut:ApplicationShortCut){
        switch shortcut {
        case .newNote:
            print("")
        case .listNotes:
            navigateToNotesController(afterDelay: 0.01)
        }
    }
}

