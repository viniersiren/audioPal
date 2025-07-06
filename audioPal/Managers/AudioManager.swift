import Foundation
import AVFoundation
import UIKit

class AudioManager: NSObject, ObservableObject {
    @Published var audioLevel: Float = 0.0
    @Published var currentAudioRoute: String = "Unknown"
    @Published var microphonePermissionStatus: AVAudioSession.RecordPermission = .undetermined
    @Published var audioQuality: AudioQuality = .high
    
    private var audioLevelTimer: Timer?
    private var audioRouteObserver: NSObjectProtocol?
    private var audioInterruptionObserver: NSObjectProtocol?
    
    override init() {
        super.init()
        loadAudioQuality()
        setupAudioRouteMonitoring()
        setupAudioInterruptionMonitoring()
        updateAudioRouteDisplay()
        checkMicrophonePermissionStatus()
    }
    
    deinit {
        stopAudioLevelMonitoring()
        
        if let observer = audioRouteObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        if let observer = audioInterruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Audio Quality Management
    
    func saveAudioQuality(_ quality: AudioQuality) {
        UserDefaults.standard.set(quality.rawValue, forKey: "audioQuality")
        audioQuality = quality
        print("✅ Audio quality saved: \(quality.rawValue)")
    }
    
    private func loadAudioQuality() {
        if let savedQuality = UserDefaults.standard.string(forKey: "audioQuality"),
           let quality = AudioQuality(rawValue: savedQuality) {
            audioQuality = quality
            print("✅ Audio quality loaded: \(quality.rawValue)")
        } else {
            audioQuality = .high
            print("✅ Using default audio quality: High")
        }
    }
    
    // MARK: - Audio Session Management
    
    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configure audio session to support multiple input sources:
            // - .playAndRecord: Allows both recording and playback
            // - .defaultToSpeaker: Audio output goes to speaker (not earpiece)
            // - .allowBluetooth: Enables recording from Bluetooth devices like AirPods, headphones, etc.
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured successfully for background recording")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated")
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
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
                case .oldDeviceUnavailable:
                    print("🎧 Old audio device unavailable")
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
                
                self.updateAudioRouteDisplay()
            }
        }
        print("🎧 Audio route monitoring started")
    }
    
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
               let reasonValue = userInfo[AVAudioSessionInterruptionReasonKey] as? NSNumber {
                
                let reason = reasonValue.uintValue
                switch reason {
                case 1:
                    print("📱 Audio interruption began")
                case 0:
                    print("📱 Audio interruption ended")
                default:
                    print("🎧 Unknown audio interruption reason: \(reason)")
                }
            }
        }
        print("🎧 Audio interruption monitoring started")
    }
    
    // MARK: - Permission Management
    
    private func checkMicrophonePermissionStatus() {
        microphonePermissionStatus = AVAudioSession.sharedInstance().recordPermission
        print("🔐 Microphone permission status: \(microphonePermissionStatus.description)")
    }
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        if microphonePermissionStatus == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.microphonePermissionStatus = granted ? .granted : .denied
                    print("🎤 Microphone permission: \(granted ? "granted" : "denied")")
                    completion(granted)
                }
            }
        } else {
            completion(microphonePermissionStatus == .granted)
        }
    }
    
    func hasMicrophonePermission() -> Bool {
        return microphonePermissionStatus == .granted
    }
    
    // MARK: - Audio Level Monitoring
    
    func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }
    
    private func updateAudioLevel() {
        audioLevel = 0.0
    }
}

// MARK: - Permission Status Extensions

extension AVAudioSession.RecordPermission {
    var description: String {
        switch self {
        case .undetermined:
            return "Undetermined"
        case .denied:
            return "Denied"
        case .granted:
            return "Granted"
        @unknown default:
            return "Unknown"
        }
    }
} 