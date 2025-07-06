# AudioPal - Speech-to-Text iOS App


## Features

- **Real-time Speech Recognition**: On-device transcription using Apple's Speech framework
- **Whisper API Integration**: Optional cloud-based transcription for improved accuracy
- **Background Recording**: Unlimited duration recording even when app is in background
- **Conversation Management**: Save and organize transcription sessions
- **Audio Route Handling**: Automatic detection and handling of audio device changes
- **Network Queue Management**: Intelligent queuing and retry logic for API calls
- **Performance Monitoring**: Real-time battery, memory, and CPU usage tracking
- **iOS Widget**: Quick access to recording controls from home screen
- **Haptic Feedback**: Tactile feedback for better user experience

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- OpenAI API key (optional, for Whisper API)

# Install the repo
   ```
1. Configuration of the widget is optional since it is not fully functioal
2. You can set your whisper api key in settings otherwise it falls back to local transcription.



The app follows the MVVM (Model-View-ViewModel) pattern with clear separation of concerns:

- **ViewModels**: Handle business logic and state management
- **Managers**: Encapsulate system-level functionality
- **Models**: Define data structures
- **Views**: Present UI and handle user interactions

## Permissions

The app requires the following permissions:

- **Microphone**: For audio recording
- **Speech Recognition**: For on-device transcription

These are requested automatically when you first use the recording feature. If denied it shows users a
message on how to enable them.


