//
//  WindowManager.swift
//  ClaudeChat
//
//  Created by Amazon Q Developer
//

import SwiftUI
import SwiftData

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var windows: [ChatWindow] = []
    private var windowCounter = 0
    
    private init() {
        // Listen for the global hotkey notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenNewChatWindow),
            name: .openNewChatWindow,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleOpenNewChatWindow() {
        openNewChatWindow()
    }
    
    func openNewChatWindow() {
        windowCounter += 1
        let newWindow = ChatWindow(
            id: "chat-window-\(windowCounter)",
            title: "Quick Chat \(windowCounter)"
        )
        
        DispatchQueue.main.async {
            self.windows.append(newWindow)
            self.showWindow(newWindow)
        }
    }
    
    private func showWindow(_ chatWindow: ChatWindow) {
        // Create and show the window
        let windowController = NSWindowController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = chatWindow.title
        window.center()
        window.setFrameAutosaveName(chatWindow.id)
        
        // Create the SwiftUI view with its own model container
        let contentView = QuickChatView()
            .modelContainer(createModelContainer())
        
        window.contentView = NSHostingView(rootView: contentView)
        windowController.window = window
        
        // Store the window controller to keep it alive
        chatWindow.windowController = windowController
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Handle window closing
        let delegate = WindowDelegate(chatWindow: chatWindow, windowManager: self)
        chatWindow.windowDelegate = delegate
        window.delegate = delegate
    }
    
    func closeWindow(_ chatWindow: ChatWindow) {
        if let index = windows.firstIndex(where: { $0.id == chatWindow.id }) {
            windows.remove(at: index)
        }
    }
    
    private func createModelContainer() -> ModelContainer {
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
    }
}

// Data model for chat windows
class ChatWindow: ObservableObject, Identifiable {
    let id: String
    let title: String
    var windowController: NSWindowController?
    var windowDelegate: WindowDelegate?
    
    init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

// Window delegate to handle window events
class WindowDelegate: NSObject, NSWindowDelegate {
    let chatWindow: ChatWindow
    let windowManager: WindowManager
    
    init(chatWindow: ChatWindow, windowManager: WindowManager) {
        self.chatWindow = chatWindow
        self.windowManager = windowManager
    }
    
    func windowWillClose(_ notification: Notification) {
        windowManager.closeWindow(chatWindow)
    }
}
