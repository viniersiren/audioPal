import Foundation

struct PendingTranscription {
    let id: UUID
    let audioFileURL: URL
    let originalText: String
    let duration: TimeInterval
    let timestamp: Date
    var retryCount: Int = 0
} 