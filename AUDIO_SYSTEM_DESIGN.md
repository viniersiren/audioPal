# Audio System Design

## Overview

The AudioPal audio system is designed to handle complex audio scenarios including recording, playback, background processing, and seamless audio route changes. The system provides a robust foundation for speech-to-text applications with minimal user interruption.

## Audio Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    AudioManager                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ Audio Session   │  │ Route Monitoring│  │ Interruption│ │
│  │   Management    │  │     System      │  │   Handling  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 RecordingManager                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ Audio Recording │  │ File Management │  │ Quality     │ │
│  │     Engine      │  │     System      │  │ Control     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              SpeechRecognitionManager                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ Speech Engine   │  │ Buffer Handling │  │ Recognition │ │
│  │   Integration   │  │     System      │  │   Pipeline  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Audio Session Management

### Session Configuration

The audio session is configured to support multiple use cases:

```swift
func setupAudioSession() {
    do {
        let audioSession = AVAudioSession.sharedInstance()
        
        // Configure for recording and playback
        try audioSession.setCategory(.playAndRecord, 
                                   mode: .default, 
                                   options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
        print("❌ Failed to setup audio session: \(error)")
    }
}
```

1. **Initialization**: Configure session when app starts
2. **Activation**: Activate session before recording begins
3. **Deactivation**: Deactivate session when recording stops
4. **Cleanup**: Proper cleanup in deinit methods

## Audio Route Handling

### Route Change Detection

The system monitors audio route changes in real-time:

```swift
private func setupAudioRouteMonitoring() {
    audioRouteObserver = NotificationCenter.default.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: nil,
        queue: nil
    ) { [weak self] notification in
        // Handle route changes
    }
}
```

### Route Change Scenarios
Handles route changing such as disconnection or connection of new devices.

### Route Information Display

The system provides real-time route information:

```swift
private func getCurrentAudioRoute() -> String {
    let audioSession = AVAudioSession.sharedInstance()
    let outputs = audioSession.currentRoute.outputs
    
    if let output = outputs.first {
        switch output.portType {
        case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
            return "Bluetooth (\(output.portName))"
        case .headphones:
            return "Wired Headphones"
        case .builtInSpeaker:
            return "Built-in Speaker"
        case .builtInReceiver:
            return "Built-in Receiver"
        default:
            return output.portName
        }
    }
    return "Unknown"
}
```

## Audio Interruption Handling

### Interruption Types

The system handles various audio interruption scenarios such as siri, or phone calls where it continues recording.
For other audio conflicts like other recording apps it stops recording.

### Interruption Response

```swift
private func setupAudioInterruptionMonitoring() {
    audioInterruptionObserver = NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: nil,
        queue: nil
    ) { [weak self] notification in
        if let userInfo = notification.userInfo,
           let reasonValue = userInfo[AVAudioSessionInterruptionReasonKey] as? NSNumber {
            
            let reason = reasonValue.uintValue
            switch reason {
            case 1: // Interruption began
                self?.handleInterruptionBegan()
            case 0: // Interruption ended
                self?.handleInterruptionEnded()
            default:
                print("🎧 Unknown audio interruption reason: \(reason)")
            }
        }
    }
}
```

### Interruption Recovery

1. **Automatic Recovery**: Attempt to resume recording automatically
2. **User Notification**: Inform user of interruption status
3. **State Preservation**: Maintain recording state during interruption
4. **Graceful Degradation**: Continue with available audio sources

## Background Audio Processing

### Background Recording Capabilities

The app supports unlimited background recording:

```swift
@objc private func appDidEnterBackground() {
    print("📱 App entered background")
    if isRecording {
        print("🎤 Recording continues in background (unlimited duration)")
    }
}
```

### Background Audio Session

- **Audio Session**: Configured for background operation
- **File Management**: Continuous audio file writing
- **Memory Management**: Efficient buffer handling
- **Battery Optimization**: Minimize power consumption

### Background Task Management

```swift
private func setupBackgroundNotifications() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(appDidEnterBackground),
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
    )
    
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(appWillEnterForeground),
        name: UIApplication.willEnterForegroundNotification,
        object: nil
    )
}
```

## Audio Quality Management

### Quality Settings

The system supports multiple audio quality levels:

```swift
enum AudioQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var settings: AudioQualitySettings {
        switch self {
        case .low:
            return AudioQualitySettings(sampleRate: 16000, bitRate: 32000)
        case .medium:
            return AudioQualitySettings(sampleRate: 22050, bitRate: 64000)
        case .high:
            return AudioQualitySettings(sampleRate: 44100, bitRate: 128000)
        }
    }
}
```

### Quality Selection Criteria

- **Low Quality**: Faster processing, smaller files, basic transcription
- **Medium Quality**: Balanced performance and accuracy
- **High Quality**: Best accuracy, larger files, slower processing


## Future Enhancements

### Planned Improvements

1. **Advanced Audio Processing**: Implement noise reduction
2. **Audio Effects**: Add audio enhancement features


