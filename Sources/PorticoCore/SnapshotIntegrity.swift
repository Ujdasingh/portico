import Foundation

/// Detects accidental corruption, not malicious replacement of both data and manifest.
/// Links are recorded as links: external company folders are never traversed.
struct SnapshotIntegrity: Codable, Equatable {
    struct Entry: Codable, Equatable {
        let kind: String
        let value: String
    }
    let version: Int
    let entries: [String: Entry]

    static func capture(_ root: URL) throws -> Self {
        let manager = FileManager.default
        guard try manager.attributesOfItem(atPath: root.path)[.type] as? FileAttributeType == .typeDirectory else {
            throw PorticoError.message("The backup environment is not a regular folder.")
        }
        var entries: [String: Entry] = [:]
        func visit(_ directory: URL, relative: String) throws {
            for item in try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                let path = relative.isEmpty ? item.lastPathComponent : relative + "/" + item.lastPathComponent
                let type = try manager.attributesOfItem(atPath: item.path)[.type] as? FileAttributeType
                switch type {
                case .typeSymbolicLink:
                    entries[path] = Entry(kind: "link", value: try manager.destinationOfSymbolicLink(atPath: item.path))
                case .typeDirectory:
                    entries[path] = Entry(kind: "directory", value: "")
                    try visit(item, relative: path)
                case .typeRegular:
                    entries[path] = Entry(kind: "file", value: try EngineInstaller.digest(of: item))
                default:
                    throw PorticoError.message("The environment contains a special file that cannot be backed up safely.")
                }
            }
        }
        try visit(root, relative: "")
        return Self(version: 1, entries: entries)
    }

    func verify(_ root: URL) throws {
        guard version == 1, try Self.capture(root) == self else {
            throw PorticoError.message("Backup integrity verification failed. A file is missing, damaged, or changed. The current environment has not been replaced.")
        }
    }
}
