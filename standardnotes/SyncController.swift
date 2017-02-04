//
//  SyncController.swift
//  standardnotes
//
//  Created by Jay Zisch on 2017/02/04.
//  Copyright © 2017 Standard Notes. All rights reserved.
//

import Foundation

class SyncController {
    
    static var sharedInstance = SyncController()
    
    var syncTimer : Timer?
    let syncTimeInterval : TimeInterval = 30
    
    func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncTimeInterval, repeats: true, block: { (timer) in
            ApiController.sharedInstance.sync(completion: { (error) in})
        })
    }
    
    func stopSyncTimer() {
        syncTimer?.invalidate()
    }
}
