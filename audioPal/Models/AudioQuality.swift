import Foundation
import AVFoundation

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