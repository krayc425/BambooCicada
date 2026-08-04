import Foundation

struct Vector2: Equatable {
    var x: Double
    var y: Double

    static let zero = Vector2(x: 0, y: 0)

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: Self, rhs: Double) -> Self {
        Self(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    var length: Double { hypot(x, y) }
}

struct ToyPhysics {
    let ropeLength = 3.0
    private let gravity = 23.0
    private let airDrag = 0.35
    private let driveResponse = 16.0

    var anchor = Vector2.zero
    var tube = Vector2(x: 0, y: -3)
    var tubeVelocity = Vector2.zero
    var requestedAngularVelocity: Double?

    private(set) var ropeDistance = 3.0
    private(set) var ropeTension = 23.0
    private(set) var ropeAngle = -Double.pi / 2
    private(set) var bodyAngle = -Double.pi / 2
    private(set) var angularVelocity = 0.0
    private(set) var isRopeTaut = true
    private(set) var rotationsPerSecond = 0.0
    private(set) var soundActivity = 0.0

    mutating func step(_ dt: Double) {
        if isRopeTaut {
            stepWhileTaut(dt)
        } else {
            stepWhileSlack(dt)
        }
    }

    private mutating func stepWhileTaut(_ dt: Double) {
        // Gravity always acts. While the user is driving the toy, a critically
        // damped controller follows their measured circular speed instead of
        // letting an unconstrained spring fling the model unpredictably.
        angularVelocity += -(gravity / ropeLength) * cos(ropeAngle) * dt
        if let requestedAngularVelocity {
            let blend = 1 - exp(-driveResponse * dt)
            angularVelocity += (requestedAngularVelocity - angularVelocity) * blend
        }
        angularVelocity *= exp(-airDrag * dt)
        angularVelocity = min(max(angularVelocity, -30), 30)
        ropeAngle += angularVelocity * dt

        let radial = Vector2(x: cos(ropeAngle), y: sin(ropeAngle))
        let tangent = Vector2(x: -sin(ropeAngle), y: cos(ropeAngle))
        tube = anchor + radial * ropeLength
        tubeVelocity = tangent * (angularVelocity * ropeLength)
        ropeDistance = ropeLength
        bodyAngle = ropeAngle

        // T = m(Lω² - g·sinθ). At the top and low speed this approaches zero;
        // when it becomes negative a real rope goes slack instead of pushing.
        let requiredTension = ropeLength * angularVelocity * angularVelocity
            - gravity * sin(ropeAngle)
        ropeTension = max(0, requiredTension)
        if requestedAngularVelocity == nil, requiredTension <= 0 {
            isRopeTaut = false
            ropeTension = 0
        }
    }

    private mutating func stepWhileSlack(_ dt: Double) {
        // A new deliberate gesture pulls the line taut again. This keeps the
        // control predictable while allowing an untouched toy to free-fall.
        if requestedAngularVelocity != nil {
            reattachToRope()
            return
        }

        tubeVelocity.y -= gravity * dt
        tubeVelocity = tubeVelocity * exp(-airDrag * 0.18 * dt)
        tube = tube + tubeVelocity * dt

        let offset = tube - anchor
        let distance = offset.length
        ropeDistance = distance
        ropeTension = 0

        if distance > 0.001 {
            let radial = offset * (1 / distance)
            ropeAngle = atan2(radial.y, radial.x)
            let radialSpeed = tubeVelocity.x * radial.x + tubeVelocity.y * radial.y

            // Once the falling toy has used up all available line, remove
            // only its outward velocity. Tangential motion is preserved.
            if distance >= ropeLength, radialSpeed > 0 {
                tube = anchor + radial * ropeLength
                tubeVelocity = tubeVelocity - radial * radialSpeed
                let tangent = Vector2(x: -radial.y, y: radial.x)
                angularVelocity = (tubeVelocity.x * tangent.x + tubeVelocity.y * tangent.y) / ropeLength
                ropeDistance = ropeLength
                bodyAngle = ropeAngle
                isRopeTaut = true
                ropeTension = max(
                    0,
                    ropeLength * angularVelocity * angularVelocity - gravity * sin(ropeAngle)
                )
                return
            }

            // This is angular drift around the anchor, not a circular
            // constraint. Near the anchor it safely approaches zero.
            angularVelocity = (
                offset.x * tubeVelocity.y - offset.y * tubeVelocity.x
            ) / max(distance * distance, 0.04)
        } else {
            angularVelocity = 0
        }
    }

    private mutating func reattachToRope() {
        let offset = tube - anchor
        let distance = offset.length
        let radial: Vector2
        if distance > 0.001 {
            radial = offset * (1 / distance)
        } else {
            radial = Vector2(x: cos(bodyAngle), y: sin(bodyAngle))
        }
        let tangent = Vector2(x: -radial.y, y: radial.x)
        let tangentialSpeed = tubeVelocity.x * tangent.x + tubeVelocity.y * tangent.y
        tube = anchor + radial * ropeLength
        tubeVelocity = tangent * tangentialSpeed
        ropeAngle = atan2(radial.y, radial.x)
        bodyAngle = ropeAngle
        angularVelocity = tangentialSpeed / ropeLength
        ropeDistance = ropeLength
        ropeTension = 0
        isRopeTaut = true
    }

    mutating func finishFrame(_ dt: Double) {
        rotationsPerSecond = abs(angularVelocity) / (2 * Double.pi)
        let tautness = min(max(ropeTension / gravity, 0), 1)
        let drive = min(max((rotationsPerSecond - 0.28) / 1.9, 0), 1)
        let targetActivity = pow(drive, 1.15) * tautness
        let response = targetActivity > soundActivity ? 14.0 : 3.2
        soundActivity += (targetActivity - soundActivity) * min(1, dt * response)
    }
}
