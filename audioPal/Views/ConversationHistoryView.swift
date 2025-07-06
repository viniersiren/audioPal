import SwiftUI
import UniformTypeIdentifiers

struct ConversationHistoryView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFilter: DateFilter = .allTime
    @State private var searchText = ""
    @State private var showingExportSheet = false
    @State private var exportData: ExportData?
    @State private var showingDeleteAlert = false
    @State private var conversationToDelete: Int?
    
    enum DateFilter: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case allTime = "All Time"
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .today:
                let startOfDay = calendar.startOfDay(for: now)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                return (startOfDay, endOfDay)
            case .thisWeek:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
                return (startOfWeek, endOfWeek)
            case .thisMonth:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
                return (startOfMonth, endOfMonth)
            case .allTime:
                return (Date.distantPast, Date.distantFuture)
            }
        }
    }
    
    var filteredConversations: [Conversation] {
        let dateRange = selectedFilter.dateRange
        let filteredByDate = viewModel.conversations.filter { conversation in
            conversation.date >= dateRange.start && conversation.date < dateRange.end
        }
        
        let sortedConversations = filteredByDate.sorted { $0.date > $1.date } // Sort newest to oldest
        
        if searchText.isEmpty {
            return sortedConversations
        } else {
            return sortedConversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchText) ||
                conversation.messages.contains { message in
                    message.content.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search conversations...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    // Filter Picker
                    Picker("Date Filter", selection: $selectedFilter) {
                        ForEach(DateFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGroupedBackground))
                
                // Conversations List
                List {
                    // New Conversation Button
                    Button(action: {
                        viewModel.startNewConversation()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            Text("New Conversation")
                                .foregroundColor(.primary)
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.blue.opacity(0.1))
                    
                    // Export All Button
                    if !filteredConversations.isEmpty {
                        Button(action: {
                            exportAllConversations()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.green)
                                Text("Export All (\(filteredConversations.count))")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.green.opacity(0.1))
                    }
                    
                    // Conversations
                    ForEach(Array(filteredConversations.enumerated()), id: \.element.id) { index, conversation in
                        ConversationRow(
                            conversation: conversation,
                            originalIndex: viewModel.conversations.firstIndex(where: { $0.id == conversation.id }) ?? 0,
                            viewModel: viewModel,
                            dismiss: dismiss,
                            onExport: { exportConversation(conversation) },
                            onDelete: { deleteConversation(at: index) }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $exportData) { data in
            ExportSheet(exportData: data)
        }
        .alert("Delete Conversation", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let index = conversationToDelete {
                    deleteConversationConfirmed(at: index)
                }
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }
    }
    
    private func exportConversation(_ conversation: Conversation) {
        let exportText = formatConversationForExport(conversation)
        let filename = "\(conversation.title)_\(formatDate(conversation.date)).txt"
        exportData = ExportData(text: exportText, filename: filename)
    }
    
    private func exportAllConversations() {
        let exportText = formatAllConversationsForExport(filteredConversations)
        let filename = "Conversations_\(formatDate(Date())).txt"
        exportData = ExportData(text: exportText, filename: filename)
    }
    
    private func formatConversationForExport(_ conversation: Conversation) -> String {
        var text = "Conversation: \(conversation.title)\n"
        text += "Date: \(formatDate(conversation.date))\n"
        text += "Messages: \(conversation.messages.count)\n"
        text += "=" * 50 + "\n\n"
        
        for (index, message) in conversation.messages.enumerated() {
            let role = message.isUser ? "User" : "Assistant"
            let duration = message.recordingDuration.map { formatDuration($0) } ?? ""
            let method = message.transcriptionMethod?.rawValue ?? ""
            
            text += "[\(index + 1)] \(role)"
            if !duration.isEmpty {
                text += " (\(duration))"
            }
            if !method.isEmpty {
                text += " [\(method)]"
            }
            text += ":\n"
            text += message.content + "\n\n"
        }
        
        return text
    }
    
    private func formatAllConversationsForExport(_ conversations: [Conversation]) -> String {
        var text = "AudioPal Conversations Export\n"
        text += "Generated: \(formatDate(Date()))\n"
        text += "Total Conversations: \(conversations.count)\n"
        text += "=" * 50 + "\n\n"
        
        for conversation in conversations {
            text += formatConversationForExport(conversation)
            text += "\n" + "=" * 50 + "\n\n"
        }
        
        return text
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func deleteConversation(at index: Int) {
        conversationToDelete = index
        showingDeleteAlert = true
    }
    
    private func deleteConversationConfirmed(at index: Int) {
        guard index < filteredConversations.count else { return }
        let conversationToDelete = filteredConversations[index]
        
        if let originalIndex = viewModel.conversations.firstIndex(where: { $0.id == conversationToDelete.id }) {
            viewModel.conversations.remove(at: originalIndex)
            viewModel.persistChatHistory()
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let originalIndex: Int
    @ObservedObject var viewModel: ChatViewModel
    let dismiss: DismissAction
    let onExport: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack {
                        Text(conversation.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("\(conversation.messages.count) messages")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if let lastMessage = conversation.messages.last,
                           let duration = lastMessage.recordingDuration {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(formatDuration(duration))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    Button(action: onExport) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            
            // Preview of last message
            if let lastMessage = conversation.messages.last {
                Text(lastMessage.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.loadConversation(at: originalIndex)
            dismiss()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ExportData: Identifiable {
    let id = UUID()
    let text: String
    let filename: String
}

struct ExportSheet: View {
    let exportData: ExportData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Export Conversation")
                    .font(.headline)
                    .padding()
                
                ScrollView {
                    Text(exportData.text)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .textSelection(.enabled)
                }
                
                HStack {
                    Button("Copy to Clipboard") {
                        UIPasteboard.general.string = exportData.text
                    }
                    .buttonStyle(.borderedProminent)
                    
                    ShareLink(
                        item: exportData.text,
                        preview: SharePreview(
                            exportData.filename,
                            image: "doc.text"
                        )
                    ) {
                        Text("Share")
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Extension to create repeated strings
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
} 