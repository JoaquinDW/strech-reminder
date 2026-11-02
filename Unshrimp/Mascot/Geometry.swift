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

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
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
}
