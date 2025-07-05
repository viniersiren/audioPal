import Foundation
import SwiftUI

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
            case .whisper:
                return "sparkles"
            case .local:
                return "iphone"
            }
        }
        
        var color: Color {
            switch self {
            case .whisper:
                return .orange
            case .local:
                return .blue
            }
        }
    }
    
    init(content: String, isUser: Bool, isThinking: Bool = false, isError: Bool = false, audioURL: URL? = nil, recordingDuration: TimeInterval? = nil, transcriptionMethod: TranscriptionMethod? = nil) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.isThinking = isThinking
        self.isError = isError
        self.audioURL = audioURL
        self.recordingDuration = recordingDuration
        self.transcriptionMethod = transcriptionMethod
    }
}

extension Message: Equatable {
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isUser == rhs.isUser &&
        lhs.isThinking == rhs.isThinking &&
        lhs.isError == rhs.isError &&
        lhs.audioURL == rhs.audioURL &&
        lhs.recordingDuration == rhs.recordingDuration &&
        lhs.transcriptionMethod == rhs.transcriptionMethod
    }
} 
