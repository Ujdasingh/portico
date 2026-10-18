import Foundation

public struct LibraryStore: Sendable {
    public let rootURL: URL
    /// No filesystem access: lets the UI appear before a protected-folder prompt.
    public init(location: URL) { self.rootURL = location.standardizedFileURL }
    public init(rootURL: URL) throws {
        self.init(location: rootURL.resolvingSymlinksInPath())
        try prepare()
    }
    public func prepare() throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        for folder in ["Apps", "Logs", "Backups", "Runtimes"] {
            try FileManager.default.createDirectory(at: rootURL.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
    }
    public var libraryURL: URL { rootURL.appendingPathComponent("library.json") }
    public func load() throws -> [AppProfile] {
        guard FileManager.default.fileExists(atPath: libraryURL.path) else { return [] }
        let profiles = try JSONDecoder().decode([AppProfile].self, from: Data(contentsOf: libraryURL))
        try Self.validate(profiles)
        return profiles
    }
    public func save(_ profiles: [AppProfile]) throws {
        try Self.validate(profiles)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: libraryURL, options: .atomic)
    }
    private static func validate(_ profiles: [AppProfile]) throws {
        guard Set(profiles.map(\.id)).count == profiles.count else {
            throw PorticoError.message("The library contains duplicate app identifiers. Restore its metadata from a trusted backup; the existing file has not been changed.")
        }
        for profile in profiles {
            guard profile.runtimePath.hasPrefix("/"), !profile.runtimePath.contains("\0") else {
                throw PorticoError.message("The library contains an invalid runtime path. The existing file has not been changed.")
            }
            if let path = profile.executablePath {
                guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\0"),
                      !path.split(separator: "/").contains("..") else {
                    throw PorticoError.message("The library contains an invalid executable path. The existing file has not been changed.")
                }
            }
        }
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
