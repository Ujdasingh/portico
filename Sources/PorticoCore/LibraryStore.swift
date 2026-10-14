import Foundation

public struct LibraryStore: Sendable {
    public let rootURL: URL
    public init(rootURL: URL) throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        self.rootURL = rootURL.resolvingSymlinksInPath().standardizedFileURL
        for folder in ["Apps", "Logs", "Backups", "Runtimes"] {
            try FileManager.default.createDirectory(at: rootURL.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
    }
    public var libraryURL: URL { rootURL.appendingPathComponent("library.json") }
    public func load() throws -> [AppProfile] {
        guard FileManager.default.fileExists(atPath: libraryURL.path) else { return [] }
        return try JSONDecoder().decode([AppProfile].self, from: Data(contentsOf: libraryURL))
    }
    public func save(_ profiles: [AppProfile]) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: libraryURL, options: .atomic)
    }
    public func prefixURL(for profile: AppProfile) -> URL {
        rootURL.appendingPathComponent("Apps").appendingPathComponent(profile.id.uuidString).appendingPathComponent("prefix")
    }
    public func logDirectory(for profile: AppProfile) -> URL { rootURL.appendingPathComponent("Logs").appendingPathComponent(profile.id.uuidString) }
    public func backupDirectory(for profile: AppProfile) -> URL { rootURL.appendingPathComponent("Backups").appendingPathComponent(profile.id.uuidString) }
    public func snapshotURL(for snapshot: PrefixSnapshot) -> URL {
        rootURL.appendingPathComponent("Backups").appendingPathComponent(snapshot.profileID.uuidString).appendingPathComponent(snapshot.id.uuidString)
    }
    public func executableURL(for profile: AppProfile) throws -> URL {
        guard let relative = profile.executablePath else { throw PorticoError.message("Choose the installed app's executable first.") }
        return try Self.containedURL(relativePath: relative, root: prefixURL(for: profile).appendingPathComponent("drive_c"))
    }
    public static func containedURL(relativePath: String, root: URL) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/"), !relativePath.split(separator: "/").contains("..") else {
            throw PorticoError.message("The selected path is outside this app's Windows environment.")
        }
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        var candidate = resolvedRoot
        // Resolve each existing ancestor, including when the final file does not exist yet.
        for component in relativePath.split(separator: "/") {
            candidate = candidate.appendingPathComponent(String(component)).resolvingSymlinksInPath().standardizedFileURL
            guard candidate.path.hasPrefix(resolvedRoot.path + "/") else { throw PorticoError.message("The selected file points outside this app's environment.") }
        }
        return candidate
    }
}
