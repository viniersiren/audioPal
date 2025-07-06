import Foundation

enum ChatError: LocalizedError {
    case permissionDenied
    case speechRecognitionError(String)
    case audioSessionError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone or Speech Recognition permission denied"
        case .speechRecognitionError(let message):
            return "Speech recognition error: \(message)"
        case .audioSessionError(let message):
            return "Audio session error: \(message)"
        case .unknownError(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Go to Settings > Privacy & Security > Microphone and Speech Recognition to enable access for this app."
        case .speechRecognitionError:
            return "Please try again or check your internet connection."
        case .audioSessionError:
            return "Please try again or restart the app."
        case .unknownError:
            return "Please try again or contact support if the problem persists."
        }
    }
}

