import SwiftUI
import SceneKit

#if os(iOS) || os(tvOS)
struct BambooCicadaScene: UIViewRepresentable {
    var anchor: Vector2
    var tube: Vector2
    var tubeVelocity: Vector2
    var ropeLength: Double
    var ropeDistance: Double
    var ropeAngle: Double
    var bodyAngle: Double
    var angularVelocity: Double
    var intensity: Double

    final class Coordinator {
        var spin = 0.0
        var previousOmega = 0.0
        var wingLeft = (angle: 0.15, velocity: 0.0)
        var wingRight = (angle: 0.15, velocity: 0.0)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = CicadaSceneFactory.makeScene()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = true
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard let root = view.scene?.rootNode,
              let rotor = root.childNode(withName: "rotor", recursively: true),
              let handle = root.childNode(withName: "handle", recursively: true),
              let handleKnot = root.childNode(withName: "handleKnot", recursively: true),
              let stringA = root.childNode(withName: "stringA", recursively: true),
              let stringB = root.childNode(withName: "stringB", recursively: true),
              let wingLeft = root.childNode(withName: "wingLeft", recursively: true),
              let wingRight = root.childNode(withName: "wingRight", recursively: true) else { return }

        let pivot = Vector2(x: anchor.x, y: anchor.y + 3.1)
        let bodyPosition = Vector2(x: tube.x, y: tube.y + 3.1)
        let towardAnchor = (pivot - bodyPosition) * (1 / max((pivot - bodyPosition).length, 0.001))
        let attachment = bodyPosition + towardAnchor * 0.84
        let slack = max(0, ropeLength - ropeDistance)
        let ropeMidpoint = Vector2(
            x: (pivot.x + attachment.x) / 2,
            y: (pivot.y + attachment.y) / 2 - slack * 0.55
        )
        updateSegment(stringA, from: pivot, to: ropeMidpoint)
        updateSegment(stringB, from: ropeMidpoint, to: attachment)

        let coordinator = context.coordinator
        let dt = 1.0 / 60.0
        coordinator.spin += angularVelocity * 0.45 * dt
        let angularAcceleration = min(max((angularVelocity - coordinator.previousOmega) / dt, -60), 60)
        coordinator.previousOmega = angularVelocity
        let travelSpeed = tubeVelocity.length
        let restingAngle = 0.15 + min(0.85, travelSpeed * 0.08)
        let kick = angularAcceleration * 0.016
        let flutter = min(1, travelSpeed * 0.05 + intensity)
            * sin(CFAbsoluteTimeGetCurrent() * 46) * 0.22

        func advanceWing(_ wing: inout (angle: Double, velocity: Double), target: Double) -> Double {
            wing.velocity += ((target - wing.angle) * 80 - wing.velocity * 9) * dt
            wing.angle += wing.velocity * dt
            return wing.angle
        }
        let leftAngle = advanceWing(&coordinator.wingLeft, target: restingAngle - kick) + flutter
        let rightAngle = advanceWing(&coordinator.wingRight, target: restingAngle + kick) + flutter * 0.85

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        // The rope anchor is the right-hand end of the stick, not its center.
        // A slight diagonal makes the grip read naturally instead of looking
        // like a bar floating horizontally through the middle of the screen.
        let handleAngle = 0.18
        let handleDirection = Vector2(x: cos(handleAngle), y: sin(handleAngle))
        let handleCenter = pivot - handleDirection * 1.62
        handle.position = SCNVector3(Float(handleCenter.x), Float(handleCenter.y), 0)
        handle.eulerAngles.z = Float(handleAngle - Double.pi / 2)
        handleKnot.position = SCNVector3(Float(pivot.x), Float(pivot.y), 0)
        rotor.position = SCNVector3(Float(bodyPosition.x), Float(bodyPosition.y), 0)
        rotor.eulerAngles = SCNVector3(0, Float(coordinator.spin), Float(bodyAngle + .pi / 2))
        wingLeft.eulerAngles.y = Float(-leftAngle)
        wingRight.eulerAngles.y = Float(rightAngle)
        SCNTransaction.commit()
    }

    private func updateSegment(_ node: SCNNode, from start: Vector2, to end: Vector2) {
        let delta = end - start
        let distance = max(delta.length, 0.001)
        (node.geometry as? SCNCylinder)?.height = CGFloat(distance)
        node.position = SCNVector3(
            Float((start.x + end.x) / 2),
            Float((start.y + end.y) / 2),
            0
        )
        node.eulerAngles.z = Float(atan2(-delta.x, delta.y))
    }
}

private enum CicadaSceneFactory {
    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 36
        camera.position = SCNVector3(0, 2.0, 16.0)
        scene.rootNode.addChildNode(camera)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 900
        key.light?.temperature = 4_300
        key.position = SCNVector3(-4, 5, 7)
        scene.rootNode.addChildNode(key)
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .ambient
        fill.light?.intensity = 330
        fill.light?.color = UIColor(red: 0.65, green: 0.76, blue: 0.58, alpha: 1)
        scene.rootNode.addChildNode(fill)

        let rotor = SCNNode()
        rotor.name = "rotor"
        rotor.position = SCNVector3(0, 0.1, 0)
        scene.rootNode.addChildNode(rotor)

        let body = node(SCNCylinder(radius: 0.48, height: 1.65), color: UIColor(red: 0.74, green: 0.57, blue: 0.27, alpha: 1), roughness: 0.76)
        rotor.addChildNode(body)

        for y in [-0.74, 0.60] as [Float] {
            let joint = node(SCNTorus(ringRadius: 0.48, pipeRadius: 0.038), color: UIColor(red: 0.40, green: 0.24, blue: 0.08, alpha: 1), roughness: 0.82)
            joint.position.y = y
            rotor.addChildNode(joint)
        }
        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 4) {
            let grain = node(SCNBox(width: 0.014, height: 1.25, length: 0.014, chamferRadius: 0.006), color: UIColor(red: 0.37, green: 0.23, blue: 0.07, alpha: 0.34), roughness: 1)
            grain.position = SCNVector3(Float(cos(angle) * 0.47), -0.05, Float(sin(angle) * 0.47))
            rotor.addChildNode(grain)
        }

        let headBand = node(SCNCylinder(radius: 0.52, height: 0.22), color: UIColor(red: 0.72, green: 0.12, blue: 0.07, alpha: 1), roughness: 0.72)
        headBand.position.y = 0.69
        rotor.addChildNode(headBand)
        let membrane = node(SCNCylinder(radius: 0.41, height: 0.035), color: UIColor(red: 0.94, green: 0.86, blue: 0.67, alpha: 1), roughness: 0.92)
        membrane.position.y = 0.815
        rotor.addChildNode(membrane)
        let tailOpening = node(SCNCylinder(radius: 0.40, height: 0.028), color: UIColor(red: 0.18, green: 0.10, blue: 0.035, alpha: 1), roughness: 1)
        tailOpening.position.y = -0.84
        rotor.addChildNode(tailOpening)

        addWing(to: rotor, side: -1, name: "wingLeft")
        addWing(to: rotor, side: 1, name: "wingRight")

        for side in [-1, 1] as [Float] {
            let eye = node(SCNSphere(radius: 0.14), color: UIColor(red: 0.12, green: 0.08, blue: 0.04, alpha: 1), roughness: 0.35)
            eye.position = SCNVector3(side * 0.36, 0.60, 0.39)
            rotor.addChildNode(eye)
        }

        let stringA = node(SCNCylinder(radius: 0.025, height: 1.2), color: UIColor(red: 0.73, green: 0.15, blue: 0.10, alpha: 1), roughness: 0.9)
        stringA.name = "stringA"
        scene.rootNode.addChildNode(stringA)
        let stringB = node(SCNCylinder(radius: 0.025, height: 1.2), color: UIColor(red: 0.73, green: 0.15, blue: 0.10, alpha: 1), roughness: 0.9)
        stringB.name = "stringB"
        scene.rootNode.addChildNode(stringB)

        let handle = node(SCNCapsule(capRadius: 0.13, height: 3.4), color: UIColor(red: 0.48, green: 0.29, blue: 0.10, alpha: 1), roughness: 0.8)
        handle.name = "handle"
        scene.rootNode.addChildNode(handle)

        let handleKnot = node(SCNSphere(radius: 0.16), color: UIColor(red: 0.73, green: 0.15, blue: 0.10, alpha: 1), roughness: 0.88)
        handleKnot.name = "handleKnot"
        handleKnot.position = SCNVector3(0, 3.1, 0)
        scene.rootNode.addChildNode(handleKnot)
        return scene
    }

    static func addWing(to parent: SCNNode, side: Float, name: String) {
        let shape = UIBezierPath()
        shape.move(to: CGPoint(x: 0, y: 0))
        shape.addCurve(to: CGPoint(x: CGFloat(side) * 0.78, y: -0.78), controlPoint1: CGPoint(x: CGFloat(side) * 0.76, y: -0.05), controlPoint2: CGPoint(x: CGFloat(side) * 1.18, y: -0.48))
        shape.addCurve(to: CGPoint(x: 0, y: 0), controlPoint1: CGPoint(x: CGFloat(side) * 0.48, y: -0.72), controlPoint2: CGPoint(x: CGFloat(side) * 0.10, y: -0.22))
        let wing = node(SCNShape(path: shape, extrusionDepth: 0.025), color: UIColor(red: 0.90, green: 0.82, blue: 0.62, alpha: 0.92), roughness: 0.86)
        wing.name = name
        wing.position = SCNVector3(side * 0.30, 0.38, 0.04)
        parent.addChildNode(wing)
    }

    static func node(_ geometry: SCNGeometry, color: UIColor, roughness: CGFloat) -> SCNNode {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.roughness.contents = roughness
        material.metalness.contents = 0.02
        material.isDoubleSided = true
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }
}
#endif
