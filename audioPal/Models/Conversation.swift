import Foundation

struct Conversation: Identifiable, Codable {
    let id: UUID
    let title: String
    let messages: [Message]
    let date: Date
    
    init(title: String, messages: [Message], date: Date) {
        self.id = UUID()
        self.title = title
        self.messages = messages
        self.date = date
    }
} 