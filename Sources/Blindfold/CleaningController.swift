import AppKit
@preconcurrency import ApplicationServices
import Carbon.HIToolbox
import Combine

enum CleaningIssue {
    case accessibility
    case inputMonitoring
    case unavailable
    case pointerUnavailable
    case capsLockUnavailable
    case capsLockRestoreFailed
    case backlightUnavailable
    case backlightRestoreFailed
    case interrupted
    case noDisplay

    var message: String {
        switch self {
        case .accessibility:
            "Allow Blindfold in System Settings › Privacy & Security › Accessibility, then try again."
        case .inputMonitoring:
            "Allow Blindfold in System Settings › Privacy & Security › Input Monitoring, then reopen the app."
        case .unavailable:
            "macOS couldn’t pause input. Reopen Blindfold and try again."
        case .pointerUnavailable:
            "macOS couldn’t freeze the pointer. Bring Blindfold to the front and try again."
        case .capsLockUnavailable:
            "Blindfold couldn’t pause Caps Lock on a connected keyboard."
        case .capsLockRestoreFailed:
            "Blindfold couldn’t restore the keyboard mappings. Reopen the app to try again."
        case .backlightUnavailable:
            "Blindfold couldn’t turn off the keyboard backlight."
        case .backlightRestoreFailed:
            "Blindfold couldn’t restore the keyboard backlight. Reopen the app to try again."
        case .interrupted:
            "macOS interrupted input filtering. Cleaning ended and input was restored."
        case .noDisplay:
            "Blindfold couldn’t find an active display."
        }
    }
}

@MainActor
final class CleaningController: ObservableObject {
    @Published private var secondsRemaining: Int?
    @Published private(set) var options: CleaningOptions = []
    @Published private(set) var issue: CleaningIssue?

    private let clock = ContinuousClock()
    private let displays = CleaningDisplays()
    private let backlight = KeyboardBacklight()
    private let capsLock = KeyboardCapsLock()
    private var session: CleaningSession?
    private var tap: InputTap?
    private var localKeyMonitor: Any?
    private var timer: Timer?

    init() {
        recoverKeyboardState()
    }

    var hasKeyboardBacklight: Bool { backlight.isAvailable }
    var isCleaning: Bool { !options.isEmpty }

    var cleaningStatus: String? {
        guard isCleaning else { return nil }
        if let secondsRemaining { return "\(secondsRemaining) s remaining" }
        return "No auto-unlock"
    }

    var escapeHint: String {
        if isCleaning, !options.blocksInput { return "Hold Esc for 3 seconds while Blindfold is active." }
        return "Hold Esc for 3 seconds to end cleaning."
    }

    func start(options: CleaningOptions, duration: CleaningDuration) {
        guard session == nil, !options.isEmpty else { return }
        issue = nil

        let screens = options.contains(.display) ? NSScreen.screens : []
        if options.contains(.display), screens.isEmpty {
            issue = .noDisplay
            return
        }

        if options.blocksInput {
            guard AXIsProcessTrusted() else {
                issue = .accessibility
                let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
                _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
                return
            }

            do {
                tap = try InputTap(options: options) { [weak self] isDown in
                    self?.recordEscape(isDown: isDown)
                }
            } catch {
                switch error {
                case .pointerUnavailable:
                    issue = .pointerUnavailable
                case .tapUnavailable:
                    if CGPreflightListenEventAccess() {
                        issue = .unavailable
                    } else {
                        issue = .inputMonitoring
                        _ = CGRequestListenEventAccess()
                    }
                }
                return
            }
        } else {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
                guard event.keyCode == UInt16(kVK_Escape), let self else { return event }
                if !event.isARepeat {
                    let isDown = event.type == .keyDown
                    MainActor.assumeIsolated { self.recordEscape(isDown: isDown) }
                }
                return nil
            }
        }

        if options.contains(.keyboard), !capsLock.start(at: clock.now) {
            issue = releaseInputCapture() ? .capsLockUnavailable : .capsLockRestoreFailed
            return
        }

        if options.contains(.keyboardBacklight) {
            do {
                try backlight.turnOff()
            } catch {
                if releaseInputCapture() {
                    issue = error == .restoreFailed ? .backlightRestoreFailed : .backlightUnavailable
                } else {
                    issue = .capsLockRestoreFailed
                }
                return
            }
        }

        session = CleaningSession(startedAt: clock.now, duration: duration)
        secondsRemaining = duration.seconds
        self.options = options
        if !screens.isEmpty {
            displays.show(on: screens, statusScreen: NSApp.keyWindow?.screen, controller: self)
        }

        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        guard session != nil else { return }
        let restoredCapsLock = releaseInputCapture()
        timer?.invalidate()
        timer = nil
        displays.close()
        session = nil
        options = []
        secondsRemaining = nil
        let restoredBacklight = backlight.restore()
        if !restoredCapsLock {
            issue = .capsLockRestoreFailed
        } else if !restoredBacklight {
            issue = .backlightRestoreFailed
        }
    }

    func recoverKeyboardState() {
        guard !isCleaning else { return }
        capsLock.recoverIfNeeded()
        backlight.recoverIfNeeded()
    }

    private func releaseInputCapture() -> Bool {
        let restoredCapsLock = capsLock.stop()
        tap?.stop()
        tap = nil
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        return restoredCapsLock
    }

    func displayConfigurationChanged() {
        if !options.isDisjoint(with: [.display, .pointer]) { stop() }
    }

    func appWillResignActive() {
        if options.contains(.pointer) {
            stop()
        } else if localKeyMonitor != nil {
            session?.cancelEscape()
        }
    }

    private func recordEscape(isDown: Bool) {
        session?.recordEscape(isDown: isDown, at: clock.now)
    }

    private func update() {
        guard let session else { return }

        if let tap, !tap.isActive {
            stop()
            if issue == nil { issue = .interrupted }
            return
        }

        let now = clock.now
        if !capsLock.refresh(at: now) {
            stop()
            if issue == nil { issue = .capsLockUnavailable }
            return
        }
        if session.shouldEnd(at: now) {
            stop()
            return
        }
        let remaining = session.secondsRemaining(at: now)
        if secondsRemaining != remaining { secondsRemaining = remaining }
    }
}
