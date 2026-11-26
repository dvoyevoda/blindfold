import Foundation
import Testing
@testable import Blindfold

@MainActor
@Test func backlightRestoresTheSavedLevelAndAutomaticSetting() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let device = TestKeyboardBacklight()
    let original = device.state
    let backlight = KeyboardBacklight(device: device, directory: directory)
    let otherInstance = KeyboardBacklight(device: device, directory: directory)

    try backlight.turnOff()
    #expect(device.state == KeyboardBacklightState(brightness: 0, autoBrightness: false))

    otherInstance.recoverIfNeeded()
    #expect(throws: KeyboardBacklight.Failure.self) { try otherInstance.turnOff() }
    #expect(device.state.brightness == 0)

    #expect(backlight.restore())
    #expect(device.state == original)
}

@MainActor
@Test func aFailedBrightnessWriteRollsBackAutomaticAdjustment() {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let device = TestKeyboardBacklight()
    let original = device.state
    device.rejectNextBrightnessWrite = true
    let backlight = KeyboardBacklight(device: device, directory: directory)

    #expect(throws: KeyboardBacklight.Failure.self) { try backlight.turnOff() }
    #expect(device.state == original)
}

@MainActor
@Test func missingSessionRestorationIsRetriedByTheNextInstance() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let device = TestKeyboardBacklight()
    let original = device.state
    var backlight: KeyboardBacklight? = KeyboardBacklight(device: device, directory: directory)

    try backlight?.turnOff()
    #expect(device.state.brightness == 0)
    backlight = nil

    let restarted = KeyboardBacklight(device: device, directory: directory)
    restarted.recoverIfNeeded()
    #expect(device.state == original)
}

@MainActor
private final class TestKeyboardBacklight: KeyboardBacklightDevice {
    var state = KeyboardBacklightState(brightness: 0.65, autoBrightness: true)
    var rejectNextBrightnessWrite = false

    func readState() -> KeyboardBacklightState? { state }

    func setBrightness(_ brightness: Float) -> Bool {
        if rejectNextBrightnessWrite {
            rejectNextBrightnessWrite = false
            return false
        }
        state = KeyboardBacklightState(brightness: brightness, autoBrightness: state.autoBrightness)
        return true
    }

    func setAutoBrightness(_ enabled: Bool) -> Bool {
        state = KeyboardBacklightState(brightness: state.brightness, autoBrightness: enabled)
        return true
    }
}
