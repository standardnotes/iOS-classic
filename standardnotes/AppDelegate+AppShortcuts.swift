//
//  AppDelegate+AppShortcuts.swift
//  standardnotes
//
//  Created by Florian Schuttkowski (Flowinho) on 02.05.17.
//  Copyright © 2017 Standard Notes / Florian Schuttkowski. All rights reserved.
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
            navigateToComposerController(after: 0.01)
            succeeded = true
        case .listNotes:
           navigateToNotesController(afterDelay: 0.01)
            succeeded = true
        }
        return succeeded
    }

    func navigateToComposerController(after delayInSeconds: Double) {
        delay(delayInSeconds) {
            // This is needed to get access to the navigation controller since the storyboard defines nested 
            // navigation controllers.
            // Double checking this.
            if let tabController = UIApplication.shared.keyWindow?.rootViewController as? UITabBarController {
                    // This optional binding to NotesViewController fails. Investigate
                    if let navController = tabController.selectedViewController as? UINavigationController {
                        // String identifier for viewController reference in SB - replace this by an enum
                        if let compose = navController.storyboard?.instantiateViewController(withIdentifier: "Compose") as? ComposeViewController {
                            navController.pushViewController(compose, animated: true)
                        }
                }
            }
        }
    }

}

