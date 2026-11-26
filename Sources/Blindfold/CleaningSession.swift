struct CleaningOptions: OptionSet {
    let rawValue: Int

    static let keyboard = Self(rawValue: 1 << 0)
    static let pointer = Self(rawValue: 1 << 1)
    static let display = Self(rawValue: 1 << 2)
    static let keyboardBacklight = Self(rawValue: 1 << 3)

    var blocksInput: Bool {
        contains(.keyboard) || contains(.pointer)
    }
}

enum CleaningDuration: Int, CaseIterable {
    case thirtySeconds = 30
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300
    case never = 0

    var seconds: Int? {
        self == .never ? nil : rawValue
    }

    var label: String {
        switch self {
        case .thirtySeconds: "30 seconds"
        case .oneMinute: "1 minute"
        case .twoMinutes: "2 minutes"
        case .fiveMinutes: "5 minutes"
        case .never: "Never"
        }
    }
}

struct CleaningSession {
    static let escapeHold = Duration.seconds(3)

    private let deadline: ContinuousClock.Instant?
    private var escapePressedAt: ContinuousClock.Instant?
    private var escapeCompleted = false

    init(startedAt: ContinuousClock.Instant, duration: CleaningDuration) {
        deadline = duration.seconds.map { startedAt + .seconds($0) }
    }

    mutating func recordEscape(isDown: Bool, at now: ContinuousClock.Instant) {
        if isDown {
            if escapePressedAt == nil {
                escapePressedAt = now
            }
        } else {
            escapeCompleted = escapeCompleted || escapeHeldLongEnough(at: now)
            cancelEscape()
        }
    }

    mutating func cancelEscape() {
        escapePressedAt = nil
    }

    func shouldEnd(at now: ContinuousClock.Instant) -> Bool {
        if let deadline, now >= deadline { return true }
        return escapeCompleted || escapeHeldLongEnough(at: now)
    }

    func secondsRemaining(at now: ContinuousClock.Instant) -> Int? {
        guard let deadline else { return nil }
        let remaining = now.duration(to: deadline)
        guard remaining > .zero else { return 0 }

        let (seconds, attoseconds) = remaining.components
        return Int(seconds) + (attoseconds > 0 ? 1 : 0)
    }

    private func escapeHeldLongEnough(at now: ContinuousClock.Instant) -> Bool {
        guard let escapePressedAt else { return false }
        return escapePressedAt.duration(to: now) >= Self.escapeHold
    }
}
