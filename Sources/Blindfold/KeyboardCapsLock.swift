import Darwin
import Foundation
import IOKit.hid
import IOKit.hidsystem

@MainActor
final class KeyboardCapsLock {
    typealias Mapping = [UInt64: UInt64]

    private static let keyboardPage = UInt64(kHIDPage_KeyboardOrKeypad) << 32
    private static let capsLock = keyboardPage | UInt64(kHIDUsage_KeyboardCapsLock)
    private static let lockingCapsLock = keyboardPage | UInt64(kHIDUsage_KeyboardLockingCapsLock)
    private static let escape = keyboardPage | UInt64(kHIDUsage_KeyboardEscape)
    private static let noAction = keyboardPage
    private static let sourceKey = "HIDKeyboardModifierMappingSrc"
    private static let destinationKey = "HIDKeyboardModifierMappingDst"

    private struct Change: Codable {
        let original: Mapping
        let blocked: Mapping
    }

    private struct Recovery: Codable {
        let bootSession: String?
        var changes: [UInt64: Change] = [:]
    }

    private let directory: URL
    private lazy var client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
    private lazy var bootSession = Self.currentBootSession()
    private var lock: CleaningFileLock?
    private var recovery: Recovery?
    private var nextScan: ContinuousClock.Instant?

    init(directory: URL) {
        self.directory = directory
    }

    convenience init() {
        self.init(directory: URL.applicationSupportDirectory.appendingPathComponent("Blindfold", isDirectory: true))
    }

    private var recoveryFile: URL { directory.appendingPathComponent("caps-lock-restore.json") }

    func start(at now: ContinuousClock.Instant) -> Bool {
        guard lock == nil, let lock = acquireLock() else { return false }
        self.lock = lock
        guard restoreSavedMappings() else { return false }
        recovery = Recovery(bootSession: bootSession)
        return refresh(at: now)
    }

    // Poll for keyboards connected after the session starts. Keyboard input itself
    // remains filtered on the event taps while this check runs.
    func refresh(at now: ContinuousClock.Instant) -> Bool {
        guard var recovery else { return true }
        if let nextScan, now < nextScan { return true }
        nextScan = now + .milliseconds(250)

        guard let keyboards = connectedKeyboards() else { return false }
        for (id, keyboard) in keyboards {
            guard let current = readMapping(keyboard) else { return false }
            if let change = recovery.changes[id] {
                guard current == change.blocked else { return false }
                continue
            }

            let blocked = Self.mappingWithCapsLockBlocked(current)
            guard blocked != current else { continue }

            recovery.changes[id] = Change(original: current, blocked: blocked)
            do {
                try JSONEncoder().encode(recovery).write(to: recoveryFile, options: .atomic)
            } catch {
                return false
            }

            self.recovery = recovery
            guard writeMapping(blocked, to: keyboard) else { return false }
        }
        return true
    }

    func stop() -> Bool {
        guard lock != nil else { return true }
        defer {
            lock = nil
            recovery = nil
            nextScan = nil
        }
        return restoreSavedMappings()
    }

    func recoverIfNeeded() {
        guard lock == nil, FileManager.default.fileExists(atPath: recoveryFile.path),
              let recoveryLock = acquireLock() else { return }
        withExtendedLifetime(recoveryLock) {
            _ = restoreSavedMappings()
        }
    }

    private func acquireLock() -> CleaningFileLock? {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return CleaningFileLock(directory.appendingPathComponent("caps-lock.lock"))
    }

    private func restoreSavedMappings() -> Bool {
        guard FileManager.default.fileExists(atPath: recoveryFile.path) else { return true }
        do {
            let saved = try JSONDecoder().decode(Recovery.self, from: Data(contentsOf: recoveryFile))
            // Registry IDs identify services within one boot. macOS clears the
            // remaps on reboot or when a keyboard disconnects.
            if saved.bootSession == nil || bootSession == nil || saved.bootSession == bootSession {
                guard let keyboards = connectedKeyboards() else { return false }
                for (id, change) in saved.changes {
                    guard let keyboard = keyboards[id] else { continue }
                    guard let current = readMapping(keyboard) else { return false }
                    let restored = Self.restoringMapping(current, original: change.original, blocked: change.blocked)
                    guard restored == current || writeMapping(restored, to: keyboard) else { return false }
                }
            }
            try FileManager.default.removeItem(at: recoveryFile)
            return true
        } catch {
            return false
        }
    }

    private func connectedKeyboards() -> [UInt64: IOHIDServiceClient]? {
        guard let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] else { return nil }
        var keyboards: [UInt64: IOHIDServiceClient] = [:]
        for service in services where IOHIDServiceClientConformsTo(
            service, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Keyboard)
        ) != 0 {
            guard let id = IOHIDServiceClientGetRegistryID(service) as? NSNumber else { return nil }
            keyboards[id.uint64Value] = service
        }
        return keyboards
    }

    private func readMapping(_ keyboard: IOHIDServiceClient) -> Mapping? {
        guard let value = IOHIDServiceClientCopyProperty(keyboard, kIOHIDUserKeyUsageMapKey as CFString) else { return [:] }
        guard let pairs = value as? [[String: NSNumber]] else { return nil }
        var mapping: Mapping = [:]
        for pair in pairs {
            guard let source = pair[Self.sourceKey],
                  let destination = pair[Self.destinationKey] else { return nil }
            let key = source.uint64Value
            if mapping[key] == nil { mapping[key] = destination.uint64Value }
        }
        return mapping
    }

    private func writeMapping(_ mapping: Mapping, to keyboard: IOHIDServiceClient) -> Bool {
        let pairs = mapping.map { source, destination in
            [Self.sourceKey: NSNumber(value: Int64(bitPattern: source)),
             Self.destinationKey: NSNumber(value: Int64(bitPattern: destination))]
        }
        return IOHIDServiceClientSetProperty(keyboard, kIOHIDUserKeyUsageMapKey as CFString, pairs as CFArray)
            && readMapping(keyboard) == mapping
    }

    static func mappingWithCapsLockBlocked(_ original: Mapping) -> Mapping {
        var blocked = original
        for (source, destination) in original where destination == capsLock || destination == lockingCapsLock {
            // Keep the physical Esc key usable if it was remapped to Caps Lock.
            blocked[source] = source == escape ? escape : noAction
        }
        blocked[capsLock] = noAction
        blocked[lockingCapsLock] = noAction
        return blocked
    }

    static func restoringMapping(_ current: Mapping, original: Mapping, blocked: Mapping) -> Mapping {
        var restored = current
        for (source, destination) in blocked where original[source] != destination && current[source] == destination {
            restored[source] = original[source]
        }
        return restored
    }

    private static func currentBootSession() -> String? {
        var bytes = [UInt8](repeating: 0, count: 128)
        var size = bytes.count
        guard sysctlbyname("kern.bootsessionuuid", &bytes, &size, nil, 0) == 0, size > 1 else { return nil }
        return String(decoding: bytes.prefix(size - 1), as: UTF8.self)
    }
}
