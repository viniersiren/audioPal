import WidgetKit
import SwiftUI
import AVFoundation

struct AudioPalWidget: Widget {
    let kind: String = "audioPalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AudioPalWidgetProvider()) { entry in
            AudioPalWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("AudioPal")
        .description("Quick access to voice recording")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AudioPalWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AudioPalWidgetEntry {
        let widgetData = WidgetData()
        return AudioPalWidgetEntry(date: Date(), isRecording: widgetData.isRecording, canRecord: widgetData.canRecord, recordingDuration: widgetData.recordingDuration)
    }

    func getSnapshot(in context: Context, completion: @escaping (AudioPalWidgetEntry) -> ()) {
        let widgetData = WidgetData()
        let entry = AudioPalWidgetEntry(date: Date(), isRecording: widgetData.isRecording, canRecord: widgetData.canRecord, recordingDuration: widgetData.recordingDuration)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let widgetData = WidgetData()
        let currentDate = Date()
        
        let entry = AudioPalWidgetEntry(
            date: currentDate,
            isRecording: widgetData.isRecording,
            canRecord: widgetData.canRecord,
            recordingDuration: widgetData.recordingDuration
        )
        
        // Update more frequently when recording
        let updateInterval: TimeInterval = widgetData.isRecording ? 5 : 30
        let nextUpdate = Calendar.current.date(byAdding: .second, value: Int(updateInterval), to: currentDate)!
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct AudioPalWidgetEntry: TimelineEntry {
    let date: Date
    let isRecording: Bool
    let canRecord: Bool
    let recordingDuration: TimeInterval
}

struct AudioPalWidgetEntryView: View {
    var entry: AudioPalWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Background
            Color.blue.opacity(0.1)
            
            VStack(spacing: 8) {
                // Current time
                Text(formatTime(entry.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // App icon or title
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                
                // Recording status
                if entry.isRecording {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.0)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: entry.isRecording)
                            
                            Text("Recording...")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // Recording duration
                        Text(formatDuration(entry.recordingDuration))
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                } else {
                    Text("Tap to Record")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                // Permission status
                if !entry.canRecord {
                    Text("Permissions Required")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding()
        }
        .widgetURL(URL(string: "audiopal://record"))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview(as: .systemSmall) {
    AudioPalWidget()
} timeline: {
    AudioPalWidgetEntry(date: .now, isRecording: false, canRecord: true, recordingDuration: 0)
    AudioPalWidgetEntry(date: .now, isRecording: true, canRecord: true, recordingDuration: 125)
    AudioPalWidgetEntry(date: .now, isRecording: false, canRecord: false, recordingDuration: 0)
} 