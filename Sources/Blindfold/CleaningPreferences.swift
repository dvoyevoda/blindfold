import Foundation

enum CleaningPreferences {
    static let pauseKeyboard = "pauseKeyboard"
    static let turnOffKeyboardBacklight = "turnOffKeyboardBacklight"
    static let pausePointer = "pausePointer"
    static let blackOutDisplays = "blackOutDisplays"
    static let duration = "durationSeconds"

    private static let migratedKey = "migratedLegacyCleaningPreferences"

    static func migrateLegacySettings(
        in defaults: UserDefaults = .standard,
        appDomain: String? = Bundle.main.bundleIdentifier,
        legacyDomain: String = "io.github.dvoyevoda.InputHush"
    ) {
        guard let appDomain, appDomain != legacyDomain,
              let previous = defaults.persistentDomain(forName: legacyDomain) else { return }

        let saved = defaults.persistentDomain(forName: appDomain) ?? [:]
        guard saved[migratedKey] == nil else { return }

        let keys = [pauseKeyboard, turnOffKeyboardBacklight, pausePointer, blackOutDisplays, duration]
        for key in keys where saved[key] == nil {
            if let value = previous[key] {
                defaults.set(value, forKey: key)
            }
        }

        defaults.set(true, forKey: migratedKey)
    }
}
