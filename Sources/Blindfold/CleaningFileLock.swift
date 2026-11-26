import Darwin
import Foundation

final class CleaningFileLock {
    private let descriptor: Int32

    init?(_ url: URL) {
        let descriptor = Darwin.open(url.path, O_CREAT | O_RDWR, mode_t(0o600))
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            return nil
        }
        self.descriptor = descriptor
    }

    deinit {
        Darwin.close(descriptor)
    }
}
