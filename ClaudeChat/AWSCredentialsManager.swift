//
//  AWSCredentialsManager.swift
//  ClaudeChat
//
//  Created by Amazon Q on 7/5/25.
//

import Foundation

struct AWSCredentials {
    let accessKeyId: String
    let secretAccessKey: String
    let sessionToken: String?
    let region: String
}

class AWSCredentialsManager {
    static let shared = AWSCredentialsManager()
    
    private init() {}
    
    func loadCredentials(profile: String = "default") -> AWSCredentials? {
        // Try multiple paths to find AWS credentials
        let possiblePaths = [
            // Standard AWS credentials path
            NSString(string: "~/.aws/credentials").expandingTildeInPath,
            // Container path (for sandboxed apps)
            NSHomeDirectory() + "/.aws/credentials",
            // Alternative container paths
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".aws/credentials").path,
            // Check if we can access the real home directory
            "/Users/\(NSUserName())/.aws/credentials"
        ]
        
        let possibleConfigPaths = [
            NSString(string: "~/.aws/config").expandingTildeInPath,
            NSHomeDirectory() + "/.aws/config",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".aws/config").path,
            "/Users/\(NSUserName())/.aws/config"
        ]
        
        var credentialsContent: String?
        var credentialsPath: String?
        
        // Try to find and read credentials file
        for path in possiblePaths {
            print("Trying credentials path: \(path)")
            if FileManager.default.fileExists(atPath: path) {
                do {
                    credentialsContent = try String(contentsOfFile: path)
                    credentialsPath = path
                    print("✅ Successfully read credentials from: \(path)")
                    break
                } catch {
                    print("❌ Could not read credentials file at \(path): \(error)")
                }
            } else {
                print("❌ Credentials file does not exist at: \(path)")
            }
        }
        
        guard let credentials = credentialsContent else {
            print("❌ Could not find AWS credentials file in any of the expected locations")
            print("Expected locations:")
            for path in possiblePaths {
                print("  - \(path)")
            }
            return nil
        }
        
        // Try to find and read config file
        var configContent: String?
        for path in possibleConfigPaths {
            if FileManager.default.fileExists(atPath: path) {
                do {
                    configContent = try String(contentsOfFile: path)
                    print("✅ Successfully read config from: \(path)")
                    break
                } catch {
                    print("⚠️ Could not read config file at \(path): \(error)")
                }
            }
        }
        
        return parseCredentials(
            credentialsContent: credentials,
            configContent: configContent,
            profile: profile
        )
    }
    
    private func parseCredentials(credentialsContent: String, configContent: String?, profile: String) -> AWSCredentials? {
        let credentialsLines = credentialsContent.components(separatedBy: .newlines)
        let configLines = configContent?.components(separatedBy: .newlines) ?? []
        
        var accessKeyId: String?
        var secretAccessKey: String?
        var sessionToken: String?
        var region: String = "us-east-1" // Default region
        
        // Parse credentials file
        var inTargetProfile = false
        let profileHeader = "[\(profile)]"
        
        for line in credentialsLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                inTargetProfile = (trimmedLine == profileHeader)
                continue
            }
            
            if inTargetProfile {
                if trimmedLine.hasPrefix("aws_access_key_id") {
                    accessKeyId = extractValue(from: trimmedLine)
                } else if trimmedLine.hasPrefix("aws_secret_access_key") {
                    secretAccessKey = extractValue(from: trimmedLine)
                } else if trimmedLine.hasPrefix("aws_session_token") {
                    sessionToken = extractValue(from: trimmedLine)
                } else if trimmedLine.hasPrefix("region") {
                    region = extractValue(from: trimmedLine) ?? region
                }
            }
        }
        
        // Parse config file for region if not found in credentials
        inTargetProfile = false
        let configProfileHeader = profile == "default" ? "[default]" : "[profile \(profile)]"
        
        for line in configLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                inTargetProfile = (trimmedLine == configProfileHeader)
                continue
            }
            
            if inTargetProfile && trimmedLine.hasPrefix("region") {
                region = extractValue(from: trimmedLine) ?? region
            }
        }
        
        guard let accessKey = accessKeyId, let secretKey = secretAccessKey else {
            print("❌ Missing required AWS credentials (access_key_id or secret_access_key)")
            print("Found access_key_id: \(accessKeyId != nil ? "✅" : "❌")")
            print("Found secret_access_key: \(secretAccessKey != nil ? "✅" : "❌")")
            return nil
        }
        
        print("✅ Successfully parsed AWS credentials")
        print("Profile: \(profile)")
        print("Region: \(region)")
        print("Access Key ID: \(accessKey.prefix(8))...")
        print("Session Token: \(sessionToken != nil ? "✅ Present" : "❌ Not present")")
        
        return AWSCredentials(
            accessKeyId: accessKey,
            secretAccessKey: secretKey,
            sessionToken: sessionToken,
            region: region
        )
    }
    
    private func extractValue(from line: String) -> String? {
        let components = line.components(separatedBy: "=")
        guard components.count >= 2 else { return nil }
        
        let value = components[1...].joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
