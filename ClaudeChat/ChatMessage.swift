//
//  ChatMessage.swift
//  ClaudeChat
//
//  Created by Amazon Q on 7/5/25.
//

import Foundation
import SwiftData

enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
}

@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var isFromUser: Bool
    var timestamp: Date
    var conversationId: UUID
    var messageType: MessageType
    var imageURL: String?
    
    init(content: String, isFromUser: Bool, conversationId: UUID, messageType: MessageType = .text, imageURL: String? = nil) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.conversationId = conversationId
        self.messageType = messageType
        self.imageURL = imageURL
    }
}
