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
import StoreKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    weak var lockOutAlertVC: UIAlertController?
    
    let numRunsBeforeAskingForReview = [5, 20, 50]
    
    var runCount: Int {
        get {
            return UserDefaults.standard.integer(forKey: "runCount")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "runCount")
            UserDefaults.standard.synchronize()
        }
    }
    
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
        handleAppStoreReviewLogic()
        return true
    }
    
    func handleAppStoreReviewLogic() {
        if #available(iOS 10.3, *) {
            runCount += 1
            if(numRunsBeforeAskingForReview.contains(runCount)) {
                SKStoreReviewController.requestReview()
            }
        }
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
            showLockedController()
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

        let container = NSPersistentContainer(name: "standardnotes")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {

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
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    var lockedVC: LockedViewController?
    
    func showLockedController() {
        if self.lockedVC != nil {
            return
        }
    
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        self.lockedVC = storyboard.instantiateViewController(withIdentifier: "LockedVC") as? LockedViewController
        (UIApplication.shared.keyWindow?.rootViewController?.topMostViewController())?.present(self.lockedVC!, animated: false, completion: nil)
    }
    
    func hideLockedController(afterDelay: Double) {
        // return tab to accounts page
        delay(afterDelay) {
            self.lockedVC?.dismiss(animated: true, completion: nil)
            self.lockedVC = nil
        }
    }
    
    func attemptFingerPrint(){
        lockOutAlertVC?.dismiss(animated: false, completion: nil)
        lockOutAlertVC = nil
        guard UserManager.sharedInstance.touchIDEnabled else { return }
        UIApplication.shared.beginIgnoringInteractionEvents()
        
        delay(0.01) {
            self.showLockedController()
        }
        
        let touchIDContext = LAContext()
        var error : NSError?
        let reasonString = "Authentication is needed to access your notes."
        if touchIDContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error){
            touchIDContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reasonString, reply: { [weak self] (success, touchIDError) in
                guard success else {
                    print(error?.localizedDescription ?? "Touch ID Error")
                    OperationQueue.main.addOperation {
                        UIApplication.shared.endIgnoringInteractionEvents()
                        self?.presentLockAlert()
                    }
                    return
                }
                UIApplication.shared.endIgnoringInteractionEvents()
                self?.hideLockedController(afterDelay: 0.01)
            })
        } else {
            print(error?.localizedDescription ?? "Touch ID Error")
            
            // Do PIN code auth
            let context = LAContext()
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reasonString, reply: { [weak self] (success, error) in
                guard success else {
                    print(error?.localizedDescription ?? "Touch ID Error")
                    OperationQueue.main.addOperation {
                        UIApplication.shared.endIgnoringInteractionEvents()
                        self?.presentLockAlert()
                    }
                    return
                }
                UIApplication.shared.endIgnoringInteractionEvents()
                self?.hideLockedController(afterDelay: 0.01)

            })
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
        self.lockedVC?.present(alertController, animated: true, completion: nil)
        lockOutAlertVC = alertController
        
    }

}

