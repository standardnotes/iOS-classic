//
//  AppDelegate.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/19/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import UIKit
import CoreData
import LocalAuthentication
import HockeySDK


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    weak var lockOutAlertVC: UIAlertController?
    
    static let sharedContext: NSManagedObjectContext = {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.persistentContainer.viewContext
    }()
    
    static let sharedInstance: AppDelegate = {
        return UIApplication.shared.delegate as! AppDelegate
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Theme.Initialize()
        ItemManager.initializeSharedInstance(context: self.persistentContainer.viewContext)
        attemptFingerPrint()
        initializeCrashReporting()
        SyncController.sharedInstance.startSyncing()
        return true
    }
    
    func initializeCrashReporting() {
        BITHockeyManager.shared().configure(withIdentifier: "f6d12c22bdad48e5a07aa578822b4620")
        BITHockeyManager.shared().isMetricsManagerDisabled = true
        BITHockeyManager.shared().start()
        BITHockeyManager.shared().authenticator.authenticateInstallation()
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        if UserManager.sharedInstance.touchIDEnabled {
            navigateToAccountController(afterDelay: 0)
        }
        SyncController.sharedInstance.stopSyncing()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        attemptFingerPrint()
        SyncController.sharedInstance.startSyncing()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "standardnotes")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {

        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func navigateToAccountController(afterDelay: Double) {
        // return tab to accounts page
        delay(afterDelay) {
            (UIApplication.shared.keyWindow?.rootViewController as? UITabBarController)?.selectedIndex = 1
        }
    }
    
    func navigateToNotesController(afterDelay: Double) {
        // return tab to accounts page
        delay(afterDelay) {
            (UIApplication.shared.keyWindow?.rootViewController as? UITabBarController)?.selectedIndex = 0
        }
    }
    
    func attemptFingerPrint(){
        lockOutAlertVC?.dismiss(animated: false, completion: nil)
        lockOutAlertVC = nil
        guard UserManager.sharedInstance.touchIDEnabled else { return }
        UIApplication.shared.beginIgnoringInteractionEvents()
        
        navigateToAccountController(afterDelay: 0.1)
        
        let touchIDContext = LAContext()
        var error : NSError?
        let reasonString = "Authentication is needed to access your notes."
        if touchIDContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error){
            touchIDContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reasonString, reply: { [weak self] (success, touchIDError) in
                guard success else {
                    print(error?.localizedDescription ?? "touch id error")
                    OperationQueue.main.addOperation {
                        UIApplication.shared.endIgnoringInteractionEvents()
                        self?.presentLockAlert()
                    }
                    return
                }
                UIApplication.shared.endIgnoringInteractionEvents()
                self?.navigateToNotesController(afterDelay: 0.01)
            })
        } else {
            UIApplication.shared.endIgnoringInteractionEvents()
            print(error?.localizedDescription ?? "touch id error")
        }
        
    }
    
    func presentLockAlert(){
        guard lockOutAlertVC == nil else {
            return
        }
        let alertController = UIAlertController(title: "Fingerprint Required", message: "Notes are locked with Touch ID. Please try again.", preferredStyle: .alert)
        let retryTouchIDAction = UIAlertAction(title: "Try Again", style: .default, handler: { [weak self]
            alert -> Void in
            self?.attemptFingerPrint()
        })
        alertController.addAction(retryTouchIDAction)
        UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
        lockOutAlertVC = alertController
        
    }

}

