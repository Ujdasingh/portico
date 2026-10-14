import Foundation
import Darwin

/// A lifetime lock prevents two app copies from saving over the same library.
public final class LibrarySession {
    private let descriptor: Int32
    public init(root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        descriptor = Darwin.open(root.appendingPathComponent(".session.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw PorticoError.message("Cannot lock this library. Check its folder permissions.") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            throw PorticoError.message("Another Portico copy is using this library. Quit that copy, then reopen this one.")
        }
        // Child Wine processes must not inherit the app's lifetime lock.
        _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
    }
    deinit { flock(descriptor, LOCK_UN); Darwin.close(descriptor) }
}
