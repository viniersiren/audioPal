import Foundation
import WidgetKit

struct WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private let userDefaults = UserDefaults(suiteName: "group.testaaa.audioPal")
    
    private init() {}
    
    // MARK: - Recording Status
    
    func updateRecordingStatus(isRecording: Bool) {
        userDefaults?.set(isRecording, forKey: "isRecording")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func getRecordingStatus() -> Bool {
        return userDefaults?.bool(forKey: "isRecording") ?? false
    }
    
    // MARK: - Permission Status
    
    func updatePermissionStatus(canRecord: Bool) {
        userDefaults?.set(canRecord, forKey: "canRecord")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func getPermissionStatus() -> Bool {
        return userDefaults?.bool(forKey: "canRecord") ?? true
    }
    
    // MARK: - Recording Duration
    
    func updateRecordingDuration(_ duration: TimeInterval) {
        userDefaults?.set(duration, forKey: "recordingDuration")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func getRecordingDuration() -> TimeInterval {
        return userDefaults?.double(forKey: "recordingDuration") ?? 0.0
    }
    
    // MARK: - Last Update Time
    
    func updateLastUpdateTime() {
        userDefaults?.set(Date(), forKey: "lastUpdateTime")
    }
    
    func getLastUpdateTime() -> Date {
        return userDefaults?.object(forKey: "lastUpdateTime") as? Date ?? Date()
    }
    
    // MARK: - Widget Configuration
    
    func setWidgetEnabled(_ enabled: Bool) {
        userDefaults?.set(enabled, forKey: "widgetEnabled")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func isWidgetEnabled() -> Bool {
        return userDefaults?.bool(forKey: "widgetEnabled") ?? true
    }
}

// MARK: - Widget Data Model

struct WidgetData {
    let isRecording: Bool
    let canRecord: Bool
    let recordingDuration: TimeInterval
    let lastUpdateTime: Date
    
    init() {
        let manager = WidgetDataManager.shared
        self.isRecording = manager.getRecordingStatus()
        self.canRecord = manager.getPermissionStatus()
        self.recordingDuration = manager.getRecordingDuration()
        self.lastUpdateTime = manager.getLastUpdateTime()
    }
} 