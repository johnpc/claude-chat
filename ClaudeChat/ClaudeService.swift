// This is the complete implementation using AWS SDK for Swift
import Foundation
import SwiftUI
import AWSBedrockRuntime
import AWSClientRuntime
import AWSSDKIdentity

class ClaudeService: ObservableObject {
    static let shared = ClaudeService()
    
    private let credentialsManager = AWSCredentialsManager.shared
    private let modelId = "arn:aws:bedrock:us-east-1:273354634817:inference-profile/us.anthropic.claude-opus-4-20250514-v1:0"
    private var bedrockClient: BedrockRuntimeClient?
    
    init() {
        setupAWSClient()
    }
    
    private func setupAWSClient() {
        guard let credentials = credentialsManager.loadCredentials() else {
            print("❌ Failed to load AWS credentials")
            return
        }
        
        Task {
            do {
                // Create AWS credential identity resolver
                let credentialsProvider = StaticAWSCredentialIdentityResolver(
                    AWSCredentialIdentity(
                        accessKey: credentials.accessKeyId,
                        secret: credentials.secretAccessKey,
                        sessionToken: credentials.sessionToken
                    )
                )
                
                // Create Bedrock client configuration with explicit credentials
                let config = try await BedrockRuntimeClient.BedrockRuntimeClientConfiguration(
                    awsCredentialIdentityResolver: credentialsProvider,
                    region: credentials.region
                )
                
                // Create Bedrock client with explicit configuration
                bedrockClient = BedrockRuntimeClient(config: config)
                
                print("✅ AWS Bedrock client initialized successfully")
            } catch {
                print("❌ Failed to initialize AWS Bedrock client: \(error)")
            }
        }
    }
    
    func testCredentials() -> String {
        guard let credentials = credentialsManager.loadCredentials() else {
            return "❌ AWS credentials not found"
        }
        
        return """
        ✅ AWS credentials loaded successfully
        Region: \(credentials.region)
        Access Key ID: \(String(credentials.accessKeyId.prefix(8)))...
        Session Token: \(credentials.sessionToken != nil ? "✅ Present" : "❌ Missing")
        """
    }
    
    func sendMessage(_ message: String, conversationHistory: [ChatMessage] = []) async throws -> String {
        guard let client = bedrockClient else {
            throw ClaudeError.credentialsNotFound
        }
        
        // Convert conversation history to Claude format
        var claudeMessages: [ClaudeMessage] = []
        
        // Add conversation history
        for historyMessage in conversationHistory {
            let role = historyMessage.isFromUser ? "user" : "assistant"
            claudeMessages.append(ClaudeMessage(role: role, content: historyMessage.content))
        }
        
        // Add current message
        claudeMessages.append(ClaudeMessage(role: "user", content: message))
        
        // Create the request payload
        let requestPayload = ClaudeRequest(messages: claudeMessages)
        let requestBody = try JSONEncoder().encode(requestPayload)
        
        // Create the Bedrock request
        let request = InvokeModelInput(
            body: requestBody,
            modelId: modelId
        )
        
        do {
            // Make the API call using AWS SDK
            let response = try await client.invokeModel(input: request)
            
            // Parse the response
            guard let responseBody = response.body else {
                throw ClaudeError.invalidResponse
            }
            
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: responseBody)
            
            guard let firstContent = claudeResponse.content.first else {
                throw ClaudeError.invalidResponse
            }
            
            return firstContent.text
        } catch {
            print("AWS Bedrock Error: \(error)")
            throw ClaudeError.apiError(error.localizedDescription)
        }
    }
    
    func generateConversationTitle(userMessage: String, assistantResponse: String) async throws -> String {
        guard let client = bedrockClient else {
            throw ClaudeError.credentialsNotFound
        }
        
        let titlePrompt = """
        Based on this conversation exchange, generate a concise, descriptive title (maximum 6 words) that captures the main topic or question being discussed:

        User: \(userMessage)
        Assistant: \(assistantResponse)

        Respond with only the title, no additional text or formatting.
        """
        
        let claudeMessages = [ClaudeMessage(role: "user", content: titlePrompt)]
        let requestPayload = ClaudeRequest(messages: claudeMessages, max_tokens: 50)
        let requestBody = try JSONEncoder().encode(requestPayload)
        
        let request = InvokeModelInput(
            body: requestBody,
            modelId: modelId
        )
        
        do {
            let response = try await client.invokeModel(input: request)
            
            guard let responseBody = response.body else {
                throw ClaudeError.invalidResponse
            }
            
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: responseBody)
            
            guard let firstContent = claudeResponse.content.first else {
                throw ClaudeError.invalidResponse
            }
            
            // Clean up the title - remove quotes and trim whitespace
            let title = firstContent.text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
            
            // Ensure title isn't empty and has a reasonable length
            if title.isEmpty {
                return String(userMessage.prefix(50))
            }
            
            return String(title.prefix(60)) // Limit to 60 characters max
        } catch {
            print("Title generation error: \(error)")
            // Fallback to first part of user message if title generation fails
            return String(userMessage.prefix(50))
        }
    }
}

// MARK: - Data Models

struct ClaudeRequest: Codable {
    let messages: [ClaudeMessage]
    var max_tokens: Int = 4096
    var anthropic_version: String = "bedrock-2023-05-31"
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let content: [ClaudeContent]
    let usage: ClaudeUsage?
}

struct ClaudeContent: Codable {
    let text: String
    let type: String
}

struct ClaudeUsage: Codable {
    let input_tokens: Int?
    let output_tokens: Int?
}

enum ClaudeError: Error, LocalizedError {
    case credentialsNotFound
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            return "AWS credentials not found"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let message):
            return "API Error: \(message)"
        }
    }
}
