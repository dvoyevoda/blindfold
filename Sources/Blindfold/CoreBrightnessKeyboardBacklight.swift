import Darwin
import Foundation
import ObjectiveC.runtime

// macOS has no public keyboard-brightness setter. Keep all use of the private
// interface here and verify method signatures before calling into it.
@MainActor
final class CoreBrightnessKeyboardBacklight: KeyboardBacklightDevice {
    private typealias ReadBrightness = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias WriteBrightness = @convention(c) (AnyObject, Selector, Float, UInt64) -> ObjCBool
    private typealias ReadFlag = @convention(c) (AnyObject, Selector, UInt64) -> ObjCBool
    private typealias WriteFlag = @convention(c) (AnyObject, Selector, ObjCBool, UInt64) -> ObjCBool

    private static let framework = dlopen(
        "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
        RTLD_NOW | RTLD_LOCAL
    )
    #if arch(x86_64)
    private static let boolEncoding = "c"
    #else
    private static let boolEncoding = "B"
    #endif

    private static let brightness = NSSelectorFromString("brightnessForKeyboard:")
    private static let setBrightness = NSSelectorFromString("setBrightness:forKeyboard:")
    private static let autoBrightness = NSSelectorFromString("isAutoBrightnessEnabledForKeyboard:")
    private static let setAutoBrightness = NSSelectorFromString("enableAutoBrightness:forKeyboard:")

    private let client: NSObject
    private let keyboardID: UInt64
    private let readBrightness: ReadBrightness
    private let writeBrightness: WriteBrightness
    private let readAutoBrightness: ReadFlag
    private let writeAutoBrightness: WriteFlag

    init?() {
        let copyIDs = NSSelectorFromString("copyKeyboardBacklightIDs")
        let builtIn = NSSelectorFromString("isKeyboardBuiltIn:")
        let bool = Self.boolEncoding

        guard Self.framework != nil,
              let clientClass = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type,
              Self.checkedMethod(clientClass, copyIDs, encoding: "@@:") != nil,
              let client = (clientClass as AnyObject).perform(NSSelectorFromString("new"))?.takeRetainedValue() as? NSObject,
              let ids = client.perform(copyIDs)?.takeRetainedValue() as? [NSNumber],
              let readBuiltIn = Self.checkedMethod(clientClass, builtIn, encoding: "\(bool)@:Q"),
              let readBrightness = Self.checkedMethod(clientClass, Self.brightness, encoding: "f@:Q"),
              let writeBrightness = Self.checkedMethod(clientClass, Self.setBrightness, encoding: "\(bool)@:fQ"),
              let readAuto = Self.checkedMethod(clientClass, Self.autoBrightness, encoding: "\(bool)@:Q"),
              let writeAuto = Self.checkedMethod(clientClass, Self.setAutoBrightness, encoding: "\(bool)@:\(bool)Q")
        else { return nil }

        let isBuiltIn = unsafeBitCast(readBuiltIn, to: ReadFlag.self)
        guard let keyboard = ids.first(where: { isBuiltIn(client, builtIn, $0.uint64Value).boolValue }) else {
            return nil
        }

        self.client = client
        keyboardID = keyboard.uint64Value
        self.readBrightness = unsafeBitCast(readBrightness, to: ReadBrightness.self)
        self.writeBrightness = unsafeBitCast(writeBrightness, to: WriteBrightness.self)
        readAutoBrightness = unsafeBitCast(readAuto, to: ReadFlag.self)
        writeAutoBrightness = unsafeBitCast(writeAuto, to: WriteFlag.self)
        guard readState() != nil else { return nil }
    }

    func readState() -> KeyboardBacklightState? {
        let brightness = readBrightness(client, Self.brightness, keyboardID)
        guard (0...1).contains(brightness) else { return nil }
        let auto = readAutoBrightness(client, Self.autoBrightness, keyboardID).boolValue
        return KeyboardBacklightState(brightness: brightness, autoBrightness: auto)
    }

    func setBrightness(_ brightness: Float) -> Bool {
        writeBrightness(client, Self.setBrightness, brightness, keyboardID).boolValue
    }

    func setAutoBrightness(_ enabled: Bool) -> Bool {
        writeAutoBrightness(client, Self.setAutoBrightness, ObjCBool(enabled), keyboardID).boolValue
    }

    private static func checkedMethod(_ clientClass: NSObject.Type, _ selector: Selector, encoding: String) -> IMP? {
        guard let method = class_getInstanceMethod(clientClass, selector),
              let rawEncoding = method_getTypeEncoding(method),
              String(cString: rawEncoding).filter({ !$0.isNumber }) == encoding else { return nil }
        return method_getImplementation(method)
    }
}
