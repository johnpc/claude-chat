# ClaudeChat

A macOS chat application for interacting with Claude-4-Sonnet using AWS Bedrock and credentials from `~/.aws/credentials`.

## Quick Start - Download Pre-built App

The easiest way to get started is to download the pre-built app:

1. **Download**: Go to the [Releases page](https://github.com/johnpc/claude-chat/releases) and download the latest `ClaudeChat.app.zip`
2. **Install**: Unzip and move `ClaudeChat.app` to your `/Applications` folder
3. **Remove Quarantine**: Run this command in Terminal to prevent macOS quarantine issues:
   ```bash
   xattr -dr com.apple.quarantine /Applications/ClaudeChat.app
   ```
4. **Launch**: Open ClaudeChat from your Applications folder. Grant Accessibility permissions to enable quick chat (cmd+shift+a)

After launching, you'll need to configure your AWS credentials (see [AWS Setup](#aws-setup) below).

## Features

- **Chat Interface**: Clean, modern chat interface with conversation management
- **AWS Integration**: Uses AWS Bedrock to access Claude-4-Sonnet model
- **Credential Management**: Automatically reads AWS credentials from `~/.aws/credentials`
- **Conversation History**: Persistent conversation storage using SwiftData
- **Multiple Conversations**: Create and manage multiple chat conversations
- **Real-time Messaging**: Async messaging with loading indicators

## Prerequisites

1. **AWS Account**: You need an AWS account with access to Amazon Bedrock
2. **Claude Model Access**: Ensure you have access to the Claude-4-Sonnet model in AWS Bedrock
3. **AWS Credentials**: Configure your AWS credentials in `~/.aws/credentials`
4. **macOS**: This is a macOS-only application

## AWS Setup

### 1. Configure AWS Credentials

Create or update your `~/.aws/credentials` file:

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
region = us-east-1
```

If you're using temporary credentials (e.g., from AWS SSO), include the session token:

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
aws_session_token = YOUR_SESSION_TOKEN
region = us-east-1
```

### 2. AWS Bedrock Model Access

Ensure you have access to the Claude-4-Sonnet model in AWS Bedrock:

1. Go to the AWS Bedrock console
2. Navigate to "Model access" in the left sidebar
3. Request access to "Anthropic Claude 3.5 Sonnet" if not already enabled
4. Wait for approval (this can take some time)

### 3. IAM Permissions

Your AWS credentials need the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel"
            ],
            "Resource": "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0"
        }
    ]
}
```

## Building and Running

### Using Xcode

1. Open `ClaudeChat.xcodeproj` in Xcode
2. Select your development team in the project settings
3. Build and run the project (⌘+R)

### Using Command Line

```bash
# Build the project
xcodebuild -scheme ClaudeChat -destination 'platform=macOS' build

# Run the built app
open /Users/$(whoami)/Library/Developer/Xcode/DerivedData/ClaudeChat-*/Build/Products/Debug/ClaudeChat.app
```

## Usage

1. **Launch the App**: Open ClaudeChat from Xcode or the built application
2. **Test Credentials**: Click "Test AWS Credentials" to verify your setup
3. **Start Chatting**:
   - Click "New Conversation" to create a new chat
   - Type your message in the text field at the bottom
   - Press Enter or click the send button
4. **Manage Conversations**:
   - View all conversations in the left sidebar
   - Delete conversations by selecting them and using the delete key
   - Conversations are automatically titled based on the first message

## Architecture

The app is built using:

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Core Data successor for data persistence
- **AWS Bedrock**: Amazon's managed AI service
- **Claude-4-Sonnet**: Anthropic's advanced language model

### Key Components

- `ClaudeService`: Handles AWS Bedrock API calls and authentication
- `AWSCredentialsManager`: Reads and parses AWS credentials from files
- `ChatView`: Main chat interface with message bubbles
- `ContentView`: Conversation list and navigation
- `ChatMessage` & `Conversation`: SwiftData models for persistence

## Troubleshooting

### Common Issues

1. **"AWS credentials not found"**
   - Verify `~/.aws/credentials` file exists and is properly formatted
   - Check file permissions (should be readable by your user)

2. **"API Error (403): Access Denied"**
   - Ensure you have requested access to Claude models in AWS Bedrock
   - Verify your IAM permissions include `bedrock:InvokeModel`

3. **"Invalid response from Claude API"**
   - Check your AWS region supports Bedrock
   - Verify the model ID is correct for your region

4. **Network connectivity issues**
   - Ensure the app has network permissions (check entitlements)
   - Verify you can reach AWS Bedrock endpoints from your network

### Debug Mode

The app includes console logging for debugging. Check the Xcode console for detailed error messages when issues occur.

## Security Considerations

- AWS credentials are read from local files only
- No credentials are stored within the app
- All communication with AWS uses HTTPS
- The app runs in a sandboxed environment with minimal permissions

## Contributing

This is a sample application demonstrating AWS Bedrock integration with SwiftUI. Feel free to fork and modify for your needs.

## License

This project is provided as-is for educational and demonstration purposes.
