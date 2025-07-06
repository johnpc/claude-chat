//
//  NovaCanvasService.swift
//  ClaudeChat
//
//  Created by Amazon Q on 7/6/25.
//

import Foundation
import SwiftUI
import AWSBedrockRuntime
import AWSClientRuntime
import AWSSDKIdentity

class NovaCanvasService: ObservableObject {
    static let shared = NovaCanvasService()
    
    private let credentialsManager = AWSCredentialsManager.shared
    private let modelId = "amazon.nova-canvas-v1:0"
    private var bedrockClient: BedrockRuntimeClient?
    private var lastCredentialsCheck: Date = Date.distantPast
    private let credentialsRefreshInterval: TimeInterval = 300 // 5 minutes
    
    init() {
        // Don't setup client immediately - do it on first use
    }
    
    private func ensureFreshClient() async throws -> BedrockRuntimeClient {
        let now = Date()
        
        // Check if we need to refresh credentials (every 5 minutes or if no client exists)
        if bedrockClient == nil || now.timeIntervalSince(lastCredentialsCheck) > credentialsRefreshInterval {
            print("🔄 Refreshing AWS credentials for Nova Canvas...")
            
            guard let credentials = credentialsManager.loadCredentials() else {
                print("❌ Failed to load AWS credentials for Nova Canvas")
                throw NovaCanvasError.credentialsNotFound
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
                
                print("✅ AWS Bedrock client for Nova Canvas refreshed successfully")
            } catch {
                print("❌ Failed to refresh AWS Bedrock client for Nova Canvas: \(error)")
                throw NovaCanvasError.apiError("Failed to refresh AWS client: \(error.localizedDescription)")
            }
        }
        
        guard let client = bedrockClient else {
            throw NovaCanvasError.credentialsNotFound
        }
        
        return client
    }
    
    func generateImage(prompt: String, negativePrompt: String? = nil, width: Int = 1024, height: Int = 1024, cfgScale: Double = 6.5, seed: Int? = nil) async throws -> Data {
        let client = try await ensureFreshClient()
        
        // Create the request payload for Nova Canvas
        let requestPayload = NovaCanvasRequest(
            taskType: "TEXT_IMAGE",
            textToImageParams: TextToImageParams(
                text: prompt,
                negativeText: negativePrompt,
                images: nil
            ),
            imageGenerationConfig: ImageGenerationConfig(
                numberOfImages: 1,
                quality: "standard",
                height: height,
                width: width,
                cfgScale: cfgScale,
                seed: seed
            )
        )
        
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
                throw NovaCanvasError.invalidResponse
            }
            
            let novaResponse = try JSONDecoder().decode(NovaCanvasResponse.self, from: responseBody)
            
            guard let firstImage = novaResponse.images.first,
                  let imageData = Data(base64Encoded: firstImage) else {
                throw NovaCanvasError.invalidResponse
            }
            
            return imageData
        } catch {
            print("AWS Bedrock Nova Canvas Error: \(error)")
            
            // If we get an authentication error, try refreshing credentials once more
            if error.localizedDescription.contains("403") || 
               error.localizedDescription.contains("Forbidden") ||
               error.localizedDescription.contains("expired") ||
               error.localizedDescription.contains("invalid") {
                print("🔄 Authentication error detected for Nova Canvas, forcing credential refresh...")
                
                // Force refresh by resetting the client and timestamp
                bedrockClient = nil
                lastCredentialsCheck = Date.distantPast
                
                // Try once more with fresh credentials
                let freshClient = try await ensureFreshClient()
                let retryResponse = try await freshClient.invokeModel(input: request)
                
                guard let retryResponseBody = retryResponse.body else {
                    throw NovaCanvasError.invalidResponse
                }
                
                let retryNovaResponse = try JSONDecoder().decode(NovaCanvasResponse.self, from: retryResponseBody)
                
                guard let retryFirstImage = retryNovaResponse.images.first,
                      let retryImageData = Data(base64Encoded: retryFirstImage) else {
                    throw NovaCanvasError.invalidResponse
                }
                
                return retryImageData
            }
            
            throw NovaCanvasError.apiError(error.localizedDescription)
        }
    }
    
    func saveImageToDocuments(_ imageData: Data, filename: String = "generated_image") -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imageURL = documentsPath.appendingPathComponent("\(filename)_\(UUID().uuidString).png")
        
        do {
            try imageData.write(to: imageURL)
            return imageURL
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
}

// MARK: - Data Models

struct NovaCanvasRequest: Codable {
    let taskType: String
    let textToImageParams: TextToImageParams
    let imageGenerationConfig: ImageGenerationConfig
}

struct TextToImageParams: Codable {
    let text: String
    let negativeText: String?
    let images: [String]?
}

struct ImageGenerationConfig: Codable {
    let numberOfImages: Int
    let quality: String
    let height: Int
    let width: Int
    let cfgScale: Double
    let seed: Int?
}

struct NovaCanvasResponse: Codable {
    let images: [String]
    let error: String?
}

enum NovaCanvasError: Error, LocalizedError {
    case credentialsNotFound
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            return "AWS credentials not found"
        case .invalidResponse:
            return "Invalid response from Nova Canvas API"
        case .apiError(let message):
            return "Nova Canvas API Error: \(message)"
        }
    }
}
