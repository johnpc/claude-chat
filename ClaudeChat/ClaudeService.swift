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
    private var lastCredentialsCheck: Date = Date.distantPast
    private let credentialsRefreshInterval: TimeInterval = 300 // 5 minutes
    private let novaCanvasService = NovaCanvasService.shared
    
    init() {
        // Don't setup client immediately - do it on first use
    }
    
    private func ensureFreshClient() async throws -> BedrockRuntimeClient {
        let now = Date()
        
        // Check if we need to refresh credentials (every 5 minutes or if no client exists)
        if bedrockClient == nil || now.timeIntervalSince(lastCredentialsCheck) > credentialsRefreshInterval {
            print("🔄 Refreshing AWS credentials...")
            
            guard let credentials = credentialsManager.loadCredentials() else {
                print("❌ Failed to load AWS credentials")
                throw ClaudeError.credentialsNotFound
            }
            
            do {
                // Create AWS credential identity resolver with fresh credentials
                let credentialsProvider = StaticAWSCredentialIdentityResolver(
                    AWSCredentialIdentity(
                        accessKey: credentials.accessKeyId,
                        secret: credentials.secretAccessKey,
                        sessionToken: credentials.sessionToken
                    )
                )
                
                // Create Bedrock client configuration with fresh credentials
                let config = try await BedrockRuntimeClient.BedrockRuntimeClientConfiguration(
                    awsCredentialIdentityResolver: credentialsProvider,
                    region: credentials.region
                )
                
                // Create new Bedrock client with fresh configuration
                bedrockClient = BedrockRuntimeClient(config: config)
                lastCredentialsCheck = now
                
                print("✅ AWS Bedrock client refreshed successfully")
                print("Region: \(credentials.region)")
                print("Access Key ID: \(String(credentials.accessKeyId.prefix(8)))...")
                print("Session Token: \(credentials.sessionToken != nil ? "✅ Present" : "❌ Not present")")
            } catch {
                print("❌ Failed to refresh AWS Bedrock client: \(error)")
                throw ClaudeError.apiError("Failed to refresh AWS client: \(error.localizedDescription)")
            }
        }
        
        guard let client = bedrockClient else {
            throw ClaudeError.credentialsNotFound
        }
        
        return client
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
    
    // Enhanced message processing that can handle tool calls
    func processMessage(_ message: String, conversationHistory: [ChatMessage] = []) async throws -> ProcessedResponse {
        // Check if this is an image generation request
        if isImageGenerationRequest(message) {
            let imagePrompt = extractImagePrompt(from: message)
            
            do {
                let imageData = try await novaCanvasService.generateImage(
                    prompt: imagePrompt,
                    negativePrompt: "people, anatomy, hands, low quality, low resolution, low detail"
                )
                
                // Save image to documents directory
                if let imageURL = novaCanvasService.saveImageToDocuments(imageData, filename: "nova_canvas_image") {
                    return ProcessedResponse(
                        text: "I've generated an image based on your request: \"\(imagePrompt)\"",
                        imageURL: imageURL,
                        isImageGeneration: true
                    )
                } else {
                    throw ClaudeError.apiError("Failed to save generated image")
                }
            } catch {
                // If image generation fails, fall back to text response
                let fallbackMessage = "I tried to generate an image for you, but encountered an error: \(error.localizedDescription). Let me provide a text response instead."
                let textResponse = try await sendMessage(message, conversationHistory: conversationHistory)
                return ProcessedResponse(text: fallbackMessage + "\n\n" + textResponse, imageURL: nil, isImageGeneration: false)
            }
        } else {
            // Regular text conversation
            let textResponse = try await sendMessage(message, conversationHistory: conversationHistory)
            return ProcessedResponse(text: textResponse, imageURL: nil, isImageGeneration: false)
        }
    }
    
    private func isImageGenerationRequest(_ message: String) -> Bool {
        let lowercaseMessage = message.lowercased()
        let imageKeywords = [
            "generate an image", "create an image", "make an image", "draw", "generate a picture",
            "create a picture", "make a picture", "show me", "visualize", "illustrate",
            "paint", "sketch", "render", "design", "create art", "make art"
        ]
        
        return imageKeywords.contains { keyword in
            lowercaseMessage.contains(keyword)
        }
    }
    
    private func extractImagePrompt(from message: String) -> String {
        let lowercaseMessage = message.lowercased()
        
        // Common patterns to extract the actual image description
        let patterns = [
            "generate an image of ",
            "create an image of ",
            "make an image of ",
            "draw ",
            "show me ",
            "visualize ",
            "illustrate ",
            "paint ",
            "sketch ",
            "render ",
            "design ",
            "create art of ",
            "make art of "
        ]
        
        for pattern in patterns {
            if let range = lowercaseMessage.range(of: pattern) {
                let startIndex = message.index(message.startIndex, offsetBy: range.upperBound.utf16Offset(in: lowercaseMessage))
                return String(message[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // If no specific pattern found, use the whole message as the prompt
        return message
    }
    
    func sendMessage(_ message: String, conversationHistory: [ChatMessage] = []) async throws -> String {
        let client = try await ensureFreshClient()
        
        // Convert conversation history to Claude format (only text messages)
        var claudeMessages: [ClaudeMessage] = []
        
        // Add conversation history (filter out image messages for Claude)
        for historyMessage in conversationHistory {
            if historyMessage.messageType == .text {
                let role = historyMessage.isFromUser ? "user" : "assistant"
                claudeMessages.append(ClaudeMessage(role: role, content: historyMessage.content))
            }
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
            
            // If we get an authentication error, try refreshing credentials once more
            if error.localizedDescription.contains("403") || 
               error.localizedDescription.contains("Forbidden") ||
               error.localizedDescription.contains("expired") ||
               error.localizedDescription.contains("invalid") {
                print("🔄 Authentication error detected, forcing credential refresh...")
                
                // Force refresh by resetting the client and timestamp
                bedrockClient = nil
                lastCredentialsCheck = Date.distantPast
                
                // Try once more with fresh credentials
                let freshClient = try await ensureFreshClient()
                let retryResponse = try await freshClient.invokeModel(input: request)
                
                guard let retryResponseBody = retryResponse.body else {
                    throw ClaudeError.invalidResponse
                }
                
                let retryClaudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: retryResponseBody)
                
                guard let retryFirstContent = retryClaudeResponse.content.first else {
                    throw ClaudeError.invalidResponse
                }
                
                return retryFirstContent.text
            }
            
            throw ClaudeError.apiError(error.localizedDescription)
        }
    }
    
    func generateConversationTitle(userMessage: String, assistantResponse: String) async throws -> String {
        let client = try await ensureFreshClient()
        
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

struct ProcessedResponse {
    let text: String
    let imageURL: URL?
    let isImageGeneration: Bool
}

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
