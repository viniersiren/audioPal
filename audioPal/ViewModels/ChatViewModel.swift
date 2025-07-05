import Foundation
import SwiftUI
import AVFoundation
import Speech
import UIKit
import Network

enum QueueStatus {
    case idle
    case processing(count: Int)
    case queued(count: Int)
    case offline
    
    var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .processing(let count):
            return "Processing \(count) segments"
        case .queued(let count):
            return "\(count) segments queued"
        case .offline:
            return "Offline - segments queued"
        }
    }
}

class ChatViewModel: NSObject, ObservableObject {
    @Published var messages: [Message] = []
    @Published var isRecording: Bool = false
    @Published var isThinking: Bool = false
    @Published var isProcessingSegment: Bool = false
    @Published var speechRecognizer: SFSpeechRecognizer?
    @Published var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @Published var recognitionTask: SFSpeechRecognitionTask?
    @Published var audioEngine: AVAudioEngine?
    @Published var inputText: String = ""
    @Published var error: ChatError?
    @Published var audioLevel: Float = 0.0
    @Published var conversations: [Conversation] = []
    @Published var currentConversationIndex: Int = -1
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()
    @Published var queueStatus: QueueStatus = .idle
    @Published var currentAudioRoute: String = "Unknown"
    private var audioLevelTimer: Timer?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var hasUnsavedChanges: Bool = false
    private var saveTimer: Timer?
    
    // Auto-segmentation
    private let segmentDuration: TimeInterval = 30.0 // 30 seconds
    private var currentSegmentText: String = ""
    private var segmentStartTime: Date?
    private var lastProcessedTextLength: Int = 0 // Track processed text length
    
    // Audio recording for Whisper API
    private var audioRecorder: AVAudioRecorder?
    private var currentAudioFileURL: URL?
    private var whisperRetryCount: Int = 0
    private let maxWhisperRetries: Int = 5
    private var retryAudioFileURL: URL? // Store audio file for retries
    
    // Concurrent processing and offline queuing
    private let transcriptionQueue = DispatchQueue(label: "com.audiopal.transcription", qos: .userInitiated, attributes: .concurrent)
    private var pendingTranscriptions: [PendingTranscription] = []
    private var isProcessingQueue: Bool = false
    private let maxConcurrentRequests: Int = 3
    private var activeTranscriptionCount: Int = 0
    
    // Network monitoring
    private var isNetworkAvailable: Bool = true
    private var networkMonitor: NWPathMonitor?
    private let networkQueue = DispatchQueue(label: "com.audiopal.network")
    
    // Audio route monitoring
    private var audioRouteObserver: NSObjectProtocol?
    
    // Audio interruption monitoring
    private var audioInterruptionObserver: NSObjectProtocol?
    
    struct PendingTranscription {
        let id: UUID
        let audioFileURL: URL
        let originalText: String
        let duration: TimeInterval
        let timestamp: Date
        var retryCount: Int = 0
    }
    
    // Performance monitoring
    private var performanceTimer: Timer?
    private var cpuUsageStartTime: Date?
    private var memoryUsageStartValue: UInt64 = 0
    private var batteryLevelStart: Float = 0.0
    private var batteryMonitoringStartTime: Date?
    
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private var tickSound: AVAudioPlayer?
    
    // MARK: - Configuration
    var openAIKey: String? {
        return KeychainManager.shared.getOpenAIKey()
    }
    
    var hasValidOpenAIKey: Bool {
        guard let key = openAIKey else { return false }
        return !key.isEmpty && key != "YOUR_OPENAI_KEY"
    }
    
    var networkStatusDescription: String {
        if !isNetworkAvailable {
            return "Offline - using local transcription"
        } else if !hasValidOpenAIKey {
            return "No API key - using local transcription"
        } else {
            return "Online - using Whisper API"
        }
    }
    
    var queueStatusDescription: String {
        switch queueStatus {
        case .idle:
            return networkStatusDescription
        case .processing(let count):
            return "Processing \(count) segments..."
        case .queued(let count):
            return "\(count) segments queued"
        case .offline:
            return "Offline - segments queued"
        }
    }
    
    // MARK: - Audio Quality Settings
    @Published var audioQuality: AudioQuality = .high
    
    enum AudioQuality: String, CaseIterable {
        case low = "Low"
        case medium = "Medium" 
        case high = "High"
        case ultra = "Ultra"
        
        var settings: [String: Any] {
            switch self {
            case .low:
                return [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 22050,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue,
                    AVEncoderBitRateKey: 32000
                ]
            case .medium:
                return [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
                    AVEncoderBitRateKey: 64000
                ]
            case .high:
                return [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                    AVEncoderBitRateKey: 128000
                ]
            case .ultra:
                return [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 48000,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
                    AVEncoderBitRateKey: 256000
                ]
            }
        }
        
        var description: String {
            switch self {
            case .low:
                return "22kHz, 32kbps - Small files, basic quality"
            case .medium:
                return "44kHz, 64kbps - Balanced quality and size"
            case .high:
                return "44kHz, 128kbps - High quality (default)"
            case .ultra:
                return "48kHz, 256kbps - Maximum quality, large files"
            }
        }
        
        var estimatedFileSize: String {
            switch self {
            case .low:
                return "~200KB per 30s"
            case .medium:
                return "~400KB per 30s"
            case .high:
                return "~800KB per 30s"
            case .ultra:
                return "~1.6MB per 30s"
            }
        }
    }
    
    func saveOpenAIKey(_ key: String) -> Bool {
        let success = KeychainManager.shared.saveOpenAIKey(key)
        if success {
            print("✅ OpenAI API key saved to Keychain")
        } else {
            print("❌ Failed to save OpenAI API key to Keychain")
        }
        return success
    }
    
    func saveAudioQuality(_ quality: AudioQuality) {
        UserDefaults.standard.set(quality.rawValue, forKey: "audioQuality")
        audioQuality = quality
        print("✅ Audio quality saved: \(quality.rawValue)")
    }
    
    func loadAudioQuality() {
        if let savedQuality = UserDefaults.standard.string(forKey: "audioQuality"),
           let quality = AudioQuality(rawValue: savedQuality) {
            audioQuality = quality
            print("✅ Audio quality loaded: \(quality.rawValue)")
        } else {
            audioQuality = .high // Default
            print("✅ Using default audio quality: High")
        }
    }
    
    // MARK: - Whisper API Transcription
    func transcribeAudioWithWhisper(audioFileURL: URL, completion: @escaping (String?) -> Void) {
        guard hasValidOpenAIKey, let apiKey = openAIKey else {
            completion(nil)
            return
        }
        
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        
        do {
            let audioData = try Data(contentsOf: audioFileURL)
            body.append(audioData)
        } catch {
            print("❌ Failed to read audio file: \(error)")
            completion(nil)
            return
        }
        
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🎤 Sending audio to Whisper API (attempt \(whisperRetryCount + 1)/\(maxWhisperRetries))")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Whisper API error: \(error)")
                self.handleWhisperFailure(completion: completion)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Success - reset retry count
                    self.whisperRetryCount = 0
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data ?? Data()) as? [String: Any],
                           let text = json["text"] as? String {
                            print("✅ Whisper transcription successful")
                            completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        } else {
                            print("❌ Unexpected Whisper response format")
                            completion(nil)
                    }
                } catch {
                        print("❌ Failed to parse Whisper response: \(error)")
                        completion(nil)
                    }
                } else {
                    print("❌ Whisper API HTTP error: \(httpResponse.statusCode)")
                    self.handleWhisperFailure(completion: completion)
                }
            } else {
                print("❌ No HTTP response from Whisper API")
                self.handleWhisperFailure(completion: completion)
            }
        }.resume()
    }
    
    private func handleWhisperFailure(completion: @escaping (String?) -> Void) {
        whisperRetryCount += 1
        
        if whisperRetryCount >= maxWhisperRetries {
            print("❌ Whisper API failed \(maxWhisperRetries) times - falling back to local transcription")
            whisperRetryCount = 0
            retryAudioFileURL = nil // Clean up
            completion(nil) // Signal to use local transcription
        } else {
            // Exponential backoff: 1s, 2s, 4s, 8s, 16s
            let delay = pow(2.0, Double(whisperRetryCount - 1))
            print("⏳ Retrying Whisper API in \(delay) seconds...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, let audioFileURL = self.retryAudioFileURL else {
                    print("❌ No audio file available for retry")
                    completion(nil)
                    return
                }
                
                // Retry the Whisper API call
                self.transcribeAudioWithWhisper(audioFileURL: audioFileURL, completion: completion)
            }
        }
    }
    
    private func addFailedTranscriptionToQueue(audioFileURL: URL, originalText: String, duration: TimeInterval, retryCount: Int) {
        var pending = PendingTranscription(
            id: UUID(),
            audioFileURL: audioFileURL,
            originalText: originalText,
            duration: duration,
            timestamp: Date()
        )
        pending.retryCount = retryCount
        
        // Add to front of queue for immediate retry
        pendingTranscriptions.insert(pending, at: 0)
        print("🔄 Added failed transcription back to queue for retry (attempt \(retryCount + 1))")
    }
    
    override init() {
        super.init()
        print("ChatViewModel initialized for speech-to-text")
        
        // Initialize the feedback generators
        impactGenerator.prepare()
        selectionGenerator.prepare()
        
        // Setup tick sound
        if let soundURL = Bundle.main.url(forResource: "tick", withExtension: "mp3") {
            do {
                tickSound = try AVAudioPlayer(contentsOf: soundURL)
                tickSound?.volume = 0.4
                tickSound?.prepareToPlay()
                print("✅ Tick sound loaded successfully")
            } catch {
                print("❌ Failed to load tick sound: \(error)")
            }
        } else {
            print("❌ Could not find tick.mp3 in bundle")
        }
        
        // Initialize speech recognition
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        // Load persisted chat history
        loadPersistedChatHistory()
        
        // Load audio quality settings
        loadAudioQuality()
        
        // Setup network monitoring
        setupNetworkMonitoring()
        
        // Setup audio route monitoring
        setupAudioRouteMonitoring()
        
        // Setup audio interruption monitoring
        setupAudioInterruptionMonitoring()
        
        // Initialize audio route display
        updateAudioRouteDisplay()
        
        // Start with an empty conversation
        startNewConversation()
        
        // Setup background app lifecycle notifications
        setupBackgroundNotifications()
        
        // Start performance monitoring
        startPerformanceMonitoring()
    }
    
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
    
    @objc private func appDidEnterBackground() {
        print("📱 App entered background")
        if isRecording {
            print("🎤 Recording continues in background (unlimited duration)")
            // No need for background task - audio session keeps app alive
        }
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 App will enter foreground")
        // Audio session automatically handles foreground transition
    }
    
    private func startBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "AudioRecording") { [weak self] in
            print("⚠️ Background task expiring")
            self?.endBackgroundTask()
        }
        print("🔄 Background task started: \(backgroundTaskID.rawValue)")
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            print("🔄 Background task ended")
        }
    }
    
    private func startRecordingTimer() {
        recordingStartTime = Date()
        segmentStartTime = Date()
        recordingDuration = 0.0
        currentSegmentText = ""
        lastProcessedTextLength = 0 // Reset processed text length
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(startTime)
            
            // Check if we need to create a new segment
            if let segmentStart = self.segmentStartTime {
                let segmentElapsed = Date().timeIntervalSince(segmentStart)
                if segmentElapsed >= self.segmentDuration {
                    self.createSegment()
                }
            }
        }
        print("⏱️ Recording timer started with 30-second auto-segmentation")
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        
        print("⏱️ Recording timer stopped - Duration: \(formatDuration(recordingDuration))")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func createSegment() {
        guard !currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Reset segment timer and continue
            segmentStartTime = Date()
            return
        }
        
        // Show processing indicator
        isProcessingSegment = true
        
        // Calculate segment duration
        let segmentDuration = segmentStartTime.map { Date().timeIntervalSince($0) } ?? 30.0
        
        let originalText = currentSegmentText
        
        // Clear current segment text immediately to prevent duplicates
        currentSegmentText = ""
        segmentStartTime = Date()
        
        // Check if we should use Whisper API
        let shouldUseWhisper = hasValidOpenAIKey && 
                              isNetworkAvailable && 
                              currentAudioFileURL != nil
        
        if shouldUseWhisper {
            // Add to transcription queue for concurrent processing
            addToTranscriptionQueue(audioFileURL: currentAudioFileURL!, originalText: originalText, duration: segmentDuration)
        } else {
            // Use local transcription if:
            // - No API key
            // - Network unavailable
            // - No audio file
            let reason = !hasValidOpenAIKey ? "no API key" : 
                        !isNetworkAvailable ? "network unavailable" : "no audio file"
            print("📱 Using local transcription: \(reason)")
            createMessageWithText(originalText, duration: segmentDuration, usedWhisper: false)
        }
    }
    
    private func createMessageWithText(_ text: String, duration: TimeInterval, usedWhisper: Bool) {
        let transcriptionMethod: Message.TranscriptionMethod = usedWhisper ? .whisper : .local
        
        print("🔍 Creating message with transcription method: \(transcriptionMethod.rawValue)")
        
        let segmentMessage = Message(
            content: text,
            isUser: true,
            recordingDuration: duration,
            transcriptionMethod: transcriptionMethod
        )
        
        messages.append(segmentMessage)
        updateCurrentConversation()
        
        print("📝 Created 30-second segment: \(formatDuration(duration))")
        if usedWhisper {
            print("🎤 Used Whisper API transcription")
        } else {
            print("📱 Used on-device transcription")
        }
        
        // Reset for next segment (currentSegmentText already cleared in createSegment)
        currentAudioFileURL = nil
        retryAudioFileURL = nil // Clean up retry audio file
        
        // Hide processing indicator after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProcessingSegment = false
        }
    }
    
    func speakMessage(_ text: String) {
        print("🎤 Speaking message: \(text)")
        
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to setup audio session for playback: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5  // Slower rate for more natural speech
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            print("🛑 Speech synthesis stopped")
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
        // Start battery monitoring
        batteryLevelStart = getBatteryLevel()
        batteryMonitoringStartTime = Date()
        
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.logPerformanceMetrics()
        }
        print("📊 Performance monitoring started")
    }
    
    private func stopPerformanceMonitoring() {
        performanceTimer?.invalidate()
        performanceTimer = nil
        print("📊 Performance monitoring stopped")
    }
    
    private func logPerformanceMetrics() {
        let memoryUsage = getMemoryUsage()
        let cpuUsage = getCPUUsage()
        let batteryLevel = getBatteryLevel()
        let batteryImpact = calculateBatteryImpact()
        
        print("📊 Performance Metrics:")
        print("   💾 Memory: \(ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory))")
        print("   🔋 Battery Level: \(batteryLevel)%")
        print("   🔋 Battery Impact: \(batteryImpact)")
        print("   ⚡ CPU: \(cpuUsage)%")
        print("   🎤 Recording: \(isRecording ? "Yes" : "No")")
        print("   📱 Background: \(UIApplication.shared.applicationState == .background ? "Yes" : "No")")
    }
    
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
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private func getCPUUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let threadResult = task_threads(mach_task_self_, &threadList, &threadCount)
        
        if threadResult == KERN_SUCCESS, let threadList = threadList {
            for index in 0..<threadCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadList[Int(index)],
                                   thread_flavor_t(THREAD_BASIC_INFO),
                                   $0,
                                   &threadInfoCount)
                    }
                }
                
                if infoResult == KERN_SUCCESS {
                    totalUsageOfCPU += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)
                }
            }
            
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadList)), vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride))
        }
        
        return totalUsageOfCPU * 100.0
    }
    
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel * 100
    }
    
    private func calculateBatteryImpact() -> String {
        guard let startTime = batteryMonitoringStartTime else {
            return "Not started"
        }
        
        let currentBattery = getBatteryLevel()
        let batteryDrain = batteryLevelStart - currentBattery
        let timeElapsed = Date().timeIntervalSince(startTime) / 3600 // Convert to hours
        
        if timeElapsed < 0.01 { // Less than 36 seconds
            return "Calculating..."
        }
        
        let drainPerHour = batteryDrain / Float(timeElapsed)
        
        // Determine impact level based on drain rate
        if drainPerHour < 5 {
            return "Low (\(String(format: "%.1f", drainPerHour))%/hr)"
        } else if drainPerHour < 15 {
            return "Medium (\(String(format: "%.1f", drainPerHour))%/hr)"
        } else {
            return "High (\(String(format: "%.1f", drainPerHour))%/hr)"
        }
    }
    
    private func playTickSound() {
        print("🔊 Playing tick sound")
                DispatchQueue.main.async {
            self.impactGenerator.prepare()
            self.impactGenerator.impactOccurred(intensity: 1.0)
            self.tickSound?.currentTime = 0
            self.tickSound?.play()
        }
    }
    
    // Update the test haptic feedback function
    func testHapticFeedback() {
        print("🔊 Testing haptic feedback")
        playTickSound()
    }
    
    func startRecording(completion: @escaping (String) -> Void) {
        print("🎤 Starting recording")
        
        // Reset speech recognition components
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            return
        }
        
        // Request speech recognition permission first
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    // Now request microphone permission
                    AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                        guard let self = self else { return }
                        
                        DispatchQueue.main.async {
                            if granted {
                                print("✅ Microphone permission granted")
                                self.isRecording = true
                                self.startRecordingTimer()
                                self.setupAudioSession()
                                self.startSpeechRecognition(completion: completion)
                            } else {
                                print("❌ Microphone permission denied")
                                self.error = .permissionDenied
                            }
                        }
                    }
                case .denied:
                    print("❌ Speech recognition denied")
                    self.error = .permissionDenied
                case .restricted:
                    print("❌ Speech recognition restricted")
                    self.error = .permissionDenied
                case .notDetermined:
                    print("❌ Speech recognition not determined")
                    self.error = .permissionDenied
                @unknown default:
                    print("❌ Speech recognition unknown status")
                    self.error = .permissionDenied
                }
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configure audio session to support multiple input sources:
            // - .playAndRecord: Allows both recording and playback
            // - .defaultToSpeaker: Audio output goes to speaker (not earpiece)
            // - .allowBluetooth: Enables recording from Bluetooth devices like AirPods, headphones, etc.
            // 
            // BACKGROUND RECORDING SUPPORT:
            // - .playAndRecord category allows unlimited background recording
            // - iOS will keep the app alive as long as audio session is active
            // - No time limits when using audio session (vs background tasks which are limited to ~3-5 minutes)
            // - App can record continuously even when in background
            //
            // INPUT SOURCE PRIORITY (iOS automatically selects the best available):
            // 1. Connected Bluetooth headphones/AirPods (if .allowBluetooth is set)
            // 2. Wired headphones with microphone
            // 3. Phone's built-in microphone (fallback)
            //
            // This means users can record through:
            // ✅ AirPods Pro/Max (with active noise cancellation)
            // ✅ Bluetooth headphones with built-in mics
            // ✅ Wired headphones with inline microphones
            // ✅ Phone's built-in microphone
            // ✅ UNLIMITED background recording (no time limits)
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured successfully for background recording")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func startSpeechRecognition(completion: @escaping (String) -> Void) {
        print("🎤 Starting speech recognition")
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine?.inputNode
        
        // Create and configure the speech recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Unable to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Speech recognition error: \(error.localizedDescription)")
                if error._domain == "kAFAssistantErrorDomain" && error._code == 1101 {
                    // Handle local speech recognition error
                    print("⚠️ Local speech recognition error - attempting to recover")
                    DispatchQueue.main.async {
                        self.stopRecording()
                        // Try to restart the recognition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.startSpeechRecognition(completion: completion)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.stopRecording()
                    }
                }
                return
            }
            
            if let result = result {
                let transcribedText = result.bestTranscription.formattedString
//                print("📝 Transcribed text: \(transcribedText)")
                DispatchQueue.main.async {
                    self.inputText = transcribedText
                    
                    // Only append new text to current segment
                    if transcribedText.count > self.lastProcessedTextLength {
                        let newText = String(transcribedText.dropFirst(self.lastProcessedTextLength))
                        self.currentSegmentText += newText
                        self.lastProcessedTextLength = transcribedText.count
                    }
                    
                    completion(transcribedText)
                }
            }
        }
        
        // Configure the microphone input
        let recordingFormat = inputNode?.outputFormat(forBus: 0)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio recording for Whisper API
        startAudioRecording()
        
        audioEngine?.prepare()
        do {
            try audioEngine?.start()
            print("✅ Audio engine started successfully")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            DispatchQueue.main.async {
                self.stopRecording()
            }
        }
    }
    
    private func startAudioRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = "segment_\(Date().timeIntervalSince1970).m4a"
        currentAudioFileURL = documentsPath.appendingPathComponent(audioFilename)
        
        guard let audioFileURL = currentAudioFileURL else {
            print("❌ Could not create audio file URL")
            return
        }
        
        let settings = audioQuality.settings
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.record()
            print("🎙️ Audio recording started for Whisper API with \(audioQuality.rawValue) quality")
        } catch {
            print("❌ Failed to start audio recording: \(error)")
        }
    }
    
    func stopRecording() {
        print("🛑 Stopping recording")
        
        // Stop audio recording
        audioRecorder?.stop()
        audioRecorder = nil
        print("🎙️ Audio recording stopped")
        
        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated")
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
        }
        
        isRecording = false
        stopRecordingTimer()
        
        // Handle any remaining current segment text
        if !currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let segmentDuration = segmentStartTime.map { Date().timeIntervalSince($0) } ?? 30.0
            let text = currentSegmentText
            
            // Check if we should use Whisper API for final segment
            let shouldUseWhisper = hasValidOpenAIKey && 
                                  isNetworkAvailable && 
                                  currentAudioFileURL != nil
            
            if shouldUseWhisper {
                addToTranscriptionQueue(audioFileURL: currentAudioFileURL!, originalText: text, duration: segmentDuration)
            } else {
                createMessageWithText(text, duration: segmentDuration, usedWhisper: false)
            }
        }
        
        // Audio session automatically deactivates when recording stops
        inputText = ""
    }
    
    func clearTranscribedText() {
        inputText = ""
    }
    
    private func updateCurrentConversation() {
        print("\n=== Updating Current Conversation ===")
        guard !messages.isEmpty else {
            print("⚠️ No messages to save")
            return
        }
        
        let title = messages.first?.content.prefix(30) ?? "New Conversation"
        let conversation = Conversation(
            title: String(title),
            messages: messages,
            date: Date()
        )
        
        if currentConversationIndex >= 0 && currentConversationIndex < conversations.count {
            // Update existing conversation
            print("📝 Updating existing conversation at index \(currentConversationIndex)")
            conversations[currentConversationIndex] = conversation
        } else {
            // Add new conversation
            print("📝 Adding new conversation")
            conversations.append(conversation)
            currentConversationIndex = conversations.count - 1
        }
        
        // Mark as having unsaved changes and schedule save
        hasUnsavedChanges = true
        scheduleSave()
    }
    
    private func scheduleSave() {
        // Cancel existing timer
        saveTimer?.invalidate()
        
        // Schedule new save after 2 seconds
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self, self.hasUnsavedChanges else { return }
            print("💾 Debounced save triggered")
            self.persistChatHistory()
            self.hasUnsavedChanges = false
        }
    }
    
    func startNewConversation() {
        print("\n=== Starting New Conversation ===")
        // Save current conversation if it exists and has messages
        if !messages.isEmpty {
            updateCurrentConversation()
        }
        
        // Start new conversation with empty messages
        messages = []
        currentConversationIndex = -1
        inputText = ""
    }
    
    func loadConversation(at index: Int) {
        guard index >= 0 && index < conversations.count else { return }
        messages = conversations[index].messages
        currentConversationIndex = index
    }
    
    func persistChatHistory() {
        DeviceManager.shared.saveChatHistory(conversations)
    }
    
    func loadPersistedChatHistory() {
        if let loadedConversations = DeviceManager.shared.loadChatHistory() {
            conversations = loadedConversations
            if !conversations.isEmpty {
                currentConversationIndex = conversations.count - 1
            }
        }
    }
    
    func clearPersistedChatHistory() {
        DeviceManager.shared.clearChatHistory()
        conversations = []
        currentConversationIndex = -1
    }
    
    deinit {
        stopPerformanceMonitoring()
        stopNetworkMonitoring()
        
        // Remove audio route observer
        if let observer = audioRouteObserver {
            NotificationCenter.default.removeObserver(observer)
            print("🎧 Audio route monitoring stopped")
        }
        
        // Remove audio interruption observer
        if let observer = audioInterruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            print("🎧 Audio interruption monitoring stopped")
        }
        
        NotificationCenter.default.removeObserver(self)
        
        // Force save any unsaved changes
        if hasUnsavedChanges {
            print("💾 Force saving before deinit")
            persistChatHistory()
        }
        
        // Clean up temporary audio files
        cleanupAudioFiles()
    }
    
    private func cleanupAudioFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let audioFiles = files.filter { $0.lastPathComponent.hasPrefix("segment_") && $0.pathExtension == "m4a" }
            
            for audioFile in audioFiles {
                try FileManager.default.removeItem(at: audioFile)
                print("🗑️ Cleaned up audio file: \(audioFile.lastPathComponent)")
            }
        } catch {
            print("❌ Failed to cleanup audio files: \(error)")
        }
    }
    
    // MARK: - Network and Queue Management
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasAvailable = self?.isNetworkAvailable ?? true
                self?.isNetworkAvailable = path.status == .satisfied
                
                if !wasAvailable && self?.isNetworkAvailable == true {
                    print("🌐 Network became available - processing queued transcriptions")
                    self?.queueStatus = .queued(count: self?.pendingTranscriptions.count ?? 0)
                    self?.processQueuedTranscriptions()
                } else if wasAvailable && self?.isNetworkAvailable == false {
                    print("❌ Network became unavailable - queuing transcriptions")
                    self?.queueStatus = .offline
                    
                    // If currently recording, ensure current segment is handled
                    if self?.isRecording == true {
                        self?.handleNetworkLossDuringRecording()
                    }
                }
            }
        }
        networkMonitor?.start(queue: networkQueue)
        print("🌐 Network monitoring started")
    }
    
    private func stopNetworkMonitoring() {
        networkMonitor?.cancel()
        networkMonitor = nil
        print("🌐 Network monitoring stopped")
    }
    
    private func handleNetworkLossDuringRecording() {
        print("📱 Network lost during recording - ensuring current segment is handled")
        
        // If we have current segment text, create a message with local transcription
        if !currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let segmentDuration = segmentStartTime.map { Date().timeIntervalSince($0) } ?? 30.0
            let text = currentSegmentText
            
            // Clear current segment
            currentSegmentText = ""
            segmentStartTime = Date()
            
            // Create message with local transcription since network is down
            createMessageWithText(text, duration: segmentDuration, usedWhisper: false)
            
            print("📱 Created segment with local transcription due to network loss")
        }
    }
    
    private func addToTranscriptionQueue(audioFileURL: URL, originalText: String, duration: TimeInterval) {
        let pending = PendingTranscription(
            id: UUID(),
            audioFileURL: audioFileURL,
            originalText: originalText,
            duration: duration,
            timestamp: Date()
        )
        
        pendingTranscriptions.append(pending)
        print("📋 Added to transcription queue: \(pendingTranscriptions.count) pending")
        
        // Update UI status
        DispatchQueue.main.async {
            if !self.isNetworkAvailable {
                self.queueStatus = .offline
            } else if self.activeTranscriptionCount > 0 {
                self.queueStatus = .processing(count: self.activeTranscriptionCount)
            } else {
                self.queueStatus = .queued(count: self.pendingTranscriptions.count)
            }
        }
        
        // Try to process queue
        processQueuedTranscriptions()
    }
    
    private func processQueuedTranscriptions() {
        guard isNetworkAvailable && !isProcessingQueue else { return }
        
        isProcessingQueue = true
        
        transcriptionQueue.async { [weak self] in
            guard let self = self else { return }
            
            while !self.pendingTranscriptions.isEmpty && 
                  self.activeTranscriptionCount < self.maxConcurrentRequests {
                
                guard let pending = self.pendingTranscriptions.first else { break }
                self.pendingTranscriptions.removeFirst()
                
                self.activeTranscriptionCount += 1
                print("🔄 Processing queued transcription (\(self.activeTranscriptionCount)/\(self.maxConcurrentRequests))")
                
                // Update UI status
                DispatchQueue.main.async {
                    self.queueStatus = .processing(count: self.activeTranscriptionCount)
                }
                
                self.transcribeAudioWithWhisper(audioFileURL: pending.audioFileURL) { [weak self] whisperText in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        if whisperText != nil {
                            // Success - create message
                            self.createMessageWithText(whisperText!, duration: pending.duration, usedWhisper: true)
                        } else {
                            // Failed - handle retry logic
                            if pending.retryCount < self.maxWhisperRetries {
                                // Add back to queue for retry
                                self.addFailedTranscriptionToQueue(
                                    audioFileURL: pending.audioFileURL,
                                    originalText: pending.originalText,
                                    duration: pending.duration,
                                    retryCount: pending.retryCount + 1
                                )
                            } else {
                                // Max retries reached - use local transcription
                                print("❌ Max retries reached for transcription - using local fallback")
                                self.createMessageWithText(pending.originalText, duration: pending.duration, usedWhisper: false)
                            }
                        }
                        
                        self.activeTranscriptionCount -= 1
                        
                        // Update UI status
                        if self.pendingTranscriptions.isEmpty && self.activeTranscriptionCount == 0 {
                            self.queueStatus = .idle
                        } else if self.activeTranscriptionCount > 0 {
                            self.queueStatus = .processing(count: self.activeTranscriptionCount)
                        } else {
                            self.queueStatus = .queued(count: self.pendingTranscriptions.count)
                        }
                        
                        // Continue processing queue
                        self.processQueuedTranscriptions()
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isProcessingQueue = false
            }
        }
    }
    
    // MARK: - Audio Route Monitoring
    
    private func setupAudioRouteMonitoring() {
        audioRouteObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let userInfo = notification.userInfo,
               let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? NSNumber,
               let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue.uintValue) {
                
                let oldRoute = self.getCurrentAudioRoute()
                
                switch reason {
                case .newDeviceAvailable:
                    print("🎧 New audio device available")
                    self.handleNewAudioDevice()
                case .oldDeviceUnavailable:
                    print("🎧 Old audio device unavailable")
                    self.handleAudioRouteChange()
                case .categoryChange:
                    print("🎧 Audio session category changed")
                case .override:
                    print("🎧 Audio session overridden")
                case .routeConfigurationChange:
                    print("🎧 Audio session route configuration changed")
                default:
                    print("🎧 Unknown audio route change reason")
                }
                
                let newRoute = self.getCurrentAudioRoute()
                print("🎧 Audio route changed: \(oldRoute) → \(newRoute)")
                
                // Update UI with new route
                self.updateAudioRouteDisplay()
            }
        }
        print("🎧 Audio route monitoring started")
    }
    
    private func getCurrentAudioRoute() -> String {
        let audioSession = AVAudioSession.sharedInstance()
        
        // Get current output route
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
    
    private func handleNewAudioDevice() {
        print("🎧 New audio device detected - continuing recording")
        // Optionally restart audio session to use new device
        setupAudioSession()
    }
    
    private func handleAudioRouteChange() {
        print("📱 Audio route changed - ensuring current segment is handled")
        
        // If we have current segment text, create a message with local transcription
        if !currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let segmentDuration = segmentStartTime.map { Date().timeIntervalSince($0) } ?? 30.0
            let text = currentSegmentText
            
            // Clear current segment
            currentSegmentText = ""
            segmentStartTime = Date()
            
            // Create message with local transcription since route is changed
            createMessageWithText(text, duration: segmentDuration, usedWhisper: false)
            
            print("📱 Created segment with local transcription due to audio route change")
        }
    }
    
    private func updateAudioRouteDisplay() {
        DispatchQueue.main.async {
            self.currentAudioRoute = self.getCurrentAudioRoute()
        }
    }
    
    // MARK: - Audio Interruption Monitoring
    
    private func setupAudioInterruptionMonitoring() {
        audioInterruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let userInfo = notification.userInfo,
               let reasonValue = userInfo[AVAudioSessionInterruptionReasonKey] as? NSNumber,
               let reason = AVAudioSession.InterruptionReason(rawValue: reasonValue.uintValue) {
                
                // Check if it's a Siri interruption
                let isSiriInterruption = self.isSiriInterruption(userInfo: userInfo)
                
                switch reason {
                case .began:
                    if isSiriInterruption {
                        print("🎤 Siri interruption began")
                        self.handleSiriInterruption()
                    } else {
                        print("📱 Audio interruption began")
                        self.handleAudioInterruption()
                    }
                case .ended:
                    if isSiriInterruption {
                        print("🎤 Siri interruption ended")
                        self.handleSiriInterruptionEnded()
                    } else {
                        print("📱 Audio interruption ended")
                        self.handleAudioInterruptionEnded()
                    }
                default:
                    print("🎧 Unknown audio interruption reason")
                }
            }
        }
        print("🎧 Audio interruption monitoring started")
    }
    
    private func isSiriInterruption(userInfo: [AnyHashable: Any]) -> Bool {
        // Method 1: Check for Siri-specific interruption flags
        if let interruptionTypeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber {
            // Siri typically uses specific interruption types
            return interruptionTypeValue.uintValue == AVAudioSession.InterruptionType.duckOthers.rawValue
        }
        
        // Method 2: Check for Siri in the interruption description
        if let interruptionDescription = userInfo[AVAudioSessionInterruptionOptionKey] as? String {
            return interruptionDescription.lowercased().contains("siri")
        }
        
        // Method 3: Check for system audio interruptions that are likely Siri
        if let interruptionTypeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber {
            let type = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue.uintValue)
            // Siri often uses duckOthers or beginsOtherAudio
            return type == .duckOthers || type == .beginsOtherAudio
        }
        
        // Method 4: Check for brief interruptions (Siri is usually brief)
        if let durationValue = userInfo[AVAudioSessionInterruptionDurationKey] as? NSNumber {
            let duration = durationValue.doubleValue
            // Siri interruptions are typically brief (less than 10 seconds)
            return duration < 10.0
        }
        
        return false
    }
    
    private func handleSiriInterruption() {
        print("🎤 Siri activated - pausing recording")
        
        // For Siri, we might want to pause rather than stop completely
        // since Siri interruptions are usually brief
        if isRecording {
            // Pause the recording timer but keep the session active
            recordingTimer?.invalidate()
            recordingTimer = nil
            print("🎤 Recording paused for Siri")
        }
    }
    
    private func handleSiriInterruptionEnded() {
        print("🎤 Siri ended - resuming recording")
        
        // Resume recording if it was paused for Siri
        if isRecording && recordingTimer == nil {
            startRecordingTimer()
            print("🎤 Recording resumed after Siri")
        }
    }
    
    private func handleAudioInterruption() {
        print("📱 Audio interruption began - stopping recording")
        stopRecording()
    }
    
    private func handleAudioInterruptionEnded() {
        print("📱 Audio interruption ended")
        // Don't auto-resume for non-Siri interruptions
        // User should manually restart recording
    }
}

extension Notification.Name {
    static let audioPlaybackStarted = Notification.Name("audioPlaybackStarted")
}
