import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showHistory = false
    @State private var micButtonScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var glowScale: CGFloat = 1.0

    var body: some View {
        NavigationView {
            ZStack(alignment: .leading) { // Align content to the left for the slide-in
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            if viewModel.messages.isEmpty {
                                VStack(spacing: 16) {
                                    Spacer()
                                    Text("Tap the microphone to start recording")
                                        .font(.headline)
                                                    .foregroundColor(.blue)
                                    Text("Your speech will be converted to text and saved")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
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
                                    if viewModel.isThinking {
                                        ThinkingBubble()
                                    }
                                    if viewModel.isProcessingSegment {
                                        ProcessingSegmentBubble()
                                    }
                                }
                            }
                            //.padding() // Removed padding here to let bubbles control their padding
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
                            //VoiceSelectionView(viewModel: viewModel) // deprecated 
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
                            // Glowing circle effect
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .scaleEffect(glowScale)
                                .opacity(glowOpacity)
                                .animation(.easeOut(duration: 1.5), value: glowScale)
                                .animation(.easeOut(duration: 1.5), value: glowOpacity)
                            
                                                        // Main mic button
                        Button(action: {
                                if viewModel.isRecording {
                                    viewModel.stopRecording()
                                    stopMicAnimation()
                                } else {
                            viewModel.startRecording { text in
                                        // Handle the transcribed text
                                        // print("Transcribed text: \(text)")
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

                // Conditional presentation of history view
                if showHistory {
                    // Semi-transparent overlay to capture taps outside history view
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showHistory = false
                            }
                        }
                    
                    GeometryReader { geometry in
                        ConversationHistoryView(viewModel: viewModel)
                            .frame(width: geometry.size.width * 0.48) // Changed to 40% width
                            .transition(.move(edge: .leading)) // Use move transition from leading edge
                            .zIndex(1) // Ensure it's above other content
                            // .offset(x: 0, y: geometry.safeAreaInsets.top + 56) // Position below the toolbar - managed by ZStack alignment
                            .overlay(
                                Rectangle()
                                    .frame(width: 1)
                                    .foregroundColor(.blue.opacity(0.3)),
                                alignment: .trailing
                            )
                            .background(Color(UIColor.systemBackground)) // Add background to history view
                    }
                    .ignoresSafeArea(.container, edges: .vertical)
                }


            }
            .navigationTitle("Speech to Text")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Animation Methods
    
    private func startMicAnimation() {
        // Button press animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            micButtonScale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                micButtonScale = 1.0
            }
        }
        
        // Start glowing animation
        startGlowAnimation()
    }
    
    private func stopMicAnimation() {
        // Reset button scale
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            micButtonScale = 1.0
        }
        
        // Stop glowing
        withAnimation(.easeOut(duration: 0.3)) {
            glowOpacity = 0.0
            glowScale = 1.0
        }
    }
    
    private func startGlowAnimation() {
        // Reset glow state
        glowOpacity = 0.0
        glowScale = 1.0
        
        // Start glow animation
        withAnimation(.easeOut(duration: 0.3)) {
            glowOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 1.5)) {
            glowScale = 2.0
        }
        
        // Fade out glow
        withAnimation(.easeOut(duration: 1.5).delay(0.3)) {
            glowOpacity = 0.0
        }
        
        // Reset glow scale
        withAnimation(.easeOut(duration: 1.5).delay(1.5)) {
            glowScale = 1.0
        }
        
        // Repeat animation if still recording
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
