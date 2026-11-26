import Testing
@testable import Blindfold

@Test func expiresAtTheSelectedDeadline() {
    let start = ContinuousClock().now

    for duration in CleaningDuration.allCases {
        guard let seconds = duration.seconds else { continue }
        let session = CleaningSession(startedAt: start, duration: duration)
        let deadline = start + .seconds(seconds)

        #expect(session.secondsRemaining(at: start + .milliseconds(750)) == seconds)
        #expect(session.secondsRemaining(at: deadline - .milliseconds(1)) == 1)
        #expect(!session.shouldEnd(at: deadline - .milliseconds(1)))
        #expect(session.secondsRemaining(at: deadline) == 0)
        #expect(session.shouldEnd(at: deadline))
    }
}

@Test func neverHasNoDeadlineAndStillEndsAfterHoldingEscape() {
    let start = ContinuousClock().now
    let later = start + .seconds(3600)
    var session = CleaningSession(startedAt: start, duration: .never)

    #expect(session.secondsRemaining(at: start) == nil)
    #expect(session.secondsRemaining(at: later) == nil)
    #expect(!session.shouldEnd(at: later))

    session.recordEscape(isDown: true, at: later)

    #expect(!session.shouldEnd(at: later + .milliseconds(2999)))
    #expect(session.shouldEnd(at: later + .seconds(3)))
}

@Test func escapeHoldEndsTheSessionEvenWithRepeatedKeyDowns() {
    let start = ContinuousClock().now
    var session = CleaningSession(startedAt: start, duration: .oneMinute)

    session.recordEscape(isDown: true, at: start + .seconds(1))
    session.recordEscape(isDown: true, at: start + .seconds(2))

    #expect(!session.shouldEnd(at: start + .milliseconds(3999)))
    #expect(session.shouldEnd(at: start + .seconds(4)))
}

@Test func shortEscapeHoldsDoNotAccumulate() {
    let start = ContinuousClock().now
    var session = CleaningSession(startedAt: start, duration: .oneMinute)

    session.recordEscape(isDown: true, at: start)
    session.recordEscape(isDown: false, at: start + .seconds(2))
    session.recordEscape(isDown: true, at: start + .seconds(3))

    #expect(!session.shouldEnd(at: start + .seconds(5)))
    #expect(session.shouldEnd(at: start + .seconds(6)))
}

@Test func escapeReleaseAfterThreeSecondsSurvivesUntilTheNextTimerTick() {
    let start = ContinuousClock().now
    var session = CleaningSession(startedAt: start, duration: .oneMinute)

    session.recordEscape(isDown: true, at: start)
    session.recordEscape(isDown: false, at: start + .seconds(3))

    #expect(session.shouldEnd(at: start + .milliseconds(3010)))
}

@Test func cancellingTheLocalHoldPreventsAnExitAfterLosingFocus() {
    let start = ContinuousClock().now
    var session = CleaningSession(startedAt: start, duration: .oneMinute)

    session.recordEscape(isDown: true, at: start)
    session.cancelEscape()

    #expect(!session.shouldEnd(at: start + .seconds(3)))
}
