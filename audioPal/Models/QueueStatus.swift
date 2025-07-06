import Foundation

enum QueueStatus {
    case idle
    case processing(count: Int)
    case queued(count: Int)
    case offline
    
    var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .processing(let count):
            return "Processing \(count) segments"
        case .queued(let count):
            return "\(count) segments queued"
        case .offline:
            return "Offline - segments queued"
        }
    }
} 