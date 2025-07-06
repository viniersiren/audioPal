import Foundation
import Network

class NetworkQueueManager: ObservableObject {
    @Published var queueStatus: QueueStatus = .idle
    @Published var isNetworkAvailable: Bool = true
    
    private let transcriptionQueue = DispatchQueue(label: "com.audiopal.transcription", qos: .userInitiated, attributes: .concurrent)
    private var pendingTranscriptions: [PendingTranscription] = []
    private var isProcessingQueue: Bool = false
    private let maxConcurrentRequests: Int = 3
    private var activeTranscriptionCount: Int = 0
    
    // Network monitoring
    private var networkMonitor: NWPathMonitor?
    private let networkQueue = DispatchQueue(label: "com.audiopal.network")
    
    // Whisper API manager reference
    private weak var whisperAPIManager: WhisperAPIManager?
    private weak var chatViewModel: ChatViewModel?
    
    init(whisperAPIManager: WhisperAPIManager? = nil, chatViewModel: ChatViewModel? = nil) {
        self.whisperAPIManager = whisperAPIManager
        self.chatViewModel = chatViewModel
        setupNetworkMonitoring()
    }
    
    deinit {
        stopNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    
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
    
    // MARK: - Queue Management
    
    func addToTranscriptionQueue(audioFileURL: URL, originalText: String, duration: TimeInterval) {
        let isDuplicate = pendingTranscriptions.contains { pending in
            pending.audioFileURL == audioFileURL
        }
        
        if isDuplicate {
            print("🔄 Skipping duplicate transcription for audio file: \(audioFileURL.lastPathComponent)")
            return
        }
        
        let pending = PendingTranscription(
            id: UUID(),
            audioFileURL: audioFileURL,
            originalText: originalText,
            duration: duration,
            timestamp: Date()
        )
        
        pendingTranscriptions.append(pending)
        print("📋 Added to transcription queue: \(pendingTranscriptions.count) pending")
        
        DispatchQueue.main.async {
            if !self.isNetworkAvailable {
                self.queueStatus = .offline
            } else if self.activeTranscriptionCount > 0 {
                self.queueStatus = .processing(count: self.activeTranscriptionCount)
            } else {
                self.queueStatus = .queued(count: self.pendingTranscriptions.count)
            }
        }
        
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
                
                DispatchQueue.main.async {
                    self.queueStatus = .processing(count: self.activeTranscriptionCount)
                }
                
                self.processTranscription(pending) { [weak self] success in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        if !success {
                            if pending.retryCount < 5 {
                                self.addFailedTranscriptionToQueue(
                                    audioFileURL: pending.audioFileURL,
                                    originalText: pending.originalText,
                                    duration: pending.duration,
                                    retryCount: pending.retryCount + 1
                                )
                            }
                        }
                        
                        self.activeTranscriptionCount -= 1
                        
                        if self.pendingTranscriptions.isEmpty && self.activeTranscriptionCount == 0 {
                            self.queueStatus = .idle
                        } else if self.activeTranscriptionCount > 0 {
                            self.queueStatus = .processing(count: self.activeTranscriptionCount)
                        } else {
                            self.queueStatus = .queued(count: self.pendingTranscriptions.count)
                        }
                        
                        self.processQueuedTranscriptions()
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isProcessingQueue = false
            }
        }
    }
    
    private func processTranscription(_ pending: PendingTranscription, completion: @escaping (Bool) -> Void) {
        guard let whisperAPIManager = whisperAPIManager else {
            print("❌ No WhisperAPIManager available for transcription")
            completion(false)
            return
        }
        
        print("🎤 Processing transcription with Whisper API")
        whisperAPIManager.transcribeAudioWithWhisper(audioFileURL: pending.audioFileURL) { [weak self] whisperText in
            guard let self = self else { return }
            
            if let whisperText = whisperText {
                self.chatViewModel?.createMessageWithText(whisperText, duration: pending.duration, usedWhisper: true)
                completion(true)
            } else {
                print("❌ Whisper API transcription failed")
                completion(false)
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
        
        pendingTranscriptions.insert(pending, at: 0)
        print("🔄 Added failed transcription back to queue for retry (attempt \(retryCount + 1))")
    }
    
    // MARK: - Public Interface
    
    func getQueueStatus() -> QueueStatus {
        return queueStatus
    }
    
    func getNetworkStatus() -> Bool {
        return isNetworkAvailable
    }
    
    func getPendingTranscriptionCount() -> Int {
        return pendingTranscriptions.count
    }
    
    func getActiveTranscriptionCount() -> Int {
        return activeTranscriptionCount
    }
    
    func clearQueue() {
        pendingTranscriptions.removeAll()
        activeTranscriptionCount = 0
        queueStatus = .idle
        print("🗑️ Transcription queue cleared")
    }
} 