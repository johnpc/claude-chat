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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
