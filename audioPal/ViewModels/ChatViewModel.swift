import Foundation
import SwiftUI
import AVFoundation
import Speech
import UIKit
import Network
import WidgetKit

class ChatViewModel: NSObject, ObservableObject {
    @Published var messages: [Message] = []
    @Published var isRecording: Bool = false
    @Published var isThinking: Bool = false
    @Published var isProcessingSegment: Bool = false
    @Published var inputText: String = ""
    @Published var error: ChatError?
    @Published var conversations: [Conversation] = []
    @Published var currentConversationIndex: Int = -1
    @Published var synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()
    @Published var queueStatus: QueueStatus = .idle
    
    var hasValidOpenAIKey: Bool {
        return whisperAPIManager.hasValidOpenAIKey
    }
    
    @Published var audioManager = AudioManager()
    @Published var speechRecognitionManager = SpeechRecognitionManager()
    @Published var whisperAPIManager = WhisperAPIManager()
    private let recordingManager = RecordingManager()
    
    @Published var networkQueueManager: NetworkQueueManager
    
    private var hasUnsavedChanges: Bool = false
    private var saveTimer: Timer?
    
    private var performanceTimer: Timer?
    private var cpuUsageStartTime: Date?
    private var memoryUsageStartValue: UInt64 = 0
    private var batteryLevelStart: Float = 0.0
    private var batteryMonitoringStartTime: Date?
    
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private var tickSound: AVAudioPlayer?
    
    override init() {
        let audioManager = AudioManager()
        let speechRecognitionManager = SpeechRecognitionManager()
        let whisperAPIManager = WhisperAPIManager()
        
        self.networkQueueManager = NetworkQueueManager()
        
        super.init()
        
        self.audioManager = audioManager
        self.speechRecognitionManager = speechRecognitionManager
        self.whisperAPIManager = whisperAPIManager
        
        self.networkQueueManager = NetworkQueueManager(whisperAPIManager: whisperAPIManager, chatViewModel: self)
        
        impactGenerator.prepare()
        selectionGenerator.prepare()
        
        setupTickSound()
        loadPersistedChatHistory()
        setupBackgroundNotifications()
        startPerformanceMonitoring()
        startNewConversation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.refreshWidgetData()
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupTickSound() {
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
        }
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 App will enter foreground")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshWidgetData()
        }
    }
    
    // MARK: - Recording Management
    
    func startRecording(completion: @escaping (String) -> Void) {
        print("🎤 Starting recording")
        
        if !canStartRecording() {
            print("❌ Missing required permissions")
            requestPermissionsIfNeeded()
            error = .permissionDenied
            return
        }
        
        print("✅ All permissions granted, starting recording")
        isRecording = true
        
        updateWidgetRecordingStatus(true)
        
        audioManager.setupAudioSession()
        
        if let audioFileURL = recordingManager.startRecording(audioQuality: audioManager.audioQuality) {
            whisperAPIManager.setRetryAudioFile(audioFileURL)
        }
        
        speechRecognitionManager.startSpeechRecognition { [weak self] transcribedText in
            guard let self = self else { return }
            self.inputText = transcribedText
            completion(transcribedText)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func stopRecording() {
        guard isRecording else {
            print("🛑 Stop recording called but already stopped")
            return
        }
        
        print("🛑 Stopping recording")
        
        recordingManager.stopRecording()
        speechRecognitionManager.stopSpeechRecognition()
        audioManager.deactivateAudioSession()
        
        isRecording = false
        updateWidgetRecordingStatus(false)
        
        let currentSegmentText = speechRecognitionManager.getCurrentSegmentText()
        if !currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessingSegment {
            let segmentDuration = 30.0
            let text = currentSegmentText
            
            let shouldUseWhisper = whisperAPIManager.hasValidOpenAIKey && 
                                  networkQueueManager.getNetworkStatus() && 
                                  recordingManager.getCurrentAudioFileURL() != nil
            
            if shouldUseWhisper {
                addToTranscriptionQueue(audioFileURL: recordingManager.getCurrentAudioFileURL()!, originalText: text, duration: segmentDuration)
            } else {
                createMessageWithText(text, duration: segmentDuration, usedWhisper: false)
            }
        } else if isProcessingSegment {
            print("🔄 Skipping final segment processing - already processing a segment")
        }
        
        inputText = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // MARK: - Segment Management
    
    private func createSegment() {
        let currentSegmentText = speechRecognitionManager.getCurrentSegmentText()
        guard !currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        print("🔄 Setting isProcessingSegment = true")
        isProcessingSegment = true
        
        let segmentDuration: TimeInterval = 30.0
        let originalText = currentSegmentText
        
        speechRecognitionManager.clearCurrentSegmentText()
        
        speechRecognitionManager.restartSpeechRecognitionForNewSegment { [weak self] transcribedText in
            guard let self = self else { return }
            self.inputText = transcribedText
        }
        
        let shouldUseWhisper = whisperAPIManager.hasValidOpenAIKey && 
                              networkQueueManager.getNetworkStatus() && 
                              recordingManager.getCurrentAudioFileURL() != nil
        
        if shouldUseWhisper {
            addToTranscriptionQueue(audioFileURL: recordingManager.getCurrentAudioFileURL()!, originalText: originalText, duration: segmentDuration)
        } else {
            let reason = !whisperAPIManager.hasValidOpenAIKey ? "no API key" : 
                        !networkQueueManager.getNetworkStatus() ? "network unavailable" : "no audio file"
            print("📱 Using local transcription: \(reason)")
            createMessageWithText(originalText, duration: segmentDuration, usedWhisper: false)
        }
    }
    
    func createMessageWithText(_ text: String, duration: TimeInterval, usedWhisper: Bool) {
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
        
        recordingManager.clearCurrentAudioFile()
        whisperAPIManager.clearRetryAudioFile()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔄 Setting isProcessingSegment = false (transcription completed)")
            self.isProcessingSegment = false
        }
    }
    
    private func addToTranscriptionQueue(audioFileURL: URL, originalText: String, duration: TimeInterval) {
        print("📋 Adding to transcription queue: \(audioFileURL.lastPathComponent)")
        networkQueueManager.addToTranscriptionQueue(audioFileURL: audioFileURL, originalText: originalText, duration: duration)
        
        queueStatus = networkQueueManager.getQueueStatus()
        print("📊 Queue status updated: \(queueStatus.description)")
    }
    
    // MARK: - Speech Synthesis
    
    func speakMessage(_ text: String) {
        print("🎤 Speaking message: \(text)")
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to setup audio session for playback: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
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
    
    // MARK: - Permission Management
    
    func requestPermissionsIfNeeded() {
        print("🔐 Requesting permissions if needed")
        
        speechRecognitionManager.requestSpeechRecognitionPermission { [weak self] granted in
            DispatchQueue.main.async {
                if !granted {
                    self?.error = .permissionDenied
                }
            }
        }
        
        audioManager.requestMicrophonePermission { [weak self] granted in
            DispatchQueue.main.async {
                if !granted {
                    self?.error = .permissionDenied
                }
            }
        }
    }
    
    func canStartRecording() -> Bool {
        let hasMicrophonePermission = audioManager.hasMicrophonePermission()
        let hasSpeechPermission = speechRecognitionManager.hasSpeechRecognitionPermission()
        
        print("🔐 Recording permissions check:")
        print("   🎤 Microphone: \(hasMicrophonePermission ? "✅" : "❌")")
        print("   🗣️ Speech Recognition: \(hasSpeechPermission ? "✅" : "❌")")
        
        return hasMicrophonePermission && hasSpeechPermission
    }
    
    func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl) { success in
                print("🔐 Settings opened: \(success)")
            }
        }
    }
    
    // MARK: - Widget Management
    
    private func updateWidgetRecordingStatus(_ isRecording: Bool) {
        if let userDefaults = UserDefaults(suiteName: "group.testaaa.audioPal") {
            userDefaults.set(isRecording, forKey: "isRecording")
            userDefaults.set(isRecording ? recordingManager.recordingDuration : 0, forKey: "recordingDuration")
            userDefaults.set(Date(), forKey: "lastUpdateTime")
            WidgetCenter.shared.reloadAllTimelines()
            print("🔧 App: \(isRecording ? "Started" : "Stopped") recording - widget updated")
        } else {
            print("❌ App: Failed to access shared UserDefaults when \(isRecording ? "starting" : "stopping") recording")
        }
    }
    
    private func refreshWidgetData() {
        print("🔧 App: Refreshing widget data")
        
        if let userDefaults = UserDefaults(suiteName: "group.testaaa.audioPal") {
            userDefaults.set(isRecording, forKey: "isRecording")
            userDefaults.set(recordingManager.recordingDuration, forKey: "recordingDuration")
            
            let canRecord = audioManager.hasMicrophonePermission() && speechRecognitionManager.hasSpeechRecognitionPermission()
            userDefaults.set(canRecord, forKey: "canRecord")
            
            userDefaults.set(Date(), forKey: "lastUpdateTime")
            WidgetCenter.shared.reloadAllTimelines()
            
            print("🔧 App: Widget data refreshed - isRecording: \(isRecording), canRecord: \(canRecord), duration: \(recordingManager.recordingDuration)")
        } else {
            print("❌ App: Failed to access shared UserDefaults for widget refresh")
        }
    }
    
    // MARK: - Conversation Management
    
    func startNewConversation() {
        print("\n=== Starting New Conversation ===")
        if !messages.isEmpty {
            updateCurrentConversation()
        }
        
        messages = []
        currentConversationIndex = -1
        inputText = ""
    }
    
    func loadConversation(at index: Int) {
        guard index >= 0 && index < conversations.count else { return }
        messages = conversations[index].messages
        currentConversationIndex = index
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
            print("📝 Updating existing conversation at index \(currentConversationIndex)")
            conversations[currentConversationIndex] = conversation
        } else {
            print("📝 Adding new conversation")
            conversations.append(conversation)
            currentConversationIndex = conversations.count - 1
        }
        
        hasUnsavedChanges = true
        scheduleSave()
    }
    
    private func scheduleSave() {
        saveTimer?.invalidate()
        
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self, self.hasUnsavedChanges else { return }
            print("💾 Debounced save triggered")
            self.persistChatHistory()
            self.hasUnsavedChanges = false
        }
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
    
    // MARK: - Utility Methods
    
    func clearTranscribedText() {
        inputText = ""
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func testHapticFeedback() {
        print("🔊 Testing haptic feedback")
        playTickSound()
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
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
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
        let timeElapsed = Date().timeIntervalSince(startTime) / 3600
        
        if timeElapsed < 0.01 {
            return "Calculating..."
        }
        
        let drainPerHour = batteryDrain / Float(timeElapsed)
        
        if drainPerHour < 5 {
            return "Low (\(String(format: "%.1f", drainPerHour))%/hr)"
        } else if drainPerHour < 15 {
            return "Medium (\(String(format: "%.1f", drainPerHour))%/hr)"
        } else {
            return "High (\(String(format: "%.1f", drainPerHour))%/hr)"
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopPerformanceMonitoring()
        
        NotificationCenter.default.removeObserver(self)
        
        if hasUnsavedChanges {
            print("💾 Force saving before deinit")
            persistChatHistory()
        }
        
        recordingManager.cleanupAudioFiles()
    }
}

extension Notification.Name {
    static let audioPlaybackStarted = Notification.Name("audioPlaybackStarted")
}