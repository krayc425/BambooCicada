import SwiftUI
import Combine

struct ContentView: View {
    @AppStorage("totalCompletedRotations") private var totalCompletedRotations = 0
    @StateObject private var remote = RemoteInput()
    @State private var sound = CicadaSoundEngine()
    @State private var physics = ToyPhysics()
    @State private var dragAngle: Double?
    @State private var dragTime: Date?
    @State private var dragAngularVelocity = 0.0
    @State private var isDragging = false
    @State private var physicsAccumulator = 0.0
    @State private var partialRotation = 0.0
    @State private var lastFrameTime: Date?
    @GestureState private var isLongPressing = false

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background.ignoresSafeArea()
                decorativeRings(intensity: intensity)
                    .offset(y: ringNavigationOffset)

                VStack(spacing: 0) {
                    Spacer(minLength: 8)
                    BambooCicadaScene(
                        anchor: physics.anchor,
                        tube: physics.tube,
                        tubeVelocity: physics.tubeVelocity,
                        ropeLength: physics.ropeLength,
                        ropeDistance: physics.ropeDistance,
                        ropeAngle: physics.ropeAngle,
                        bodyAngle: physics.bodyAngle,
                        angularVelocity: physics.angularVelocity,
                        intensity: intensity
                    )
                        .frame(maxWidth: min(proxy.size.width * 0.92, 780), maxHeight: min(proxy.size.height * 0.60, 620))
                        .contentShape(Rectangle())
                        #if os(iOS)
                        .gesture(spinGesture(in: CGSize(
                            width: min(proxy.size.width * 0.92, 780),
                            height: min(proxy.size.height * 0.60, 620)
                        )))
                        #endif
                        .accessibilityLabel("旋转的竹蝉")
                        .accessibilityValue(intensity > 0.12 ? "正在鸣叫" : "静止")
                    Spacer(minLength: 4)
                    meter
                    rotationCounter
                    instructions
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
            .contentShape(Rectangle())
            #if os(tvOS)
            .focusable()
            .onMoveCommand { direction in
                switch direction {
                case .left, .down: remote.nudge(-1)
                case .right, .up: remote.nudge(1)
                @unknown default: break
                }
            }
            #endif
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            sound.silence()
        }
        .onReceive(ticker) { date in advanceFrame(at: date) }
        #if os(iOS)
        .navigationTitle("竹蝉")
        .navigationBarTitleDisplayMode(.large)
        #else
        .toolbar {
            ToolbarItem(placement: .principal) {
                navigationHeader
            }
        }
        #endif
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.055, green: 0.10, blue: 0.075), Color(red: 0.11, green: 0.20, blue: 0.12), Color(red: 0.035, green: 0.065, blue: 0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RadialGradient(colors: [Color.yellow.opacity(0.14), .clear], center: .center, startRadius: 20, endRadius: 520)
        }
    }

    private var navigationHeader: some View {
        Text("竹蝉")
            .font(.system(size: titleSize, weight: .black, design: .rounded))
            .tracking(4)
            .foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.45))
    }

    private var meter: some View {
        HStack(spacing: 10) {
            Image(systemName: intensity > 0.08 ? "waveform" : "circle.dotted")
                .symbolEffect(.variableColor.iterative, isActive: intensity > 0.1)
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(index < illuminatedBarCount ? Color(red: 0.96, green: 0.72, blue: 0.25) : .white.opacity(0.14))
                    .frame(width: 7, height: CGFloat(10 + index * 3))
            }
            Text(intensity > 0.65 ? "蝉鸣正盛" : intensity > 0.08 ? "风起有声" : "等待起风")
                .font(.system(size: meterSize, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var illuminatedBarCount: Int {
        guard intensity > 0.08 else { return 0 }
        return min(7, max(1, Int(ceil((intensity - 0.08) / 0.92 * 7))))
    }

    private var instructions: some View {
        HStack(spacing: 8) {
            Image(systemName: instructionIcon)
            Text(instructionText)
        }
        .font(.system(size: instructionSize, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.62))
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    private var rotationCounter: some View {
        Label {
            Text("已转 \(totalCompletedRotations) 圈")
                .contentTransition(.numericText(value: Double(totalCompletedRotations)))
        } icon: {
            Image(systemName: "arrow.clockwise.circle")
        }
        .font(.system(size: counterSize, weight: .semibold, design: .rounded))
        .foregroundStyle(Color(red: 0.95, green: 0.82, blue: 0.45).opacity(0.88))
        .padding(.top, 14)
        .accessibilityLabel("累计已转 \(totalCompletedRotations) 圈")
    }

    private func decorativeRings(intensity: Double) -> some View {
        let expansion = pow(max(intensity, 0), 0.8)
        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color(red: 0.91, green: 0.70, blue: 0.28).opacity(0.05 + intensity * 0.10), lineWidth: 1.5)
                    .frame(width: CGFloat(250 + index * 105), height: CGFloat(250 + index * 105))
                    .scaleEffect(1 + expansion * CGFloat(index + 1) * 0.060)
            }
        }
        .animation(.easeOut(duration: 0.18), value: intensity)
    }

    #if os(iOS)
    private func spinGesture(in size: CGSize) -> some Gesture {
        let longPress = LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($isLongPressing) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }

        let circularDrag = DragGesture(minimumDistance: 3)
            .onChanged { value in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                // Negating screen Y maps UIKit coordinates into the SceneKit
                // plane. A clockwise finger circle therefore has negative
                // angular velocity and the model follows clockwise as well.
                let currentAngle = atan2(
                    -Double(value.location.y - center.y),
                    Double(value.location.x - center.x)
                )
                if let previousAngle = dragAngle, let previousTime = dragTime {
                    var delta = currentAngle - previousAngle
                    while delta > Double.pi { delta -= 2 * Double.pi }
                    while delta < -Double.pi { delta += 2 * Double.pi }
                    let dt = max(value.time.timeIntervalSince(previousTime), 1.0 / 120.0)
                    // A finger circle gives the toy a little extra leverage,
                    // so a comfortable gesture can still build a lively spin.
                    let measured = min(max(delta / dt * 1.5, -28), 28)
                    dragAngularVelocity += (measured - dragAngularVelocity) * 0.55
                }
                dragAngle = currentAngle
                dragTime = value.time
                isDragging = true
            }
            .onEnded { _ in
                dragAngle = nil
                dragTime = nil
                dragAngularVelocity = 0
                isDragging = false
            }

        return longPress.simultaneously(with: circularDrag)
    }
    #endif

    private func advanceFrame(at date: Date) {
        guard let previousTime = lastFrameTime else {
            lastFrameTime = date
            return
        }
        let frameDuration = min(max(date.timeIntervalSince(previousTime), 1.0 / 240.0), 0.05)
        lastFrameTime = date

        let remoteRate = remote.consumeVelocity()
        if isLongPressing {
            physics.requestedAngularVelocity = -3.4 * 2 * Double.pi
        } else if isDragging {
            physics.requestedAngularVelocity = dragAngularVelocity
        } else if abs(remoteRate) > 0.08 {
            physics.requestedAngularVelocity = min(max(remoteRate, -28), 28)
        } else {
            physics.requestedAngularVelocity = nil
        }

        physicsAccumulator += frameDuration
        let fixedStep = 1.0 / 240.0
        while physicsAccumulator >= fixedStep {
            physics.step(fixedStep)
            partialRotation += abs(physics.angularVelocity) * fixedStep / (2 * Double.pi)
            physicsAccumulator -= fixedStep
        }
        let completedRotations = Int(partialRotation)
        if completedRotations > 0 {
            totalCompletedRotations += completedRotations
            partialRotation -= Double(completedRotations)
        }
        physics.finishFrame(frameDuration)
        sound.update(
            rotationsPerSecond: physics.rotationsPerSecond,
            phase: physics.ropeAngle,
            activity: physics.soundActivity
        )
    }

    private var intensity: Double { physics.soundActivity }

    #if os(tvOS)
    private var titleSize: CGFloat { 36 }
    private var ringNavigationOffset: CGFloat { -30 }
    private var meterSize: CGFloat { 23 }
    private var counterSize: CGFloat { 22 }
    private var instructionSize: CGFloat { 22 }
    private var horizontalPadding: CGFloat { 80 }
    private var verticalPadding: CGFloat { 50 }
    private var instructionIcon: String { "circle.grid.cross" }
    private var instructionText: String { "在遥控器触控盘上画圈，或按方向键助力" }
    #else
    private var titleSize: CGFloat { 20 }
    private var ringNavigationOffset: CGFloat { -44 }
    private var meterSize: CGFloat { 15 }
    private var counterSize: CGFloat { 15 }
    private var instructionSize: CGFloat { 15 }
    private var horizontalPadding: CGFloat { 22 }
    private var verticalPadding: CGFloat { 22 }
    private var instructionIcon: String { "hand.draw" }
    private var instructionText: String { "长按竹蝉或绕圈滑动" }
    #endif
}

#Preview {
    NavigationStack {
        ContentView()
    }
}
