//
//  ClaudeChatApp.swift
//  ClaudeChat
//
//  Created by Corser, John on 7/5/25.
//

import SwiftUI
import SwiftData

@main
struct ClaudeChatApp: App {
    @StateObject private var windowManager = WindowManager.shared
    @StateObject private var hotkeyManager = GlobalHotkeyManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Conversation.self,
            ChatMessage.self,
        ])
        
        // Create a unique URL for the database to force a fresh start if needed
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupportURL.appendingPathComponent("ClaudeChat.sqlite")
        
        let modelConfiguration = ModelConfiguration(
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("⚠️ ModelContainer creation failed: \(error)")
            
            // If there's a schema mismatch, delete the old database and create fresh
            do {
                // Remove old database files
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: storeURL.path) {
                    try fileManager.removeItem(at: storeURL)
                    print("🗑️ Removed old database due to schema mismatch")
                }
                
                // Also remove related files
                let shmURL = storeURL.appendingPathExtension("shm")
                let walURL = storeURL.appendingPathExtension("wal")
                
                if fileManager.fileExists(atPath: shmURL.path) {
                    try fileManager.removeItem(at: shmURL)
                }
                if fileManager.fileExists(atPath: walURL.path) {
                    try fileManager.removeItem(at: walURL)
                }
                
                let freshConfiguration = ModelConfiguration(
                    url: storeURL,
                    allowsSave: true,
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(for: schema, configurations: [freshConfiguration])
                print("✅ Created fresh ModelContainer after clearing old data")
                return container
            } catch {
                print("❌ Failed to create fresh ModelContainer: \(error)")
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Register the global hotkey when the app starts
                    hotkeyManager.registerGlobalHotkey()
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Quick Chat Window") {
                    windowManager.openNewChatWindow()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            
            CommandGroup(replacing: .help) {
                Button("Request Accessibility Permissions") {
                    hotkeyManager.requestAccessibilityPermissions()
                }
            }
        }
    }
}
