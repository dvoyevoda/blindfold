import IOKit.hidsystem
import Testing
@testable import Blindfold

@MainActor
@Test func keyboardCleaningIncludesStandardKeysAndTopRowControls() {
    let systemEvents = UInt64(NX_SYSDEFINEDMASK)
    let keyboardEvents = UInt64(NX_KEYDOWNMASK | NX_KEYUPMASK | NX_FLAGSCHANGEDMASK)
    let expectedEvents = keyboardEvents | systemEvents

    #expect(InputTap.eventMask(for: .keyboard) & expectedEvents == expectedEvents)
    #expect(InputTap.eventMask(for: [.keyboard, .pointer]) & systemEvents == systemEvents)
    #expect(InputTap.eventMask(for: .pointer) & systemEvents == 0)
}

@MainActor
@Test func hardwareTapOnlyFiltersKeyboardCleaningEvents() {
    let expectedEvents = UInt64(NX_KEYDOWNMASK | NX_KEYUPMASK | NX_FLAGSCHANGEDMASK | NX_SYSDEFINEDMASK)

    #expect(InputTap.hardwareKeyboardMask(for: [.keyboard, .pointer]) == expectedEvents)
    #expect(InputTap.hardwareKeyboardMask(for: .pointer) == 0)
    #expect(InputTap.hardwareKeyboardMask(for: .display) == 0)
}

@Test func filtersAuxiliaryTopRowControls() {
    let keyCodes = [
        NX_KEYTYPE_BRIGHTNESS_UP, NX_KEYTYPE_SOUND_UP, NX_KEYTYPE_PLAY,
        NX_KEYTYPE_LAUNCH_PANEL, NX_KEYTYPE_ILLUMINATION_DOWN,
    ]
    for keyCode in keyCodes {
        #expect(InputTap.isSystemKeyboardControl(subtype: NX_SUBTYPE_AUX_CONTROL_BUTTONS, data: Int(keyCode) << 16))
    }
}

@Test func filtersEjectAndPreservesPowerAndOtherSystemEvents() {
    #expect(InputTap.isSystemKeyboardControl(subtype: NX_SUBTYPE_EJECT_KEY, data: 0))
    #expect(!InputTap.isSystemKeyboardControl(subtype: NX_SUBTYPE_AUX_CONTROL_BUTTONS, data: Int(NX_POWER_KEY) << 16))
    #expect(!InputTap.isSystemKeyboardControl(subtype: NX_SUBTYPE_POWER_KEY, data: 0))
    #expect(!InputTap.isSystemKeyboardControl(subtype: NX_SUBTYPE_AUX_MOUSE_BUTTONS, data: 0))
    #expect(!InputTap.isSystemKeyboardControl(subtype: NX_SUBTYPE_SLEEP_EVENT, data: 0))
}
