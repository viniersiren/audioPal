import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var micButtonScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var glowScale: CGFloat = 1.0

    var body: some View {
        NavigationView {
            ZStack(alignment: .leading) {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            if viewModel.messages.isEmpty && !viewModel.isRecording {
                                VStack(spacing: 16) {
                                    Spacer()
                                    Text("Tap the microphone to start recording")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    Text("Your speech will be converted to text using on-device recognition")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    if !viewModel.hasValidOpenAIKey {
                                        Text("Add OpenAI API key in settings for Whisper API transcription")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Button("Open Settings") {
                                            showSettings = true
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.bottom, 20)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.messages) { message in
                                        MessageBubble(message: message, viewModel: viewModel)
                                            .id(message.id)
                                    }

                                    if viewModel.isProcessingSegment {
                                        ProcessingSegmentBubble()
                                    }
                                }
                            }
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            if let lastMessage = viewModel.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showHistory.toggle()
                                }
                            }) {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(.blue)
                                    .rotationEffect(.degrees(showHistory ? 180 : 0))
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            HStack(spacing: 8) {
                                if viewModel.hasValidOpenAIKey {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                                Button(action: {
                                    showSettings = true
                                }) {
                                    Image(systemName: "gearshape")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }

                    if let error = viewModel.error {
                        ErrorView(error: error) {
                            viewModel.error = nil
                        }
                        .padding()
                    }

                    Divider()

                    HStack(alignment: .center, spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .scaleEffect(glowScale)
                                .opacity(glowOpacity)
                                .animation(.easeOut(duration: 1.5), value: glowScale)
                                .animation(.easeOut(duration: 1.5), value: glowOpacity)
                            
                            Button(action: {
                                if viewModel.isRecording {
                                    viewModel.stopRecording()
                                    stopMicAnimation()
                                } else {
                                    viewModel.startRecording { text in
                                    }
                                    startMicAnimation()
                                }
                            }) {
                                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(viewModel.isRecording ? Color.red : Color.blue)
                                    .clipShape(Circle())
                            }
                            .scaleEffect(micButtonScale)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: micButtonScale)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }

                if showHistory {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showHistory = false
                            }
                        }
                    
                    GeometryReader { geometry in
                        ConversationHistoryView(viewModel: viewModel)
                            .frame(width: geometry.size.width * 0.80)
                            .transition(.move(edge: .leading))
                            .zIndex(1)
                            .overlay(
                                Rectangle()
                                    .frame(width: 1)
                                    .foregroundColor(.blue.opacity(0.3)),
                                alignment: .trailing
                            )
                            .background(Color(UIColor.systemBackground))
                    }
                    .ignoresSafeArea(.container, edges: .vertical)
                }
            }
            .navigationTitle("Speech to Text")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSettings) {
                SettingsView(chatViewModel: viewModel)
            }
        }
    }
    
    private func startMicAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            micButtonScale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                micButtonScale = 1.0
            }
        }

        startGlowAnimation()
    }
    
    private func stopMicAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            micButtonScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.3)) {
            glowOpacity = 0.0
            glowScale = 1.0
        }
    }

    private func startGlowAnimation() {
        glowOpacity = 0.0
        glowScale = 1.0
        
        withAnimation(.easeOut(duration: 0.3)) {
            glowOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 1.5)) {
            glowScale = 2.0
        }
        
        withAnimation(.easeOut(duration: 1.5).delay(0.3)) {
            glowOpacity = 0.0
        }

        withAnimation(.easeOut(duration: 1.5).delay(1.5)) {
            glowScale = 1.0
        }
        
        if viewModel.isRecording {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                if viewModel.isRecording {
                    startGlowAnimation()
                }
            }
        }
    }
}

struct ProcessingSegmentBubble: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    
                    Text("Processing segment...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
            
            Spacer()
        }
        .padding(.horizontal)
    }
}
