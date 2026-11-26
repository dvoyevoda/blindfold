import Foundation
import Testing
@testable import Blindfold

@Test func migratesCleaningPreferencesOnceAndPreservesExistingValues() throws {
    let appDomain = "BlindfoldTests.\(UUID().uuidString)"
    let legacyDomain = "\(appDomain).legacy"
    let defaults = try #require(UserDefaults(suiteName: appDomain))
    defer {
        defaults.removePersistentDomain(forName: appDomain)
        defaults.removePersistentDomain(forName: legacyDomain)
    }

    defaults.setPersistentDomain([
        CleaningPreferences.pauseKeyboard: false,
        CleaningPreferences.turnOffKeyboardBacklight: false,
        CleaningPreferences.pausePointer: false,
        CleaningPreferences.blackOutDisplays: false,
        CleaningPreferences.duration: 0,
        "unrelated": true,
    ], forName: legacyDomain)
    defaults.set(true, forKey: CleaningPreferences.pausePointer)

    CleaningPreferences.migrateLegacySettings(in: defaults, appDomain: appDomain, legacyDomain: legacyDomain)

    let migrated = try #require(defaults.persistentDomain(forName: appDomain))
    #expect(migrated[CleaningPreferences.pauseKeyboard] as? Bool == false)
    #expect(migrated[CleaningPreferences.turnOffKeyboardBacklight] as? Bool == false)
    #expect(migrated[CleaningPreferences.pausePointer] as? Bool == true)
    #expect(migrated[CleaningPreferences.blackOutDisplays] as? Bool == false)
    #expect(migrated[CleaningPreferences.duration] as? Int == 0)
    #expect(migrated["unrelated"] == nil)

    defaults.removeObject(forKey: CleaningPreferences.pauseKeyboard)
    CleaningPreferences.migrateLegacySettings(in: defaults, appDomain: appDomain, legacyDomain: legacyDomain)
    #expect(defaults.object(forKey: CleaningPreferences.pauseKeyboard) == nil)
}
