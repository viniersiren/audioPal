//
//  audioPalWidget.swift
//  audioPalWidget
//
//  Created by Devin Studdard on 7/5/25.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Data Manager

struct WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private let userDefaults = UserDefaults(suiteName: "group.testaaa.audioPal")
    
    private init() {
        print("🔧 WidgetDataManager: Initialized with suite: group.testaaa.audioPal")
    }
    
    // MARK: - Recording Status
    
    func updateRecordingStatus(isRecording: Bool) {
        print("🔧 WidgetDataManager: Updating recording status to \(isRecording)")
        userDefaults?.set(isRecording, forKey: "isRecording")
        WidgetCenter.shared.reloadAllTimelines()
        print("🔧 WidgetDataManager: Recording status saved")
    }

    func getRecordingStatus() -> Bool {
        let status = userDefaults?.bool(forKey: "isRecording") ?? false
        print("🔧 WidgetDataManager: Getting recording status: \(status)")
        return status
    }
    
    // MARK: - Permission Status
    
    func updatePermissionStatus(canRecord: Bool) {
        print("🔧 WidgetDataManager: Updating canRecord to \(canRecord)")
        userDefaults?.set(canRecord, forKey: "canRecord")
        WidgetCenter.shared.reloadAllTimelines()
        print("🔧 WidgetDataManager: CanRecord saved")
    }
    
    func getPermissionStatus() -> Bool {
        let canRecord = userDefaults?.bool(forKey: "canRecord") ?? true
        print("🔧 WidgetDataManager: Getting canRecord: \(canRecord)")
        return canRecord
    }
    
    // MARK: - Recording Duration
    
    func updateRecordingDuration(_ duration: TimeInterval) {
        print("🔧 WidgetDataManager: Updating recording duration to \(duration)")
        userDefaults?.set(duration, forKey: "recordingDuration")
        WidgetCenter.shared.reloadAllTimelines()
        print("🔧 WidgetDataManager: Recording duration saved")
    }
    
    func getRecordingDuration() -> TimeInterval {
        let duration = userDefaults?.double(forKey: "recordingDuration") ?? 0.0
        print("🔧 WidgetDataManager: Getting recording duration: \(duration)")
        return duration
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
        
        print("🔧 WidgetData: Initialized with - isRecording: \(isRecording), canRecord: \(canRecord), duration: \(recordingDuration), lastUpdate: \(lastUpdateTime)")
    }
}

// MARK: - Widget Entry

struct AudioPalWidgetEntry: TimelineEntry {
    let date: Date
    let isRecording: Bool
    let canRecord: Bool
    let recordingDuration: TimeInterval
}

// MARK: - Widget Provider

struct AudioPalWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AudioPalWidgetEntry {
        print("🔧 Widget: Creating placeholder")
        // Placeholder for widget gallery
        let entry = AudioPalWidgetEntry(
            date: Date(),
            isRecording: false,
            canRecord: true,
            recordingDuration: 0
        )
        print("🔧 Widget: Placeholder created - isRecording: \(entry.isRecording), duration: \(entry.recordingDuration)")
        return entry
    }

    func getSnapshot(in context: Context, completion: @escaping (AudioPalWidgetEntry) -> ()) {
        print("🔧 Widget: Creating snapshot")
        // Get current data for widget preview
        let widgetData = WidgetData()
        print("🔧 Widget: WidgetData - isRecording: \(widgetData.isRecording), canRecord: \(widgetData.canRecord), duration: \(widgetData.recordingDuration)")
        
        let entry = AudioPalWidgetEntry(
            date: Date(),
            isRecording: widgetData.isRecording,
            canRecord: widgetData.canRecord,
            recordingDuration: widgetData.recordingDuration
        )
        print("🔧 Widget: Snapshot created - isRecording: \(entry.isRecording), duration: \(entry.recordingDuration)")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        print("🔧 Widget: Creating timeline")
        // Get current data
        let widgetData = WidgetData()
        let currentDate = Date()
        
        print("🔧 Widget: WidgetData - isRecording: \(widgetData.isRecording), canRecord: \(widgetData.canRecord), duration: \(widgetData.recordingDuration)")
        
        let entry = AudioPalWidgetEntry(
            date: currentDate,
            isRecording: widgetData.isRecording,
            canRecord: widgetData.canRecord,
            recordingDuration: widgetData.recordingDuration
        )
        
        // Update more frequently when recording or when there are recent changes
        let lastUpdate = widgetData.lastUpdateTime
        let timeSinceLastUpdate = currentDate.timeIntervalSince(lastUpdate)
        
        let updateInterval: TimeInterval
        if widgetData.isRecording {
            updateInterval = 5 // Update every 5 seconds when recording
        } else if timeSinceLastUpdate < 60 {
            updateInterval = 10 // Update every 10 seconds for recent changes
        } else {
            updateInterval = 30 // Update every 30 seconds normally
        }
        
        let nextUpdate = Calendar.current.date(byAdding: .second, value: Int(updateInterval), to: currentDate)!
        
        print("🔧 Widget: Timeline created - isRecording: \(entry.isRecording), duration: \(entry.recordingDuration), nextUpdate: \(updateInterval)s")
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Entry View

struct AudioPalWidgetEntryView: View {
    var entry: AudioPalWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let _ = print("🔧 Widget: Rendering entry view - isRecording: \(entry.isRecording), duration: \(entry.recordingDuration), family: \(family)")
        
        return VStack {
            // Content based on widget family
            switch family {
            case .systemSmall:
                smallWidgetContent
            case .systemMedium:
                mediumWidgetContent
            case .systemLarge:
                largeWidgetContent
            default:
                smallWidgetContent
            }
        }
        .widgetURL(URL(string: "audiopal://record"))
    }
    
    // MARK: - Widget Content Views
    
    @ViewBuilder
    private var smallWidgetContent: some View {
        VStack(spacing: 8) {
            // Recording status icon
            if entry.isRecording {
                // Recording indicator with animation
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 40, height: 40)
                    
                    // Pulsing animation
                    Circle()
                        .stroke(Color.primary, lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .scaleEffect(entry.isRecording ? 1.2 : 1.0)
                        .opacity(entry.isRecording ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: entry.isRecording)
                    
                    Image(systemName: "mic.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
                
                // Recording duration
                Text(formatDuration(entry.recordingDuration))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            } else {
                // Microphone button (not recording)
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "mic")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
                
                // Status text
                Text(entry.canRecord ? "Tap to Record" : "No Permission")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // App name
            Text("AudioPal")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var mediumWidgetContent: some View {
        HStack(spacing: 16) {
            // Left side - Icon and status
            VStack(spacing: 8) {
                if entry.isRecording {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .stroke(Color.primary, lineWidth: 3)
                            .frame(width: 50, height: 50)
                            .scaleEffect(entry.isRecording ? 1.2 : 1.0)
                            .opacity(entry.isRecording ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: entry.isRecording)
                        
                        Image(systemName: "mic.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold))
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "mic")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .medium))
                    }
                }
                
                Text("AudioPal")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            // Right side - Status and duration
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.isRecording ? "Recording..." : "Ready to Record")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                if entry.isRecording {
                    Text("Duration: \(formatDuration(entry.recordingDuration))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Text(entry.canRecord ? "Tap to start recording" : "Microphone permission needed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var largeWidgetContent: some View {
        VStack(spacing: 16) {
            // Top section - Icon and main status
            VStack(spacing: 12) {
                if entry.isRecording {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .stroke(Color.primary, lineWidth: 4)
                            .frame(width: 60, height: 60)
                            .scaleEffect(entry.isRecording ? 1.2 : 1.0)
                            .opacity(entry.isRecording ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: entry.isRecording)
                        
                        Image(systemName: "mic.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 24, weight: .bold))
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "mic")
                            .foregroundColor(.white)
                            .font(.system(size: 24, weight: .medium))
                    }
                }
                
                Text(entry.isRecording ? "Recording in Progress" : "AudioPal")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            // Middle section - Status details
            VStack(spacing: 8) {
                if entry.isRecording {
                    Text("Duration: \(formatDuration(entry.recordingDuration))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Tap to stop recording")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Text(entry.canRecord ? "Ready to Record" : "Permission Required")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(entry.canRecord ? "Tap to start recording" : "Enable microphone access in Settings")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Widget Configuration

struct audioPalWidget: Widget {
    let kind: String = "audioPalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AudioPalWidgetProvider()) { entry in
            AudioPalWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("AudioPal")
        .description("Quick access to start/stop recording")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    audioPalWidget()
} timeline: {
    AudioPalWidgetEntry(date: .now, isRecording: false, canRecord: true, recordingDuration: 0)
    AudioPalWidgetEntry(date: .now, isRecording: true, canRecord: true, recordingDuration: 65)
}

#Preview(as: .systemMedium) {
    audioPalWidget()
} timeline: {
    AudioPalWidgetEntry(date: .now, isRecording: false, canRecord: true, recordingDuration: 0)
    AudioPalWidgetEntry(date: .now, isRecording: true, canRecord: true, recordingDuration: 125)
}

#Preview(as: .systemLarge) {
    audioPalWidget()
} timeline: {
    AudioPalWidgetEntry(date: .now, isRecording: false, canRecord: true, recordingDuration: 0)
    AudioPalWidgetEntry(date: .now, isRecording: true, canRecord: true, recordingDuration: 245)
}
