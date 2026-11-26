import Testing
@testable import Blindfold

@MainActor
@Test func capsLockMappingsAreSuppressedWithoutChangingOtherMappings() {
    let capsLock: UInt64 = 0x700000039
    let lockingCapsLock: UInt64 = 0x700000082
    let escape: UInt64 = 0x700000029
    let noAction: UInt64 = 0x700000000
    let original: KeyboardCapsLock.Mapping = [
        capsLock: 0x7000000e0,
        escape: capsLock,
        0x7000000e7: lockingCapsLock,
        0x700000004: 0x700000005,
    ]

    let blocked = KeyboardCapsLock.mappingWithCapsLockBlocked(original)

    #expect(blocked[capsLock] == noAction)
    #expect(blocked[lockingCapsLock] == noAction)
    #expect(blocked[escape] == escape)
    #expect(blocked[0x7000000e7] == noAction)
    #expect(blocked[0x700000004] == 0x700000005)
    #expect(KeyboardCapsLock.restoringMapping(blocked, original: original, blocked: blocked) == original)
}

@MainActor
@Test func capsLockRecoveryPreservesRemappingChangesMadeDuringCleaning() {
    let original: KeyboardCapsLock.Mapping = [0x700000004: 0x700000005, 0x700000039: 0x7000000e0]
    let blocked = KeyboardCapsLock.mappingWithCapsLockBlocked(original)
    var current = blocked
    current[0x700000004] = 0x700000006
    current[0x700000039] = 0x7000000e1

    let restored = KeyboardCapsLock.restoringMapping(current, original: original, blocked: blocked)

    #expect(restored == [0x700000004: 0x700000006, 0x700000039: 0x7000000e1])
}
