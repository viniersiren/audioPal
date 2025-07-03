import Foundation

class DeviceManager {
    static let shared = DeviceManager()
    private let fileManager = FileManager.default
    private let chatHistoryFileName = "chat_history.json"
    
    private init() {}
    
    private var chatHistoryURL: URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return nil
        }
        let url = documentsDirectory.appendingPathComponent(chatHistoryFileName)
        print("📁 Chat history file path: \(url.path)")
        return url
    }
    
    func saveChatHistory(_ conversations: [Conversation]) {
        print("\n=== Saving Chat History ===")
        print("📊 Number of conversations to save: \(conversations.count)")
        conversations.forEach { conversation in
            print("💬 Conversation: '\(conversation.title)' with \(conversation.messages.count) messages")
        }
        
        guard let url = chatHistoryURL else {
            print("❌ No valid URL for saving chat history")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(conversations)
            try data.write(to: url)
            print("✅ Chat history saved successfully")
            print("📊 Saved data size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
        } catch {
            print("❌ Failed to save chat history: \(error)")
        }
    }
    
    func loadChatHistory() -> [Conversation]? {
        print("\n=== Loading Chat History ===")
        guard let url = chatHistoryURL else {
            print("❌ No valid URL for loading chat history")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            print("📊 Loaded data size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let conversations = try decoder.decode([Conversation].self, from: data)
            print("✅ Chat history loaded successfully")
            print("📊 Number of conversations loaded: \(conversations.count)")
            conversations.forEach { conversation in
                print("💬 Loaded conversation: '\(conversation.title)' with \(conversation.messages.count) messages")
            }
            return conversations
        } catch {
            print("❌ Failed to load chat history: \(error)")
            return nil
        }
    }
    
    func clearChatHistory() {
        print("\n=== Clearing Chat History ===")
        guard let url = chatHistoryURL else {
            print("❌ No valid URL for clearing chat history")
            return
        }
        
        do {
            try fileManager.removeItem(at: url)
            print("✅ Chat history cleared successfully")
        } catch {
            print("❌ Failed to clear chat history: \(error)")
        }
    }
} 