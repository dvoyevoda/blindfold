import AppKit
import Carbon.HIToolbox
import CoreGraphics
import IOKit.hidsystem

@MainActor
final class InputTap {
    enum StartError: Error {
        case tapUnavailable
        case pointerUnavailable
    }

    private struct Registration {
        let port: CFMachPort
        let source: CFRunLoopSource
    }

    private static let keyEvents: [CGEventType] = [.keyDown, .keyUp]
    private static let pointerEvents: [CGEventType] = [
        .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        .rightMouseDown, .rightMouseUp, .rightMouseDragged, .otherMouseDown,
        .otherMouseUp, .otherMouseDragged, .scrollWheel,
    ]

    private let options: CleaningOptions
    private let onEscape: (Bool) -> Void
    private var registrations: [Registration] = []
    private var interrupted = false
    private var cursorIsDetached = false

    init(options: CleaningOptions, onEscape: @escaping (Bool) -> Void) throws(StartError) {
        self.options = options
        self.onEscape = onEscape

        guard installTap(at: .cgSessionEventTap, mask: Self.eventMask(for: options)) else {
            throw .tapUnavailable
        }

        let hardwareMask = Self.hardwareKeyboardMask(for: options)
        if hardwareMask != 0 {
            // Some system shortcuts run before the session tap. Keep the session
            // tap for events injected there and on systems that decline the HID tap.
            _ = installTap(at: .cghidEventTap, mask: hardwareMask)
        }

        if options.contains(.pointer) {
            // The cursor is moved by WindowServer before the session tap receives the event.
            guard CGAssociateMouseAndMouseCursorPosition(0) == .success else {
                stop()
                throw .pointerUnavailable
            }
            cursorIsDetached = true
        }
    }

    private func installTap(at location: CGEventTapLocation, mask: CGEventMask) -> Bool {
        guard let port = CGEvent.tapCreate(
            tap: location,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.filter,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        guard CGEvent.tapIsEnabled(tap: port),
              let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            return false
        }

        registrations.append(Registration(port: port, source: source))
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        return true
    }

    var isActive: Bool {
        !interrupted && !registrations.isEmpty && registrations.allSatisfy { CGEvent.tapIsEnabled(tap: $0.port) }
    }

    func stop() {
        for registration in registrations {
            CGEvent.tapEnable(tap: registration.port, enable: false)
            CFMachPortInvalidate(registration.port)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), registration.source, .commonModes)
        }
        registrations.removeAll()
        if cursorIsDetached {
            _ = CGAssociateMouseAndMouseCursorPosition(1)
            cursorIsDetached = false
        }
    }

    static func eventMask(for options: CleaningOptions) -> CGEventMask {
        // Esc is available as an exit even when only pointing devices are paused.
        var events = keyEvents
        if options.contains(.pointer) { events += pointerEvents }

        let mask = events.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        return mask | hardwareKeyboardMask(for: options)
    }

    static func hardwareKeyboardMask(for options: CleaningOptions) -> CGEventMask {
        guard options.contains(.keyboard) else { return 0 }
        return CGEventMask(NX_KEYDOWNMASK | NX_KEYUPMASK | NX_FLAGSCHANGEDMASK | NX_SYSDEFINEDMASK)
    }

    nonisolated static func isSystemKeyboardControl(_ event: CGEvent) -> Bool {
        guard event.type.rawValue == UInt32(NX_SYSDEFINED),
              let systemEvent = NSEvent(cgEvent: event),
              systemEvent.type == .systemDefined else { return false }
        return isSystemKeyboardControl(subtype: Int32(systemEvent.subtype.rawValue), data: systemEvent.data1)
    }

    nonisolated static func isSystemKeyboardControl(subtype: Int32, data: Int) -> Bool {
        switch subtype {
        case NX_SUBTYPE_AUX_CONTROL_BUTTONS:
            // The upper 16 bits carry the special key code.
            let keyCode = (data >> 16) & 0xffff
            return keyCode != Int(NX_POWER_KEY)
        case NX_SUBTYPE_EJECT_KEY:
            return true
        default:
            return false
        }
    }

    private static let filter: CGEventTapCallBack = { _, type, event, context in
        guard let context else { return Unmanaged.passUnretained(event) }

        let tap = Unmanaged<InputTap>.fromOpaque(context).takeUnretainedValue()
        if type.rawValue == UInt32(NX_SYSDEFINED) {
            // Other system-defined events include power and mouse notifications.
            let keyboardLocked = MainActor.assumeIsolated { tap.options.contains(.keyboard) }
            return keyboardLocked && InputTap.isSystemKeyboardControl(event) ? nil : Unmanaged.passUnretained(event)
        }

        let escapeTransition: Bool?
        if (type == .keyDown || type == .keyUp),
           event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Escape),
           event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            escapeTransition = type == .keyDown
        } else {
            escapeTransition = nil
        }

        // The source is installed exclusively on the main run loop.
        let suppress = MainActor.assumeIsolated {
            tap.shouldSuppress(type, escapeTransition: escapeTransition)
        }
        return suppress ? nil : Unmanaged.passUnretained(event)
    }

    private func shouldSuppress(_ type: CGEventType, escapeTransition: Bool?) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            interrupted = true
            return false
        case .keyDown, .keyUp, .flagsChanged:
            if let escapeTransition { onEscape(escapeTransition) }
            return options.contains(.keyboard)
        default:
            return options.contains(.pointer)
        }
    }
}
