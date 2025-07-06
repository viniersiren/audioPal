import SwiftUI

struct MessageBubble: View {
    let message: Message
    @ObservedObject var viewModel: ChatViewModel
    @State private var showCopiedToast: Bool = false
    
    private var shouldShowError: Bool {
        message.isError || viewModel.error != nil
    }
    
    private var backgroundColor: Color {
        message.isUser ? Color.blue : Color.gray.opacity(0.2)
    }
    
    private var textColor: Color {
        message.isUser ? .white : .primary
    }
    
    private var alignment: HorizontalAlignment {
        message.isUser ? .trailing : .leading
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: alignment, spacing: 4) {
                messageContent
                
                messageActions
            }
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal)
    }
    
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(message.content)
                    .strikethrough(shouldShowError)
                
                Spacer()
                
                // Play button inside the message
                playButton
            }
            
            HStack(spacing: 8) {
                if let duration = message.recordingDuration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.7))
                }
                
                if let method = message.transcriptionMethod {
                    HStack(spacing: 4) {
                        Image(systemName: method.icon)
                            .font(.caption)
                        Text(method.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(method.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(method.color.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .foregroundColor(textColor)
        .cornerRadius(20)
        .opacity(1.0)
        .animation(.easeIn(duration: 0.1), value: message.content)
        .onTapGesture {
            // Prevent tap from propagating to parent view
        }
        .overlay(copiedToast)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "⏱️ %02d:%02d", minutes, seconds)
    }
    
    private var messageActions: some View {
        HStack(spacing: 16) {
            if !message.isUser {
                // For non-user messages, show copy button below the message
                copyButton
            }
        }
        .padding(.top, 8)
    }
    
    private var playButton: some View {
        Button(action: {
            if viewModel.synthesizer.isSpeaking {
                viewModel.stopSpeaking()
            } else {
                viewModel.speakMessage(message.content)
            }
        }) {
            Group {
                if viewModel.synthesizer.isSpeaking {
                    // Loading spinner while speaking
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                } else {
                    // Play icon when not speaking
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(textColor)
                }
            }
            .frame(width: 32, height: 32)
            .background(textColor.opacity(0.1))
            .clipShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(viewModel.synthesizer.isSpeaking) // Prevent re-clicking while speaking
    }
    
    private var copyButton: some View {
        Button(action: {
            UIPasteboard.general.string = message.content
            withAnimation {
                showCopiedToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showCopiedToast = false
                }
            }
        }) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var copiedToast: some View {
        Group {
            if showCopiedToast {
                Text("Copied!")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .offset(y: -30)
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/*
 MARKDOWN UI IMPLEMENTATION
 -------------------------
 To implement markdown support, add the following:

 1. Add to project dependencies:
    - Package URL: https://github.com/gonzalezreal/swift-markdown-ui
    - Version: Up to Next Major (2.4.1)

 2. Import statement:
    import MarkdownUI

 3. Replace Text view with Markdown view:
    Markdown(message.content)
        .markdownTheme(.custom(
            text: TextStyle(
                font: .body,
                foregroundColor: message.isUser ? .white : .primary
            ),
            heading1: TextStyle(
                font: .system(size: 28, weight: .bold),
                foregroundColor: message.isUser ? .white : .primary
            ),
            heading2: TextStyle(
                font: .system(size: 24, weight: .bold),
                foregroundColor: message.isUser ? .white : .primary
            ),
            heading3: TextStyle(
                font: .system(size: 20, weight: .bold),
                foregroundColor: message.isUser ? .white : .primary
            ),
            code: TextStyle(
                font: .system(.body, design: .monospaced),
                foregroundColor: message.isUser ? .white : .primary
            ),
            blockquote: TextStyle(
                font: .body,
                foregroundColor: message.isUser ? .white.opacity(0.8) : .primary.opacity(0.8)
            )
        ))
        .strikethrough(message.isError)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
*/ 
