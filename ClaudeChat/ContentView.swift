//
//  ContentView.swift
//  ClaudeChat
//
//  Created by Corser, John on 7/5/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.lastMessageAt, order: .reverse) private var conversations: [Conversation]
    @Query private var allMessages: [ChatMessage]
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedConversation) {
                ForEach(conversations) { conversation in
                    NavigationLink(value: conversation) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title)
                                .font(.headline)
                                .lineLimit(1)
                            
                            Text(conversation.lastMessageAt, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete(perform: deleteConversations)
            }
            .navigationTitle("Conversations")
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addConversation) {
                        Label("New Chat", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button(action: setupCredentials) {
                        Label("Setup AWS Credentials", systemImage: "arrow.down.circle")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button(action: testCredentials) {
                        Label("Test AWS Credentials", systemImage: "key")
                    }
                }
            }
        } detail: {
            if let conversation = selectedConversation {
                ChatView(conversation: conversation)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Select a conversation or start a new chat")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Button("New Conversation") {
                        addConversation()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func addConversation() {
        withAnimation {
            let newConversation = Conversation()
            modelContext.insert(newConversation)
            selectedConversation = newConversation
        }
    }

    private func deleteConversations(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let conversation = conversations[index]
                
                // Delete all messages in this conversation
                let messagesToDelete = allMessages.filter { $0.conversationId == conversation.id }
                for message in messagesToDelete {
                    modelContext.delete(message)
                }
                
                modelContext.delete(conversation)
            }
        }
    }
    
    private func testCredentials() {
        let credentialsManager = AWSCredentialsManager.shared
        if let credentials = credentialsManager.loadCredentials() {
            print("✅ AWS Credentials loaded successfully!")
            print("Access Key ID: \(credentials.accessKeyId.prefix(8))...")
            print("Region: \(credentials.region)")
        } else {
            print("❌ Failed to load AWS credentials")
        }
    }
    
    private func setupCredentials() {
        // Try to copy credentials from the real home directory to the container
        let realCredentialsPath = "/Users/\(NSUserName())/.aws/credentials"
        let realConfigPath = "/Users/\(NSUserName())/.aws/config"
        
        let containerHome = NSHomeDirectory()
        let containerAwsDir = "\(containerHome)/.aws"
        let containerCredentialsPath = "\(containerAwsDir)/credentials"
        let containerConfigPath = "\(containerAwsDir)/config"
        
        // Create .aws directory in container if it doesn't exist
        do {
            try FileManager.default.createDirectory(atPath: containerAwsDir, withIntermediateDirectories: true)
            print("✅ Created .aws directory in container: \(containerAwsDir)")
        } catch {
            print("❌ Failed to create .aws directory: \(error)")
        }
        
        // Copy credentials file
        if FileManager.default.fileExists(atPath: realCredentialsPath) {
            do {
                let credentialsContent = try String(contentsOfFile: realCredentialsPath)
                try credentialsContent.write(toFile: containerCredentialsPath, atomically: true, encoding: .utf8)
                print("✅ Copied credentials to container")
            } catch {
                print("❌ Failed to copy credentials: \(error)")
            }
        } else {
            print("❌ Real credentials file not found at: \(realCredentialsPath)")
        }
        
        // Copy config file
        if FileManager.default.fileExists(atPath: realConfigPath) {
            do {
                let configContent = try String(contentsOfFile: realConfigPath)
                try configContent.write(toFile: containerConfigPath, atomically: true, encoding: .utf8)
                print("✅ Copied config to container")
            } catch {
                print("❌ Failed to copy config: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Conversation.self, inMemory: true)
}
