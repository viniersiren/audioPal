import Foundation
import Speech
import AVFoundation

class SpeechRecognitionManager: NSObject, ObservableObject {
    @Published var speechRecognizer: SFSpeechRecognizer?
    @Published var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @Published var recognitionTask: SFSpeechRecognitionTask?
    @Published var audioEngine: AVAudioEngine?
    @Published var speechRecognitionPermissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private var currentSegmentText: String = ""
    private var lastProcessedTextLength: Int = 0
    
    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        checkSpeechRecognitionPermissionStatus()
    }
    
    deinit {
        stopSpeechRecognition()
    }
    
    private func checkSpeechRecognitionPermissionStatus() {
        speechRecognitionPermissionStatus = SFSpeechRecognizer.authorizationStatus()
        print("🔐 Speech recognition permission status: \(speechRecognitionPermissionStatus.description)")
    }
    
    func requestSpeechRecognitionPermission(completion: @escaping (Bool) -> Void) {
        if speechRecognitionPermissionStatus == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.speechRecognitionPermissionStatus = status
                    print("🗣️ Speech recognition permission: \(status.description)")
                    completion(status == .authorized)
                }
            }
        } else {
            completion(speechRecognitionPermissionStatus == .authorized)
        }
    }
    
    func hasSpeechRecognitionPermission() -> Bool {
        return speechRecognitionPermissionStatus == .authorized
    }
    
    func startSpeechRecognition(completion: @escaping (String) -> Void) {
        print("🎤 Starting speech recognition")
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            return
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine?.inputNode
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Unable to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Speech recognition error: \(error.localizedDescription)")
                if error._domain == "kAFAssistantErrorDomain" && error._code == 1101 {
                    print("⚠️ Local speech recognition error - attempting to recover")
                    DispatchQueue.main.async {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.startSpeechRecognition(completion: completion)
                        }
                    }
                }
                return
            }
            
            if let result = result {
                let transcribedText = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    if transcribedText.count > self.lastProcessedTextLength {
                        let newText = String(transcribedText.dropFirst(self.lastProcessedTextLength))
                        self.currentSegmentText += newText
                        self.lastProcessedTextLength = transcribedText.count
                    }
                    
                    completion(transcribedText)
                }
            }
        }
        
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
        }
    }
    
    func stopSpeechRecognition() {
        print("🛑 Stopping speech recognition")
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated")
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
        }
    }
    
    func restartSpeechRecognitionForNewSegment(completion: @escaping (String) -> Void) {
        print("🔄 Restarting speech recognition for new segment")
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Unable to create new recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Speech recognition error in new segment: \(error.localizedDescription)")
                return
            }
            
            if let result = result {
                let transcribedText = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    if transcribedText.count > self.lastProcessedTextLength {
                        let newText = String(transcribedText.dropFirst(self.lastProcessedTextLength))
                        self.currentSegmentText += newText
                        self.lastProcessedTextLength = transcribedText.count
                    }
                    
                    completion(transcribedText)
                }
            }
        }
        
        print("✅ Speech recognition restarted for new segment")
    }
    
    func getCurrentSegmentText() -> String {
        return currentSegmentText
    }
    
    func clearCurrentSegmentText() {
        currentSegmentText = ""
        lastProcessedTextLength = 0
    }
    
    func resetSegmentTracking() {
        currentSegmentText = ""
        lastProcessedTextLength = 0
    }
}

extension SFSpeechRecognizerAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .authorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }
} 