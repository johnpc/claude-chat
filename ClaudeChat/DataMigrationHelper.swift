//
//  DataMigrationHelper.swift
//  ClaudeChat
//
//  Created by Amazon Q on 7/6/25.
//

import Foundation
import SwiftData

class DataMigrationHelper {
    static func clearDataStoreIfNeeded() {
        // Get the default SwiftData store location
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "ClaudeChat"
        let storeURL = appSupport.appendingPathComponent(bundleID).appendingPathComponent("default.store")
        
        // Check if the store exists and remove it if there are migration issues
        if FileManager.default.fileExists(atPath: storeURL.path) {
            do {
                try FileManager.default.removeItem(at: storeURL)
                print("🗑️ Cleared existing data store for migration")
            } catch {
                print("⚠️ Could not clear data store: \(error)")
            }
        }
    }
}
