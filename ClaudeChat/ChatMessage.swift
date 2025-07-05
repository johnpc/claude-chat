//
//  ChatMessage.swift
//  ClaudeChat
//
//  Created by Amazon Q on 7/5/25.
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var isFromUser: Bool
    var timestamp: Date
    var conversationId: UUID
    
    init(content: String, isFromUser: Bool, conversationId: UUID) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.conversationId = conversationId
    }
}
