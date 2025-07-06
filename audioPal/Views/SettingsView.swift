import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @State private var apiKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("OpenAI Whisper API (Optional)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.headline)
                        
                        SecureField("Enter your OpenAI API key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Your API key is stored securely in Keychain and never leaves your device. This enables Whisper API transcription for better accuracy. Without it, the app uses on-device transcription.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Button("Save API Key") {
                            saveAPIKey()
                        }
                        .disabled(apiKey.isEmpty)
                        
                        Spacer()
                        
                        if chatViewModel.hasValidOpenAIKey {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section(header: Text("Audio Quality Settings")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Recording Quality", selection: $chatViewModel.audioManager.audioQuality) {
                            ForEach(AudioQuality.allCases, id: \.self) { quality in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(quality.rawValue)
                                            .font(.headline)
                                        Spacer()
                                        Text(quality.estimatedFileSize)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(quality.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(quality)
                            }
                        }
                        .pickerStyle(.wheel)
                        .onChange(of: chatViewModel.audioManager.audioQuality) { newQuality in
                            chatViewModel.audioManager.saveAudioQuality(newQuality)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Settings:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sample Rate")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(chatViewModel.audioManager.audioQuality.settings[AVSampleRateKey] as? Int ?? 0) Hz")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Bit Rate")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(chatViewModel.audioManager.audioQuality.settings[AVEncoderBitRateKey] as? Int ?? 0) kbps")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Channels")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(chatViewModel.audioManager.audioQuality.settings[AVNumberOfChannelsKey] as? Int ?? 1)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("About")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AudioPal")
                            .font(.headline)
                        Text("Speech-to-Text App")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Version 1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("API Key", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadCurrentAPIKey()
            }
        }
    }
    
    private func loadCurrentAPIKey() {
        if let currentKey = chatViewModel.whisperAPIManager.openAIKey {
            apiKey = currentKey
        }
    }
    
    private func saveAPIKey() {
        let success = chatViewModel.whisperAPIManager.saveOpenAIKey(apiKey)
        
        if success {
            alertMessage = "API key saved successfully! You can now use speech-to-text features."
        } else {
            alertMessage = "Failed to save API key. Please try again."
        }
        
        showingAlert = true
    }
}

#Preview {
    SettingsView(chatViewModel: ChatViewModel())
} 