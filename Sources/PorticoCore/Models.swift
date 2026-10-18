import Foundation

public struct AppProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var runtimePath: String
    public var executablePath: String?
    public var createdAt: Date
    public var notes: String
    public var lastLaunchedAt: Date?
    public var removedAt: Date?

    public init(id: UUID = UUID(), name: String, runtimePath: String, executablePath: String? = nil, notes: String = "") {
        self.id = id; self.name = name; self.runtimePath = runtimePath
        self.executablePath = executablePath; self.createdAt = Date(); self.notes = notes
    }
}

public struct WineRuntime: Identifiable, Hashable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let displayName: String
    public init(url: URL, displayName: String) { self.url = url; self.displayName = displayName }
}

public struct WindowsExecutable: Identifiable, Hashable, Sendable {
    public var id: String { relativePath }
    public let name: String
    public let relativePath: String
    public init(name: String, relativePath: String) { self.name = name; self.relativePath = relativePath }
}

public struct PrefixSnapshot: Codable, Identifiable, Sendable {
    public var integritySHA256: String?
    public var id: UUID
    public var profileID: UUID
    public var createdAt: Date
    public var runtimePath: String
    public init(profileID: UUID, runtimePath: String) {
        id = UUID(); self.profileID = profileID; createdAt = Date(); self.runtimePath = runtimePath
    }
}

public struct RunResult: Sendable {
    public let exitCode: Int32
    public let logURL: URL
    public let diagnostic: String?
    public init(exitCode: Int32, logURL: URL, diagnostic: String?) {
        self.exitCode = exitCode; self.logURL = logURL; self.diagnostic = diagnostic
    }
}

public enum PorticoError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}

public enum Diagnostics {
    public static func explain(_ text: String, exitCode: Int32) -> String? {
        let lower = text.lowercased()
        if lower.contains("bad cpu type") || lower.contains("rosetta") && lower.contains("error") {
            return "This runtime needs Rosetta on Apple silicon. Install Rosetta through macOS, then try again."
        }
        if lower.contains("library not loaded") || lower.contains("dyld:") {
            return "The Wine runtime is missing a macOS library. Keep the complete Wine app together; check its GStreamer dependency."
        }
        if lower.contains("c0000135") || lower.contains("import_dll") || lower.contains("could not load") && lower.contains("dll") {
            return "A Windows component is missing. Use the app's official installer to include its dependencies. Check the log for the DLL name."
        }
        if lower.contains("permission denied") || lower.contains("operation not permitted") {
            return "macOS blocked access to a file or executable. Check file permissions and Privacy & Security; do not disable Gatekeeper."
        }
        if lower.contains("wrong architecture") || lower.contains("bad exe format") || lower.contains("c000007b") {
            return "This executable or one of its dependencies has an unsupported architecture. Try the Windows x64 installer."
        }
        return exitCode == 0 ? nil : "The Windows process exited with code \(exitCode). Open its session log for details."
    }
}
