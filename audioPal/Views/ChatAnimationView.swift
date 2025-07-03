import SwiftUI

struct ChatAnimationView: View {
    let isRecording: Bool
    let isResponding: Bool
    let audioLevel: Float

    @State private var rotation: Double = 0
    @State private var linePositions: [CGPoint] = Array(repeating: .zero, count: 24) // 20 lines * 2 points
    @State private var equalizerPoints: [CGPoint] = []
    @State private var animationKey = UUID()

    private let timer = Timer.publish(every: 0.008, on: .main, in: .common).autoconnect()
    private let numberOfLines = 12 // More lines for the globe
    private let ballRadius: CGFloat = 40

    // Adjusted speed parameters for 3D ball
    private let perspectiveBaseLength: CGFloat = 30 // Base length for horizontal lines
    private let rotationSpeedBase: Double = 0.25 // Much faster base rotation speed
    private let rotationSpeedDynamicMultiplier: Double = 0.15 // Dynamic part scales this

    // Adjusted parameters for Equalizer
    private let equalizerAmplitudeBase: CGFloat = 25 // Base amplitude for equalizer (50% of potential max)
    private let equalizerAmplitudeDynamicMultiplier: CGFloat = 80 // Dynamic part scales this
    private let dynamicWiggleMultiplier: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isResponding {
                    // Equalizer animation
                    Path { path in
                        guard !equalizerPoints.isEmpty else { return }
                        path.move(to: equalizerPoints[0])
                        for point in equalizerPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.blue, lineWidth: 3)
                    .animation(.easeInOut(duration: 0.1), value: equalizerPoints)
                } else {
                    // 3D ball animation with horizontal lines
                    ForEach(0..<numberOfLines, id: \.self) { index in
                        Line3D(
                            startPoint: linePositions[index],
                            endPoint: linePositions[index + numberOfLines],
                            rotation: rotation // Pass rotation, though not used in Path definition
                        )
                        .stroke(Color.blue, lineWidth: 2)
                    }
                }
            }
            .id(animationKey)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                rotation = 0
                setupInitialPositions(in: geometry.size)
                animationKey = UUID()
            }
            .onReceive(timer) { _ in
                // Update rotation based on state (recording adds to speed)
                rotation += rotationSpeedBase + (isRecording ? rotationSpeedDynamicMultiplier : 0)

                if isResponding {
                    updateEqualizer(in: geometry.size)
                } else {
                    updateBallAnimation(in: geometry.size)
                }
            }
            .onChange(of: isResponding) { newValue in
                if !newValue {
                    rotation = 0
                    setupInitialPositions(in: geometry.size)
                    animationKey = UUID()
                }
            }
        }
    }

    // Sets up the initial positions of the lines when the view appears or transitions
    private func setupInitialPositions(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for i in 0..<numberOfLines {
            let angle = Double(i) * 2 * .pi / Double(numberOfLines)
            let sphereX = center.x + cos(angle) * ballRadius
            let sphereY = center.y + sin(angle) * ballRadius

            let initialHorizontalHalfLength = perspectiveBaseLength * (1.0 - abs(sin(angle)))

            linePositions[i] = CGPoint(x: sphereX - initialHorizontalHalfLength, y: sphereY)
            linePositions[i + numberOfLines] = CGPoint(x: sphereX + initialHorizontalHalfLength, y: sphereY)
        }
        // Also update equalizer points initially, though they won't be visible until isResponding is true
        updateEqualizer(in: size)
    }

    // Updates the positions of the lines for the 3D ball animation
    private func updateBallAnimation(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for i in 0..<numberOfLines {
            let angle = Double(i) * 2 * .pi / Double(numberOfLines) + rotation
            let sphereX = center.x + cos(angle) * ballRadius
            let sphereY = center.y + sin(angle) * ballRadius

            let modulatedHorizontalHalfLength = perspectiveBaseLength * (1.0 - abs(sin(angle)))
            // Dynamic offset based on rotation and line index
            let dynamicOffset = sin(rotation * 3 + Double(i) * 1.7) * dynamicWiggleMultiplier
            let halfLength = max(0, modulatedHorizontalHalfLength + dynamicOffset)

            let start = CGPoint(x: sphereX - halfLength, y: sphereY)
            let end = CGPoint(x: sphereX + halfLength, y: sphereY)

            linePositions[i] = start
            linePositions[i + numberOfLines] = end
        }
    }

    // Updates the points for the equalizer animation
    private func updateEqualizer(in size: CGSize) {
        let width = size.width
        let height = size.height
        let centerY = height / 2
        let numberOfPoints = 50

        // Calculate the raw amplitude based on audio level or random if responding
        let rawLevel = isResponding ? CGFloat.random(in: 0...equalizerAmplitudeDynamicMultiplier) : CGFloat(audioLevel) * equalizerAmplitudeDynamicMultiplier

        // Combine base amplitude with dynamic part (scaled by rawLevel)
        // Base amplitude is 50% of the potential max (base + dynamic_multiplier)
        let amplitude = equalizerAmplitudeBase + rawLevel * 0.5

        equalizerPoints = (0...numberOfPoints).map { i in
            let x = width * CGFloat(i) / CGFloat(numberOfPoints)
            let phase = Double(i) * 0.2 + rotation * 8 // Much faster wave
            let positionFactor = sin(phase)
            let y = centerY + positionFactor * amplitude // Apply amplitude to the sine wave
            return CGPoint(x: x, y: y)
        }
    }
}

// Line3D shape remains the same as it just draws a line between two points
struct Line3D: Shape {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let rotation: Double // Keep rotation parameter, though it's not used in the Path definition itself

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        return path
    }
}
