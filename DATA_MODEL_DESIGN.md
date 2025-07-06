# Data Model Design

## Overview


```swift
struct Message: Identifiable, Codable {
    let id: UUID
    var content: String
    let isUser: Bool
    let isThinking: Bool
    let isError: Bool
    var audioURL: URL?
    var recordingDuration: TimeInterval?
    var transcriptionMethod: TranscriptionMethod?
    
    enum TranscriptionMethod: String, Codable, CaseIterable {
        case whisper = "Whisper API"
        case local = "Local"
        
        var icon: String {
            switch self {
            case .whisper: return "sparkles"
            case .local: return "iphone"
            }
        }
        
        var color: Color {
            switch self {
            case .whisper: return .orange
            case .local: return .blue
            }
        }
    }
}
```

**Design Decisions**:

1. **UUID for ID**: Ensures uniqueness across devices and sessions
2. **Optional Properties**: Flexible model for different message types
3. **TranscriptionMethod Enum**: Type-safe transcription source tracking
4. **Codable Conformance**: Enables JSON serialization and persistence

### Conversation Model

```swift
struct Conversation: Identifiable, Codable {
    let id: UUID
    let title: String
    let messages: [Message]
    let date: Date
    
    init(title: String, messages: [Message], date: Date) {
        self.id = UUID()
        self.title = title
        self.messages = messages
        self.date = date
    }
}
```

**Design Decisions**:

1. **Immutable Properties**: Ensures data integrity
2. **Automatic ID Generation**: Simplifies creation
3. **Date Tracking**: Enables chronological organization
4. **Message Array**: Direct relationship to messages

### Supporting Models

#### Audio Quality Settings

```swift
struct AudioQualitySettings {
    let sampleRate: Double
    let bitRate: Int32
    let channels: Int
    let format: String
    
    static let low = AudioQualitySettings(sampleRate: 16000, bitRate: 32000, channels: 1, format: "m4a")
    static let medium = AudioQualitySettings(sampleRate: 22050, bitRate: 64000, channels: 1, format: "m4a")
    static let high = AudioQualitySettings(sampleRate: 44100, bitRate: 128000, channels: 1, format: "m4a")
}
```

#### Queue Status

```swift
enum QueueStatus: Equatable {
    case idle
    case queued(count: Int)
    case processing(count: Int)
    case offline
    
    var description: String {
        switch self {
        case .idle: return "Ready"
        case .queued(let count): return "Queued (\(count))"
        case .processing(let count): return "Processing (\(count))"
        case .offline: return "Offline"
        }
    }
}
```

#### Pending Transcription

```swift
struct PendingTranscription: Identifiable {
    let id: UUID
    let audioFileURL: URL
    let originalText: String
    let duration: TimeInterval
    let timestamp: Date
    var retryCount: Int = 0
}
```

## Data Persistence Strategy

### Storage Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DeviceManager                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ UserDefaults    │  │ FileManager     │  │ Keychain    │ │
│  │   (Settings)    │  │  (Audio Files)  │  │ (API Keys)  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Persistence Implementation

```swift
class DeviceManager {
    static let shared = DeviceManager()
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    
    func saveChatHistory(_ conversations: [Conversation]) {
        do {
            let data = try JSONEncoder().encode(conversations)
            userDefaults.set(data, forKey: "chatHistory")
        } catch {
            print("❌ Failed to save chat history: \(error)")
        }
    }
    
    func loadChatHistory() -> [Conversation]? {
        guard let data = userDefaults.data(forKey: "chatHistory") else { return nil }
        
        do {
            return try JSONDecoder().decode([Conversation].self, from: data)
        } catch {
            print("❌ Failed to load chat history: \(error)")
            return nil
        }
    }
}
```

### Data Flow

1. **Creation**: Messages created in memory
2. **Caching**: Data cached in UserDefaults
3. **Persistence**: Periodic saves to prevent data loss
4. **Loading**: Data loaded on app startup

## Performance Optimizations

### Memory Management

#### 1. Lazy Loading

```swift
LazyVStack(spacing: 12) {
    ForEach(viewModel.messages) { message in
        MessageBubble(message: message, viewModel: viewModel)
            .id(message.id)
    }
}
```

**Benefits**:
- Only renders visible messages
- Reduces memory usage for large conversations
- Improves scrolling performance

#### 2. Debounced Saving

```swift
private func scheduleSave() {
    saveTimer?.invalidate()
    
    saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
        guard let self = self, self.hasUnsavedChanges else { return }
        self.persistChatHistory()
        self.hasUnsavedChanges = false
    }
}
```

**Benefits**:
- Reduces I/O operations
- Prevents excessive disk writes
- Maintains data integrity

#### 3. Efficient Data Structures

```swift
// Use arrays for ordered data
@Published var messages: [Message] = []

// Use dictionaries for fast lookups
private var pendingTranscriptions: [PendingTranscription] = []

// Use enums for type safety
enum TranscriptionMethod: String, Codable {
    case whisper = "Whisper API"
    case local = "Local"
}
```

### Network Optimization

#### 1. Request Queuing

```swift
private let transcriptionQueue = DispatchQueue(
    label: "com.audiopal.transcription", 
    qos: .userInitiated, 
    attributes: .concurrent
)
```

**Benefits**:
- Prevents network overload
- Enables retry logic
- Maintains request order

#### 2. Concurrent Processing

```swift
private let maxConcurrentRequests: Int = 3
private var activeTranscriptionCount: Int = 0
```

**Benefits**:
- Limits resource usage
- Prevents API rate limiting
- Maintains responsiveness

### File Management

#### 1. Temporary File Cleanup

```swift
func cleanupAudioFiles() {
    let tempDirectory = FileManager.default.temporaryDirectory
    let audioFiles = try? FileManager.default.contentsOfDirectory(
        at: tempDirectory,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "m4a" }
    
    audioFiles?.forEach { url in
        try? FileManager.default.removeItem(at: url)
    }
}
```

**Benefits**:
- Prevents disk space issues
- Maintains system performance
- Automatic cleanup

#### 2. Efficient File Operations

```swift
func startRecording(audioQuality: AudioQuality) -> URL? {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("m4a")
    
    // Configure audio settings for optimal performance
    let settings = audioQuality.settings
    // ... recording setup
}
```

## Data Integrity

### Validation

#### 1. Input Validation

```swift
func createMessageWithText(_ text: String, duration: TimeInterval, usedWhisper: Bool) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        print("⚠️ Empty message text")
        return
    }
    
    let transcriptionMethod: Message.TranscriptionMethod = usedWhisper ? .whisper : .local
    // ... message creation
}
```

#### 2. State Validation

```swift
func canStartRecording() -> Bool {
    let hasMicrophonePermission = audioManager.hasMicrophonePermission()
    let hasSpeechPermission = speechRecognitionManager.hasSpeechRecognitionPermission()
    
    return hasMicrophonePermission && hasSpeechPermission
}
```

### Error Handling

#### 1. Graceful Degradation

```swift
func transcribeAudioWithWhisper(audioFileURL: URL, completion: @escaping (String?) -> Void) {
    guard hasValidOpenAIKey, let apiKey = openAIKey else {
        completion(nil) // Fall back to local transcription
        return
    }
    // ... API call
}
```

#### 2. Recovery Mechanisms

```swift
private func handleWhisperFailure(completion: @escaping (String?) -> Void) {
    whisperRetryCount += 1
    
    if whisperRetryCount >= maxWhisperRetries {
        print("❌ Whisper API failed - falling back to local transcription")
        completion(nil) // Signal to use local transcription
    } else {
        // Retry with exponential backoff
        let delay = pow(2.0, Double(whisperRetryCount - 1))
        // ... retry logic
    }
}
```

## Scalability Considerations

### Data Growth

#### 1. Conversation Management

```swift
func startNewConversation() {
    if !messages.isEmpty {
        updateCurrentConversation() // Save current conversation
    }
    
    messages = [] // Start fresh
    currentConversationIndex = -1
}
```

#### 2. Memory Monitoring

```swift
private func getMemoryUsage() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    return kerr == KERN_SUCCESS ? info.resident_size : 0
}
```

