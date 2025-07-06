import Foundation
import SwiftUI

class URLSchemeHandler: ObservableObject {
    static let shared = URLSchemeHandler()
    
    @Published var shouldStartRecording = false
    @Published var shouldStopRecording = false
    
    private init() {}
    
    func handleURL(_ url: URL) {
        print("🔗 Handling URL: \(url)")
        
        guard url.scheme == "audiopal" else {
            print("❌ Invalid URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        switch url.host {
        case "record":
            handleRecordAction(url: url)
        case "stop":
            handleStopAction(url: url)
        case "settings":
            handleSettingsAction(url: url)
        default:
            print("❌ Unknown URL host: \(url.host ?? "nil")")
        }
    }
    
    private func handleRecordAction(url: URL) {
        print("🎤 Widget requested recording start")
        DispatchQueue.main.async {
            self.shouldStartRecording = true
        }
    }
    
    private func handleStopAction(url: URL) {
        print("🛑 Widget requested recording stop")
        DispatchQueue.main.async {
            self.shouldStopRecording = true
        }
    }
    
    private func handleSettingsAction(url: URL) {
        print("⚙️ Widget requested settings")
        // Open settings or show settings view
    }
    
    func resetActions() {
        shouldStartRecording = false
        shouldStopRecording = false
    }
}

// MARK: - URL Scheme Constants

struct URLScheme {
    static let scheme = "audiopal"
    
    struct Actions {
        static let record = "record"
        static let stop = "stop"
        static let settings = "settings"
    }
    
    static func recordURL() -> URL {
        return URL(string: "\(scheme)://\(Actions.record)")!
    }
    
    static func stopURL() -> URL {
        return URL(string: "\(scheme)://\(Actions.stop)")!
    }
    
    static func settingsURL() -> URL {
        return URL(string: "\(scheme)://\(Actions.settings)")!
    }
} 