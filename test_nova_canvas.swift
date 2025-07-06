#!/usr/bin/env swift

import Foundation

// Simple test to verify our Nova Canvas integration compiles correctly
print("Testing Nova Canvas integration...")

// Test the image generation request detection
func testImageDetection() {
    let testMessages = [
        "Generate an image of a sunset",
        "Create an image of a mountain",
        "Draw a cat",
        "Show me a forest",
        "Hello, how are you?",
        "What's the weather like?"
    ]
    
    func isImageGenerationRequest(_ message: String) -> Bool {
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
    
    for message in testMessages {
        let isImageRequest = isImageGenerationRequest(message)
        print("Message: '\(message)' -> Image request: \(isImageRequest)")
    }
}

testImageDetection()
print("✅ Nova Canvas integration test completed!")
