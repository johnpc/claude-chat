//
//  ChatView.swift
//  ClaudeChat
//
//  Created by Amazon Q on 7/5/25.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    let conversation: Conversation
    @Environment(\.modelContext) private var modelContext
    @Query private var allMessages: [ChatMessage]
    @StateObject private var claudeService = ClaudeService.shared
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var messages: [ChatMessage] {
        allMessages.filter { $0.conversationId == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    var body: some View {
        VStack {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages, id: \.id) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Claude is thinking...")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            // Input area with image generation hint
            VStack(spacing: 8) {
                // Hint text
                Text("💡 Try: \"Generate an image of a sunset over mountains\" or ask any question")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                HStack {
                    TextField("Type your message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(1...5)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(messageText.isEmpty ? .gray : .blue)
                    }
                    .disabled(messageText.isEmpty || isLoading)
                }
                .padding()
            }
        }
        .navigationTitle(conversation.title)
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = messageText
        messageText = ""
        errorMessage = nil
        
        // Check if this is the first message in the conversation
        let isFirstMessage = messages.isEmpty
        
        // Add user message to database
        let userChatMessage = ChatMessage(
            content: userMessage,
            isFromUser: true,
            conversationId: conversation.id,
            messageType: .text
        )
        modelContext.insert(userChatMessage)
        
        // Update conversation timestamp
        conversation.lastMessageAt = Date()
        
        isLoading = true
        
        Task {
            do {
                // Use the enhanced processMessage method
                let response = try await claudeService.processMessage(userMessage, conversationHistory: messages)
                
                await MainActor.run {
                    // Add Claude's response to database
                    let claudeMessage = ChatMessage(
                        content: response.text,
                        isFromUser: false,
                        conversationId: conversation.id,
                        messageType: response.isImageGeneration ? .image : .text,
                        imageURL: response.imageURL?.absoluteString
                    )
                    modelContext.insert(claudeMessage)
                    
                    // Update conversation timestamp
                    conversation.lastMessageAt = Date()
                    
                    isLoading = false
                    
                    // Generate title if this was the first message and title is still default
                    if isFirstMessage && conversation.title == "New Conversation" {
                        Task {
                            do {
                                let generatedTitle = try await claudeService.generateConversationTitle(
                                    userMessage: userMessage,
                                    assistantResponse: response.text
                                )
                                
                                await MainActor.run {
                                    conversation.title = generatedTitle
                                    try? modelContext.save()
                                }
                            } catch {
                                print("Failed to generate conversation title: \(error)")
                                // Fallback to truncated user message
                                await MainActor.run {
                                    conversation.title = String(userMessage.prefix(50))
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                VStack(alignment: .trailing) {
                    Text(message.content)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
            } else {
                VStack(alignment: .leading) {
                    // Message content
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message.content)
                            .padding(12)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Display image if this is an image message
                        if message.messageType == .image, 
                           let imageURLString = message.imageURL,
                           let imageURL = URL(string: imageURLString) {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 300, maxHeight: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 300, height: 200)
                                    .overlay(
                                        ProgressView()
                                    )
                            }
                            .contextMenu {
                                Button("Save Image") {
                                    saveImageToDesktop(url: imageURL)
                                }
                                Button("Copy Image") {
                                    copyImageToClipboard(url: imageURL)
                                }
                            }
                        }
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity * 0.8, alignment: .leading)
                Spacer()
            }
        }
    }
    
    private func saveImageToDesktop(url: URL) {
        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            print("Could not access desktop directory")
            return
        }
        
        let destinationURL = desktopURL.appendingPathComponent("ClaudeChat_Image_\(UUID().uuidString).png")
        
        do {
            let imageData = try Data(contentsOf: url)
            try imageData.write(to: destinationURL)
            print("Image saved to desktop: \(destinationURL.path)")
        } catch {
            print("Failed to save image to desktop: \(error)")
        }
    }
    
    private func copyImageToClipboard(url: URL) {
        do {
            let imageData = try Data(contentsOf: url)
            if let image = NSImage(data: imageData) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([image])
                print("Image copied to clipboard")
            }
        } catch {
            print("Failed to copy image to clipboard: \(error)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, ChatMessage.self, configurations: config)
    
    let conversation = Conversation(title: "Test Chat")
    container.mainContext.insert(conversation)
    
    return NavigationView {
        ChatView(conversation: conversation)
    }
    .modelContainer(container)
}
