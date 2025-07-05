//
//  GlobalHotkeyManager.swift
//  ClaudeChat
//
//  Created by Amazon Q Developer
//

import Foundation
import Carbon
import SwiftUI

class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    // Hotkey configuration: Cmd+Shift+A
    private let hotkeyID: UInt32 = 1
    private let keyCode: UInt32 = 0 // 'A' key
    private let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
    
    private init() {}
    
    func registerGlobalHotkey() {
        // Check if accessibility permissions are granted
        guard checkAccessibilityPermissions() else {
            print("Accessibility permissions not granted")
            return
        }
        
        // Unregister existing hotkey if any
        unregisterGlobalHotkey()
        
        // Create event type spec
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Install event handler
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                return GlobalHotkeyManager.shared.handleHotkeyEvent(nextHandler, theEvent, userData)
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        guard status == noErr else {
            print("Failed to install event handler: \(status)")
            return
        }
        
        // Register the hotkey
        var hotkeyID = EventHotKeyID()
        hotkeyID.signature = OSType(fourCharCode("CHAT"))
        hotkeyID.id = self.hotkeyID
        
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerStatus == noErr {
            print("Global hotkey registered successfully (Cmd+Shift+A)")
        } else {
            print("Failed to register global hotkey: \(registerStatus)")
        }
    }
    
    func unregisterGlobalHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    private func handleHotkeyEvent(_ nextHandler: EventHandlerCallRef?, _ theEvent: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
        // Trigger the action to open a new chat window
        DispatchQueue.main.async {
            self.openNewChatWindow()
        }
        return noErr
    }
    
    private func openNewChatWindow() {
        // Post a notification that will be handled by the app
        NotificationCenter.default.post(name: .openNewChatWindow, object: nil)
    }
    
    private func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

// Helper function to create FourCharCode
private func fourCharCode(_ string: String) -> FourCharCode {
    assert(string.count == 4, "String must be exactly 4 characters")
    var result: FourCharCode = 0
    for char in string.utf8 {
        result = (result << 8) + FourCharCode(char)
    }
    return result
}

// Notification name for opening new chat window
extension Notification.Name {
    static let openNewChatWindow = Notification.Name("openNewChatWindow")
}
