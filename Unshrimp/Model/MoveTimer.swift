import Foundation

/// Accumulates only active time. Explicit dates make interruption behavior testable.
struct MoveTimer {
    var duration: Double
    private(set) var hasStarted = false
    private var banked: Double = 0
    private var runningSince: Date?
    private var now = Date()

    init(duration: Double) { self.duration = max(0, duration) }

    var isRunning: Bool { runningSince != nil }
    var elapsed: Double { min(duration, banked + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)) }
    var progress: Double { duration > 0 ? elapsed / duration : 1 }
    var secondsLeft: Int { Int(ceil(max(0, duration - elapsed))) }
    var isComplete: Bool { elapsed >= duration }

    mutating func start(at date: Date = Date()) {
        guard !isRunning, !isComplete else { return }
        hasStarted = true
        now = date
        runningSince = date
    }

    mutating func pause(at date: Date = Date()) {
        now = date
        banked = elapsed
        runningSince = nil
    }

    mutating func toggle(at date: Date = Date()) { isRunning ? pause(at: date) : start(at: date) }

    mutating func tick(at date: Date = Date()) {
        now = date
        if isRunning && isComplete { banked = duration; runningSince = nil }
    }

    mutating func restart(duration: Double, at date: Date = Date()) {
        self = MoveTimer(duration: duration)
        start(at: date)
    }
}
