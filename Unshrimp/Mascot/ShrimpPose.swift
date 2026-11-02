import Foundation

/// High-level moods the companion can be in.
enum ShrimpState: Hashable {
    case working       // absorbed at the laptop
    case inviting      // looks up and waves: break time?
    case stretching    // gently uncurling
    case celebrating   // break completed
    case resting       // content, goal done
    case exercise(MovePose)

    var accessibilityLabel: String {
        switch self {
        case .working: String(localized: "\(Brand.mascotName) the shrimp is typing at the laptop")
        case .inviting: String(localized: "\(Brand.mascotName) looks up and waves, inviting you to a break")
        case .stretching: String(localized: "\(Brand.mascotName) is stretching")
        case .celebrating: String(localized: "\(Brand.mascotName) is celebrating")
        case .resting: String(localized: "\(Brand.mascotName) is resting contentedly")
        case .exercise: String(localized: "\(Brand.mascotName) demonstrates the move")
        }
    }
}

/// Illustration poses for the demo moves.
enum MovePose: String, Codable, Hashable {
    case neckTilt, nod, shoulderRoll, shrug, chestOpener, reachUp, twist, catCow, march, sideReach
}

/// Every parameter the mascot rig understands. Poses are plain data so they can be
/// interpolated for smooth transitions.
struct ShrimpPose {
    enum Eye { case dot, wide, happy, closed }
    enum Mouth { case smile, open, flat }

    /// Direction (degrees) from the head toward the body. ~10 = curled at a desk, ~70 = upright.
    var heading: Double = 8
    /// Total bend of the body in degrees. Bigger = more shrimpy.
    var curl: Double = 205
    /// Positive looks up.
    var headTilt: Double = -8
    /// Arm angles in degrees, 0 = pointing forward (left), positive raises.
    var armFront: Double = -10
    var armBack: Double = -20
    var armBend: Double = -30
    var armLength: Double = 1
    /// Slides the shoulders from the belly (0) toward the spine (1), so raised arms clear the face.
    var shoulderShift: Double = 0
    var bounce: Double = 0
    var lean: Double = 0
    var eye: Eye = .dot
    var eyeOpen: Double = 1
    var mouth: Mouth = .smile
    var antennaSway: Double = 0
    var antennaPerk: Double = 0.5
    var blush: Double = 0.8
    var legWiggle: Double = 0
    var legPhase: Double = 0
    var breath: Double = 0

    static func lerp(_ a: ShrimpPose, _ b: ShrimpPose, _ t: Double) -> ShrimpPose {
        func l(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        var p = ShrimpPose()
        p.heading = l(a.heading, b.heading)
        p.curl = l(a.curl, b.curl)
        p.headTilt = l(a.headTilt, b.headTilt)
        p.armFront = l(a.armFront, b.armFront)
        p.armBack = l(a.armBack, b.armBack)
        p.armBend = l(a.armBend, b.armBend)
        p.armLength = l(a.armLength, b.armLength)
        p.shoulderShift = l(a.shoulderShift, b.shoulderShift)
        p.bounce = l(a.bounce, b.bounce)
        p.lean = l(a.lean, b.lean)
        p.eye = t < 0.5 ? a.eye : b.eye
        p.eyeOpen = l(a.eyeOpen, b.eyeOpen)
        p.mouth = t < 0.5 ? a.mouth : b.mouth
        p.antennaSway = l(a.antennaSway, b.antennaSway)
        p.antennaPerk = l(a.antennaPerk, b.antennaPerk)
        p.blush = l(a.blush, b.blush)
        p.legWiggle = l(a.legWiggle, b.legWiggle)
        p.legPhase = l(a.legPhase, b.legPhase)
        p.breath = l(a.breath, b.breath)
        return p
    }
}

/// Turns a state plus time into a concrete pose. `t` is seconds; pass `animated: false`
/// (Reduce Motion) to get the calm, canonical key pose.
enum ShrimpMotion {
    static func pose(_ state: ShrimpState, t rawT: Double, animated: Bool) -> ShrimpPose {
        let t = animated ? rawT : 0
        let k: Double = animated ? 1 : 0
        var p = ShrimpPose()
        p.breath = sin(t * 2.1) * k
        p.antennaSway = sin(t * 1.3) * 5 * k

        switch state {
        case .working:
            // Types in bursts, pausing now and then to read the screen.
            let typing = Geo.smoothstep((sin(t * 0.8) + 0.25) / 0.5) * k
            p.heading = 8; p.curl = 205
            p.headTilt = -8 + sin(t * 0.7) * 2 * k + (1 - typing) * 5 * k
            // Arms reach all the way to the keys.
            p.armFront = 2 + max(0, sin(t * 11)) * 7 * typing
            p.armBack = -4 + max(0, sin(t * 11 + 2.1)) * 7 * typing
            p.armBend = -18; p.armLength = 1.45
            p.mouth = .flat
        case .inviting:
            // Front arm raised past the body so the hand waves clear of the silhouette.
            p.heading = 18; p.curl = 188; p.headTilt = 28 + sin(t * 1.6) * 3 * k
            p.armFront = 168 + sin(t * 3) * 4 * k; p.armBend = -75 + sin(t * 6.5) * 28 * k
            p.armBack = -60; p.armLength = 1.9; p.shoulderShift = 1
            p.eye = .wide; p.mouth = .open
            p.antennaPerk = 1; p.antennaSway = 6 + sin(t * 2.4) * 9 * k
            p.bounce = abs(sin(t * 2.2)) * 2 * k
        case .stretching:
            let s = sin(t * 1.1) * k
            // Fully upright, both arms straight overhead.
            p.heading = 80 - s * 4; p.curl = 85 + s * 14; p.headTilt = 30 + s * 6
            p.armFront = 104 + s * 5; p.armBack = 72 + s * 5; p.armBend = -4; p.armLength = 3.0; p.shoulderShift = 1
            p.eye = .closed; p.mouth = .smile
        case .celebrating:
            // Arms up in a V, hopping with hang time; the body straightens in the air.
            let hop = pow(abs(sin(t * 3.6)), 0.6) * k
            p.heading = 50 + hop * 15; p.curl = 160 - hop * 45; p.headTilt = 15 + hop * 8
            p.armFront = 150 + sin(t * 9) * 8 * k; p.armBack = 62 + sin(t * 9 + 1) * 8 * k
            p.armBend = -25; p.armLength = 2.1; p.shoulderShift = 1
            p.bounce = hop * 18
            p.eye = .happy; p.mouth = .open
            p.antennaPerk = 1; p.antennaSway = sin(t * 5) * 12 * k
            p.legWiggle = 12 * k; p.legPhase = t * 10
        case .resting:
            p.heading = 0; p.curl = 225 + sin(t * 0.9) * 3 * k; p.headTilt = 0
            p.armFront = -50; p.armBack = -60; p.armBend = -60
            p.eye = .closed; p.mouth = .smile
            p.antennaSway = sin(t * 0.8) * 3 * k
            p.breath = sin(t * 1.2) * 1.6 * k
        case .exercise(let move):
            p = exercise(move, t: t, k: k)
        }

        if animated, p.eye == .dot || p.eye == .wide {
            p.eyeOpen = blink(t)
        }
        return p
    }

    static func blink(_ t: Double) -> Double {
        let cycle = t.truncatingRemainder(dividingBy: 4.3)
        let window = 0.16
        if cycle < window { return max(0.1, abs(cycle - window / 2) / (window / 2)) }
        return 1
    }

    /// Upright base used by the guided moves.
    private static var upright: ShrimpPose {
        var p = ShrimpPose()
        p.heading = 55; p.curl = 135; p.headTilt = 8
        p.armFront = -15; p.armBack = -25; p.armBend = -10
        p.eye = .dot; p.mouth = .smile
        return p
    }

    private static func exercise(_ move: MovePose, t: Double, k: Double) -> ShrimpPose {
        var p = upright
        p.breath = sin(t * 2) * k
        switch move {
        case .neckTilt:
            p.headTilt = 8 + sin(t * 0.9) * 24 * k
            p.eye = .closed
        case .nod:
            p.headTilt = 6 + sin(t * 1.8) * 16 * k
        case .shoulderRoll:
            p.armFront = -20 + sin(t * 2.4) * 22 * k
            p.armBack = -20 + sin(t * 2.4 + .pi) * 22 * k
            p.armBend = -20 + cos(t * 2.4) * 25 * k
            p.bounce = (1 + sin(t * 2.4)) * 2 * k
        case .shrug:
            let up = max(0, sin(t * 1.6)) * k
            p.bounce = up * 6
            p.armFront = -35 + up * 20; p.armBack = -45 + up * 20
            p.headTilt = 4 - up * 6
            p.eye = up > 0.5 ? .closed : .dot
        case .chestOpener:
            let o = (0.5 + 0.5 * sin(t * 0.9)) * k
            p.heading = 62 + o * 8; p.curl = 120 - o * 30
            p.headTilt = 12 + o * 12
            p.armFront = -60 - o * 50; p.armBack = -70 - o * 50; p.armBend = 0
            p.eye = .closed
        case .reachUp:
            let o = (0.5 + 0.5 * sin(t * 1.0)) * k
            p.heading = 68 + o * 4; p.curl = 110 - o * 20; p.headTilt = 22 + o * 8
            p.armFront = 20 + o * 18; p.armBack = 34 + o * 18; p.armBend = 15; p.armLength = 1.1
            p.eye = .closed
        case .twist:
            p.lean = sin(t * 1.1) * 9 * k
            p.headTilt = 6 + sin(t * 1.1) * 6 * k
            p.armFront = -5; p.armBack = -15; p.armBend = 30
        case .catCow:
            let o = sin(t * 0.9) * k
            p.curl = 150 + o * 45; p.heading = 50 - o * 12
            p.headTilt = -o * 20
            p.eye = o > 0 ? .closed : .dot
        case .march:
            p.heading = 62; p.curl = 125
            p.bounce = abs(sin(t * 4)) * 8 * k
            p.armFront = -20 + sin(t * 4) * 35 * k
            p.armBack = -20 - sin(t * 4) * 35 * k
            p.armBend = 20
            p.legWiggle = 25 * k; p.legPhase = t * 8
            p.mouth = .open
        case .sideReach:
            p.lean = sin(t * 0.8) * 12 * k
            p.armFront = 30 + sin(t * 0.8) * 15 * k; p.armBend = 20; p.armLength = 1.1
            p.armBack = -30
            p.eye = .closed
        }
        return p
    }
}
