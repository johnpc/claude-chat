//
//  Conversation.swift
//  ClaudeChat
//
//  Created by Amazon Q on 7/5/25.
//

import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var lastMessageAt: Date
    
    init(title: String = "New Conversation") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.lastMessageAt = Date()
    }
}
