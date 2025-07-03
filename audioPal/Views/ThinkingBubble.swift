import SwiftUI

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.5),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
                }
            )
            .onAppear {
                phase = 1
            }
    }
}

struct ThinkingBubble: View {
    var body: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 4) {
                Text("Thinking")
                    .padding(0)
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Color.gray.opacity(0.1)
                    .shimmer(
                        configuration: ShimmerConfiguration(
                            gradient: Gradient(colors: [
                                .clear,
                                .white.opacity(0.5),
                                .clear
                            ]),
                            duration: 1.2,
                            opacity: 0.8
                        )
                    )
            )
            .cornerRadius(20)
        }
        .padding(.horizontal)
    }
} 
