import SwiftUI

struct ConversationHistoryView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Button(action: {
                    viewModel.startNewConversation()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                        Text("New Conversation")
                            .foregroundColor(.primary)
                    }
                }
                
                ForEach(viewModel.conversations.indices, id: \.self) { index in
                    Button(action: {
                        viewModel.loadConversation(at: index)
                        dismiss()
                    }) {
                        HStack {
                            Text(viewModel.conversations[index].title)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(viewModel.conversations[index].date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
} 