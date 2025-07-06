import Foundation

class WhisperAPIManager: ObservableObject {
    private var whisperRetryCount: Int = 0
    private let maxWhisperRetries: Int = 5
    private var retryAudioFileURL: URL?
    
    // MARK: - Configuration
    
    var openAIKey: String? {
        return KeychainManager.shared.getOpenAIKey()
    }
    
    var hasValidOpenAIKey: Bool {
        guard let key = openAIKey else { return false }
        return !key.isEmpty && key != "YOUR_OPENAI_KEY"
    }
    
    func saveOpenAIKey(_ key: String) -> Bool {
        let success = KeychainManager.shared.saveOpenAIKey(key)
        if success {
            print("✅ OpenAI API key saved to Keychain")
        } else {
            print("❌ Failed to save OpenAI API key to Keychain")
        }
        return success
    }
    
    // MARK: - Whisper API Transcription
    
    func transcribeAudioWithWhisper(audioFileURL: URL, completion: @escaping (String?) -> Void) {
        guard hasValidOpenAIKey, let apiKey = openAIKey else {
            completion(nil)
            return
        }
        
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        
        do {
            let audioData = try Data(contentsOf: audioFileURL)
            body.append(audioData)
        } catch {
            print("❌ Failed to read audio file: \(error)")
            completion(nil)
            return
        }
        
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🎤 Sending audio to Whisper API (attempt \(whisperRetryCount + 1)/\(maxWhisperRetries))")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Whisper API error: \(error)")
                self.handleWhisperFailure(completion: completion)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    self.whisperRetryCount = 0
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data ?? Data()) as? [String: Any],
                           let text = json["text"] as? String {
                            print("✅ Whisper transcription successful")
                            completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        } else {
                            print("❌ Unexpected Whisper response format")
                            completion(nil)
                        }
                    } catch {
                        print("❌ Failed to parse Whisper response: \(error)")
                        completion(nil)
                    }
                } else {
                    print("❌ Whisper API HTTP error: \(httpResponse.statusCode)")
                    self.handleWhisperFailure(completion: completion)
                }
            } else {
                print("❌ No HTTP response from Whisper API")
                self.handleWhisperFailure(completion: completion)
            }
        }.resume()
    }
    
    private func handleWhisperFailure(completion: @escaping (String?) -> Void) {
        whisperRetryCount += 1
        
        if whisperRetryCount >= maxWhisperRetries {
            print("❌ Whisper API failed \(maxWhisperRetries) times - falling back to local transcription")
            whisperRetryCount = 0
            retryAudioFileURL = nil
            completion(nil)
        } else {
            let delay = pow(2.0, Double(whisperRetryCount - 1))
            print("⏳ Retrying Whisper API in \(delay) seconds...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, let audioFileURL = self.retryAudioFileURL else {
                    print("❌ No audio file available for retry")
                    completion(nil)
                    return
                }
                
                self.transcribeAudioWithWhisper(audioFileURL: audioFileURL, completion: completion)
            }
        }
    }
    
    // MARK: - Audio File Management
    
    func setRetryAudioFile(_ url: URL) {
        retryAudioFileURL = url
    }
    
    func clearRetryAudioFile() {
        retryAudioFileURL = nil
    }
    
    // MARK: - Status Information
    
    var networkStatusDescription: String {
        if !hasValidOpenAIKey {
            return "No API key - using local transcription"
        } else {
            return "Online - using Whisper API"
        }
    }
} 