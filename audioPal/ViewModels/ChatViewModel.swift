import Foundation
import SwiftUI
import AVFoundation
import Speech
import UIKit

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
    private var audioLevelTimer: Timer?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // Auto-segmentation
    private let segmentDuration: TimeInterval = 30.0 // 30 seconds
    private var currentSegmentText: String = ""
    private var segmentStartTime: Date?
    
    // Performance monitoring
    private var performanceTimer: Timer?
    private var cpuUsageStartTime: Date?
    private var memoryUsageStartValue: UInt64 = 0
    private var batteryLevelStart: Float = 0.0
    private var batteryMonitoringStartTime: Date?
    
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private var tickSound: AVAudioPlayer?
    
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
        
        // Create final segment if there's remaining text
        if !currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            createSegment()
        }
        
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
        
        // Create message for this segment
        let segmentMessage = Message(
            content: currentSegmentText,
            isUser: true,
            recordingDuration: segmentDuration
        )
        
        messages.append(segmentMessage)
        updateCurrentConversation()
        
        print("📝 Created 30-second segment: \(formatDuration(segmentDuration))")
        
        // Reset for next segment
        currentSegmentText = ""
        segmentStartTime = Date()
        
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
                    self.currentSegmentText = transcribedText
                    completion(transcribedText)
                }
            }
        }
        
        // Configure the microphone input
        let recordingFormat = inputNode?.outputFormat(forBus: 0)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
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
    
    func stopRecording() {
        print("🛑 Stopping recording")
        
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
        
        // Audio session automatically deactivates when recording stops
        
        // Final segment is created in stopRecordingTimer() if needed
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
        
        // Save after updating
        persistChatHistory()
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
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
        // End background task if still active
        endBackgroundTask()
        // Stop performance monitoring
        stopPerformanceMonitoring()
    }
}

extension Notification.Name {
    static let audioPlaybackStarted = Notification.Name("audioPlaybackStarted")
}
