//
//  QuickChatView.swift
//  ClaudeChat
//
//  Created by Amazon Q Developer
//

import SwiftUI
import SwiftData

struct QuickChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var conversations: [Conversation]
    @Query private var allMessages: [ChatMessage]
    
    @State private var currentConversation: Conversation?
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var claudeService = ClaudeService()
    @State private var showingCredentialsAlert = false
    @State private var credentialsStatus = ""
    
    // Computed property to get messages for current conversation
    private var conversationMessages: [ChatMessage] {
        guard let conversation = currentConversation else { return [] }
        return allMessages.filter { $0.conversationId == conversation.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quick Chat")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Test Credentials") {
                    testCredentials()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Chat area
            if let conversation = currentConversation {
                ChatMessagesView(conversation: conversation, messages: conversationMessages, isLoading: isLoading)
            } else {
                VStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Start a new conversation")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Type a message below to begin chatting with Claude")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            // Message input
            HStack {
                TextField("Type your message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(isLoading)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            // Create a new conversation for this quick chat window
            createNewConversation()
        }
        .alert("Credentials Status", isPresented: $showingCredentialsAlert) {
            Button("OK") { }
        } message: {
            Text(credentialsStatus)
        }
    }
    
    private func createNewConversation() {
        let conversation = Conversation(title: "Quick Chat")
        modelContext.insert(conversation)
        currentConversation = conversation
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save conversation: \(error)")
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let conversation = currentConversation else { return }
        
        let userMessage = ChatMessage(
            content: messageText,
            isFromUser: true,
            conversationId: conversation.id
        )
        
        modelContext.insert(userMessage)
        
        // Update conversation title if it's the first message
        if conversation.title == "Quick Chat" {
            let title = String(messageText.prefix(50))
            conversation.title = title.isEmpty ? "Quick Chat" : title
        }
        
        let messageToSend = messageText
        messageText = ""
        isLoading = true
        
        Task {
            do {
                let response = try await claudeService.sendMessage(messageToSend)
                
                await MainActor.run {
                    let assistantMessage = ChatMessage(
                        content: response,
                        isFromUser: false,
                        conversationId: conversation.id
                    )
                    
                    modelContext.insert(assistantMessage)
                    
                    do {
                        try modelContext.save()
                    } catch {
                        print("Failed to save messages: \(error)")
                    }
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Error sending message: \(error)")
                    isLoading = false
                }
            }
        }
    }
    
    private func testCredentials() {
        Task {
            let result = await claudeService.testCredentials()
            await MainActor.run {
                credentialsStatus = result
                showingCredentialsAlert = true
            }
        }
    }
}

// Simplified chat messages view for quick chat
struct ChatMessagesView: View {
    let conversation: Conversation
    let messages: [ChatMessage]
    let isLoading: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages.sorted(by: { $0.timestamp < $1.timestamp })) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Claude is thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading)
                        .id("loading")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    if isLoading {
                        proxy.scrollTo("loading", anchor: .bottom)
                    } else if let lastMessage = messages.sorted(by: { $0.timestamp < $1.timestamp }).last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isLoading) { _, newValue in
                if newValue {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
        }
    }
}
