import SwiftUI

public struct ShimmerConfiguration {
    public let gradient: Gradient
    public let initialLocation: (start: UnitPoint, end: UnitPoint)
    public let finalLocation: (start: UnitPoint, end: UnitPoint)
    public let duration: Double
    public let opacity: Double
    
    public init(
        gradient: Gradient = Gradient(colors: [.clear, .white.opacity(0.5), .clear]),
        initialLocation: (start: UnitPoint, end: UnitPoint) = (UnitPoint(x: -1, y: 0.5), UnitPoint(x: 0, y: 0.5)),
        finalLocation: (start: UnitPoint, end: UnitPoint) = (UnitPoint(x: 1, y: 0.5), UnitPoint(x: 2, y: 0.5)),
        duration: Double = 1.5,
        opacity: Double = 0.7
    ) {
        self.gradient = gradient
        self.initialLocation = initialLocation
        self.finalLocation = finalLocation
        self.duration = duration
        self.opacity = opacity
    }
    
    public static let `default` = ShimmerConfiguration()
}

struct ShimmeringView<Content: View>: View {
    private let content: () -> Content
    private let configuration: ShimmerConfiguration
    @State private var startPoint: UnitPoint
    @State private var endPoint: UnitPoint
    
    init(configuration: ShimmerConfiguration, @ViewBuilder content: @escaping () -> Content) {
        self.configuration = configuration
        self.content = content
        _startPoint = .init(wrappedValue: configuration.initialLocation.start)
        _endPoint = .init(wrappedValue: configuration.initialLocation.end)
    }
    
    var body: some View {
        ZStack {
            content()
            LinearGradient(
                gradient: configuration.gradient,
                startPoint: startPoint,
                endPoint: endPoint
            )
            .opacity(configuration.opacity)
            .blendMode(.screen)
            .onAppear {
                withAnimation(Animation.linear(duration: configuration.duration).repeatForever(autoreverses: false)) {
                    startPoint = configuration.finalLocation.start
                    endPoint = configuration.finalLocation.end
                }
            }
        }
    }
}

struct ShimmerModifier: ViewModifier {
    let configuration: ShimmerConfiguration
    
    func body(content: Content) -> some View {
        ShimmeringView(configuration: configuration) { content }
    }
}

extension View {
    func shimmer(configuration: ShimmerConfiguration = .default) -> some View {
        modifier(ShimmerModifier(configuration: configuration))
    }
} 