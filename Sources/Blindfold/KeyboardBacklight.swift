import Darwin
import Foundation

struct KeyboardBacklightState: Codable, Equatable {
    let brightness: Float
    let autoBrightness: Bool
}

@MainActor
protocol KeyboardBacklightDevice {
    func readState() -> KeyboardBacklightState?
    func setBrightness(_ brightness: Float) -> Bool
    func setAutoBrightness(_ enabled: Bool) -> Bool
}

@MainActor
final class KeyboardBacklight {
    enum Failure: Error {
        case unavailable
        case restoreFailed
    }

    private let device: (any KeyboardBacklightDevice)?
    private let directory: URL?
    private var activeLease: Lease?

    convenience init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Blindfold", isDirectory: true)
        self.init(device: CoreBrightnessKeyboardBacklight(), directory: directory)
    }

    init(device: (any KeyboardBacklightDevice)?, directory: URL?) {
        self.device = device
        self.directory = directory
    }

    var isAvailable: Bool { device != nil && directory != nil }

    func turnOff() throws(Failure) {
        guard activeLease == nil, let device, let directory,
              let lease = Lease(directory: directory) else { throw .unavailable }
        guard lease.restore(using: device) else { throw .restoreFailed }
        guard let state = device.readState(), lease.save(state) else { throw .unavailable }

        activeLease = lease
        if (!state.autoBrightness || device.setAutoBrightness(false)), device.setBrightness(0) {
            return
        }
        guard restore() else { throw .restoreFailed }
        throw .unavailable
    }

    func restore() -> Bool {
        guard let lease = activeLease, let device else { return true }
        defer { activeLease = nil }
        return lease.restore(using: device)
    }

    func recoverIfNeeded() {
        guard activeLease == nil, let device, let directory,
              FileManager.default.fileExists(atPath: Lease.snapshot(in: directory).path),
              let lease = Lease(directory: directory) else { return }
        _ = lease.restore(using: device)
    }

    // Hold the lock through the session so another instance cannot replace the
    // snapshot. The snapshot survives an unexpected exit and is retried on launch.
    private final class Lease {
        private let descriptor: Int32
        private let url: URL

        init?(directory: URL) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                return nil
            }

            let lock = directory.appendingPathComponent("keyboard-backlight.lock")
            let descriptor = Darwin.open(lock.path, O_CREAT | O_RDWR, mode_t(0o600))
            guard descriptor >= 0 else { return nil }
            guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
                Darwin.close(descriptor)
                return nil
            }
            self.descriptor = descriptor
            url = Self.snapshot(in: directory)
        }

        deinit {
            Darwin.close(descriptor)
        }

        static func snapshot(in directory: URL) -> URL {
            directory.appendingPathComponent("keyboard-backlight-restore.json")
        }

        func save(_ state: KeyboardBacklightState) -> Bool {
            do {
                try JSONEncoder().encode(state).write(to: url, options: .atomic)
                return true
            } catch {
                return false
            }
        }

        @MainActor
        func restore(using device: any KeyboardBacklightDevice) -> Bool {
            guard FileManager.default.fileExists(atPath: url.path) else { return true }
            guard let data = try? Data(contentsOf: url),
                  let state = try? JSONDecoder().decode(KeyboardBacklightState.self, from: data),
                  (0...1).contains(state.brightness) else { return false }

            let restoredBrightness = device.setBrightness(state.brightness)
            let restoredAuto = device.readState()?.autoBrightness == state.autoBrightness
                || device.setAutoBrightness(state.autoBrightness)
            guard restoredBrightness, restoredAuto else { return false }
            do {
                try FileManager.default.removeItem(at: url)
                return true
            } catch {
                return false
            }
        }
    }
}
