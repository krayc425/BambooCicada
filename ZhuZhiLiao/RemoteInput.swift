import Foundation
import Combine

#if os(tvOS)
import GameController

@MainActor
final class RemoteInput: ObservableObject {
    @Published private(set) var circularVelocity = 0.0
    private var lastAngle: Double?
    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let controller = note.object as? GCController else { return }
            Task { @MainActor in self.configure(controller) }
        })
        GCController.controllers().forEach(configure)
        GCController.startWirelessControllerDiscovery()
    }

    private func configure(_ controller: GCController) {
        controller.microGamepad?.reportsAbsoluteDpadValues = true
        controller.microGamepad?.dpad.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in self?.read(x: Double(x), y: Double(y)) }
        }
        controller.extendedGamepad?.dpad.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in self?.read(x: Double(x), y: Double(y)) }
        }
    }

    private func read(x: Double, y: Double) {
        let radius = hypot(x, y)
        guard radius > 0.25 else {
            lastAngle = nil
            circularVelocity *= 0.5
            return
        }
        let angle = atan2(y, x)
        if let previous = lastAngle {
            var delta = angle - previous
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            circularVelocity = circularVelocity * 0.35 + delta * 52 * 0.65
        }
        lastAngle = angle
    }

    func nudge(_ direction: Double) {
        circularVelocity += direction * 3.5
    }

    func consumeVelocity() -> Double {
        let value = circularVelocity
        circularVelocity *= 0.92
        return value
    }
}
#else
@MainActor
final class RemoteInput: ObservableObject {
    @Published private(set) var circularVelocity = 0.0
    func nudge(_ direction: Double) {}
    func consumeVelocity() -> Double { 0 }
}
#endif
