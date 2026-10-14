import Foundation
import CryptoKit

/// Pinned upstream artifact, independently published with this digest by Homebrew.
/// We never remove quarantine attributes, alter Gatekeeper, or replace an app's runtime.
public enum EngineInstaller {
    public static let version = "11.0_1"
    public static let source = URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.0_1/wine-stable-11.0_1-osx64.tar.xz")!
    public static let sha256 = "b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388"

    public static func digest(of url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
        var hash = SHA256()
        while let block = try file.read(upToCount: 1_048_576), !block.isEmpty { hash.update(data: block) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    public static func install(into root: URL, progress: @escaping @Sendable (String) -> Void) async throws -> WineRuntime {
        let target = root.appendingPathComponent("Wine-\(version)")
        let app = target.appendingPathComponent("Wine Stable.app")
        if FileManager.default.fileExists(atPath: app.path) { return try WineService.validateRuntime(at: app) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appendingPathComponent(".download-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        progress("Downloading Wine 11.0 · 177 MB. This may take several minutes.")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 90; configuration.timeoutIntervalForResource = 1800
        let session = URLSession(configuration: configuration); defer { session.invalidateAndCancel() }
        let (temporary, response) = try await session.download(from: source)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw PorticoError.message("The runtime download failed. Try again when your connection is available.") }
        let archive = staging.appendingPathComponent("runtime.tar.xz")
        try FileManager.default.moveItem(at: temporary, to: archive)
        progress("Verifying the runtime's SHA-256 checksum…")
        guard try digest(of: archive) == sha256 else { throw PorticoError.message("The downloaded runtime did not match its published checksum. It has not been installed.") }
        progress("Unpacking the verified runtime…")
        let unpacked = staging.appendingPathComponent("unpacked")
        try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: true)
        let log = staging.appendingPathComponent("extract.log")
        let code = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/tar"), arguments: ["-xJf", archive.path, "-C", unpacked.path], log: log, timeout: 180)
        guard code == 0 else { throw PorticoError.message("The Wine archive could not be unpacked.") }
        _ = try WineService.validateRuntime(at: unpacked.appendingPathComponent("Wine Stable.app"))
        guard !FileManager.default.fileExists(atPath: target.path) else { throw PorticoError.message("A runtime already exists at this location. Select it from the runtime list.") }
        try FileManager.default.moveItem(at: unpacked, to: target)
        return try WineService.validateRuntime(at: app)
    }
}
