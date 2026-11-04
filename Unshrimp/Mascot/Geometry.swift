import SwiftUI

// Small vector helpers for the illustration code.

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }

    func rotated(by degrees: Double, around c: CGPoint) -> CGPoint {
        let r = degrees * .pi / 180
        let v = self - c
        return CGPoint(x: c.x + v.x * cos(r) - v.y * sin(r), y: c.y + v.x * sin(r) + v.y * cos(r))
    }
}

enum Geo {
    static func rad(_ d: Double) -> Double { d * .pi / 180 }
    /// Unit vector for an angle in degrees (screen coordinates, y down).
    static func dir(_ d: Double) -> CGPoint { CGPoint(x: cos(rad(d)), y: sin(rad(d))) }
    static func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { (a + b) * 0.5 }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static func ellipse(_ c: CGPoint, w: CGFloat, h: CGFloat, angle: Double = 0) -> Path {
        Path(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
            .applying(CGAffineTransform(rotationAngle: rad(angle)).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
    }

    static func polyline(_ pts: [CGPoint], closed: Bool = false) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        for q in pts.dropFirst() { p.addLine(to: q) }
        if closed { p.closeSubpath() }
        return p
    }

    static func roundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r, style: .continuous)
    }

    static func smoothstep(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Ease-out that overshoots a little and settles, for lively pose changes.
    static func backOut(_ x: Double, overshoot s: Double = 1.5) -> Double {
        let t = min(max(x, 0), 1) - 1
        return t * t * ((s + 1) * t + s) + 1
    }

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    /// An ellipse whose edge drifts by a percent or two, like a shape inked by hand.
    /// The same seed always gives the same wobble, so it never shimmers between frames.
    static func wobblyEllipse(_ c: CGPoint, w: CGFloat, h: CGFloat, angle: Double = 0, seed: Double, amount: Double = 1) -> Path {
        var p = Path()
        let steps = 44
        let r = rad(angle)
        for k in 0...steps {
            let a = Double(k) / Double(steps) * 2 * .pi
            let j = 1 + amount * (0.012 * sin(3 * a + seed) + 0.008 * sin(5 * a + seed * 1.7))
            let lx = Double(w) / 2 * j * cos(a), ly = Double(h) / 2 * j * sin(a)
            let pt = CGPoint(x: c.x + CGFloat(lx * cos(r) - ly * sin(r)), y: c.y + CGFloat(lx * sin(r) + ly * cos(r)))
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    static func wobblyCircle(_ c: CGPoint, _ r: CGFloat, seed: Double, amount: Double = 1) -> Path {
        wobblyEllipse(c, w: r * 2, h: r * 2, seed: seed, amount: amount)
    }

    /// A four-point twinkle.
    static func star(_ c: CGPoint, _ r: CGFloat) -> Path {
        let pts = (0..<8).map { k -> CGPoint in
            let rr = k.isMultiple(of: 2) ? r : r * 0.32
            return c + dir(Double(k) * 45 - 90) * rr
        }
        return polyline(pts, closed: true)
    }

    static func bezier(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, _ t: Double) -> CGPoint {
        let u = CGFloat(1 - t), v = CGFloat(t)
        return a * (u * u * u) + b * (3 * u * u * v) + c * (3 * u * v * v) + d * (v * v * v)
    }

    static func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        let u = CGFloat(1 - t), v = CGFloat(t)
        return a * (u * u) + c * (2 * u * v) + b * (v * v)
    }

    /// Stable pseudo-random number in 0..<1.
    static func hash(_ x: Double) -> Double {
        let s = sin(x * 12.9898) * 43758.5453
        return s - floor(s)
    }
}

/// Fills a shape and draws the petrol outline used across all illustrations.
extension GraphicsContext {
    func outlined(_ path: Path, _ color: Color, width: CGFloat = 3, lineColor: Color = Palette.petrol) {
        self.fill(path, with: .color(color))
        self.stroke(path, with: .color(lineColor), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    func line(_ path: Path, _ color: Color = Palette.petrol, width: CGFloat = 3) {
        stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    /// A stroke that thins out along its length, like a brush or nib lifting off the paper.
    func taperedLine(_ pts: [CGPoint], from w0: CGFloat, to w1: CGFloat, color: Color = Palette.petrol) {
        guard pts.count > 1 else { return }
        for i in 1..<pts.count {
            let w = w0 + (w1 - w0) * CGFloat(i) / CGFloat(pts.count - 1)
            line(Geo.polyline([pts[i - 1], pts[i]]), color, width: w)
        }
    }

    /// Fills a shape and inks it, with a heavier line on the shadow side (down and right).
    func inked(_ path: Path, _ color: Color, width: CGFloat = 2.8) {
        var shadow = self
        shadow.translateBy(x: 0.5, y: 0.9)
        shadow.stroke(path, with: .color(Palette.petrol), style: StrokeStyle(lineWidth: width + 1.2, lineCap: .round, lineJoin: .round))
        fill(path, with: .color(color))
        stroke(path, with: .color(Palette.petrol), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}
