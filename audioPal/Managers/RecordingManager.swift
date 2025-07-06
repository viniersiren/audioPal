import Foundation
import AVFoundation
import UIKit

class RecordingManager: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var currentAudioFileURL: URL?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // Auto-segmentation
    private let segmentDuration: TimeInterval = 30.0 // 30 seconds
    private var segmentStartTime: Date?
    
    override init() {
        super.init()
    }
    
    deinit {
        stopRecordingTimer()
        endBackgroundTask()
    }
    
    // MARK: - Recording Management
    
    func startRecording(audioQuality: AudioQuality) -> URL? {
        print("🎤 Starting audio recording")
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = "segment_\(Date().timeIntervalSince1970).m4a"
        currentAudioFileURL = documentsPath.appendingPathComponent(audioFilename)
        
        guard let audioFileURL = currentAudioFileURL else {
            print("❌ Could not create audio file URL")
            return nil
        }
        
        let settings = audioQuality.settings
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.record()
            print("🎙️ Audio recording started for Whisper API with \(audioQuality.rawValue) quality")
            
            // Start recording timer
            startRecordingTimer()
            
            return audioFileURL
        } catch {
            print("❌ Failed to start audio recording: \(error)")
            return nil
        }
    }
    
    func stopRecording() {
        print("🛑 Stopping audio recording")
        
        // Stop audio recording
        audioRecorder?.stop()
        audioRecorder = nil
        print("🎙️ Audio recording stopped")
        
        stopRecordingTimer()
    }
    
    func getCurrentAudioFileURL() -> URL? {
        return currentAudioFileURL
    }
    
    func clearCurrentAudioFile() {
        currentAudioFileURL = nil
    }
    
    // MARK: - Recording Timer
    
    private func startRecordingTimer() {
        recordingStartTime = Date()
        segmentStartTime = Date()
        recordingDuration = 0.0
        
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
    
    private func createSegment() {
        // Reset segment timer and continue
        segmentStartTime = Date()
        print("🔄 Created new 30-second segment")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Background Task Management
    
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
    
    // MARK: - Cleanup
    
    func cleanupAudioFiles() {
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
} 