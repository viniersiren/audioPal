import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    var content: String
    let isUser: Bool
    let isThinking: Bool
    let isError: Bool
    var audioURL: URL?
    var recordingDuration: TimeInterval?
    
    init(content: String, isUser: Bool, isThinking: Bool = false, isError: Bool = false, audioURL: URL? = nil, recordingDuration: TimeInterval? = nil) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.isThinking = isThinking
        self.isError = isError
        self.audioURL = audioURL
        self.recordingDuration = recordingDuration
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
        lhs.recordingDuration == rhs.recordingDuration
    }
} 
