import Foundation
import Darwin

// Commands are always argument arrays. No user-supplied paths enter a shell.
public enum ProcessRunner {
    public static func run(_ executable: URL, arguments: [String], environment: [String: String]? = nil,
                           directory: URL? = nil, log: URL, timeout: TimeInterval? = nil) async throws -> Int32 {
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = Darwin.open(log.path, O_WRONLY | O_CREAT | O_APPEND, 0o600)
        guard descriptor >= 0 else { throw PorticoError.message("Cannot create the session log.") }
        let output = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        let process = Process()
        process.executableURL = executable; process.arguments = arguments
        process.environment = environment; process.currentDirectoryURL = directory
        process.standardOutput = output; process.standardError = output
        let state = ProcessState()
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { completed in
                try? output.close()
                if state.isTimedOut { continuation.resume(throwing: PorticoError.message("The operation timed out. See the session log for details.")) }
                else { continuation.resume(returning: completed.terminationStatus) }
            }
            do { try process.run() }
            catch { process.terminationHandler = nil; try? output.close(); continuation.resume(throwing: error); return }
            if let timeout {
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if process.isRunning {
                        state.markTimedOut(); process.terminate()
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                            if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
                        }
                    }
                }
            }
        }
    }
    private final class ProcessState: @unchecked Sendable {
        let lock = NSLock(); var timedOut = false
        var isTimedOut: Bool { lock.lock(); defer { lock.unlock() }; return timedOut }
        func markTimedOut() { lock.lock(); timedOut = true; lock.unlock() }
    }
}

private final class PrefixLock {
    let descriptor: Int32
    init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        descriptor = Darwin.open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw PorticoError.message("Cannot open the app's operation lock.") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor); throw PorticoError.message("This app is busy in another Portico window. Close it before making changes.")
        }
    }
    deinit { flock(descriptor, LOCK_UN); Darwin.close(descriptor) }
}

public actor WineService {
    public let store: LibraryStore
    private var busy = Set<UUID>()
    public init(store: LibraryStore) { self.store = store }

    public static func validateRuntime(at selected: URL) throws -> WineRuntime {
        var executable = selected
        if selected.pathExtension.lowercased() == "app" {
            executable = selected.appendingPathComponent("Contents/Resources/wine/bin/wine")
        }
        guard FileManager.default.isExecutableFile(atPath: executable.path),
              FileManager.default.isExecutableFile(atPath: executable.deletingLastPathComponent().appendingPathComponent("wineserver").path)
        else { throw PorticoError.message("Select a complete Wine app, or its wine executable with wineserver alongside it.") }
        // Commercial engines need their vendor's bottle and licence manager.
        guard !executable.path.lowercased().contains("crossover.app") else {
            throw PorticoError.message("CrossOver engines need CrossOver's bottle manager. Select a standalone Wine runtime instead.")
        }
        let bundleName = executable.pathComponents.first(where: { $0.hasSuffix(".app") })
        return WineRuntime(url: executable, displayName: bundleName?.replacingOccurrences(of: ".app", with: "") ?? "Wine · \(executable.deletingLastPathComponent().lastPathComponent)")
    }

    public static func detectRuntimes(extraRoot: URL? = nil) -> [WineRuntime] {
        var candidates = ["/Applications/Wine Stable.app", "/Applications/Wine Devel.app", "/Applications/Wine Staging.app", "/opt/homebrew/bin/wine", "/usr/local/bin/wine"]
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        for name in ["Wine Stable.app", "Wine Devel.app", "Wine Staging.app"] { candidates.append(userApps.appendingPathComponent(name).path) }
        if let extraRoot, let enumerator = FileManager.default.enumerator(at: extraRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let item as URL in enumerator where item.pathExtension == "app" {
                candidates.append(item.path); enumerator.skipDescendants()
            }
        }
        var seen = Set<String>()
        return candidates.compactMap { try? validateRuntime(at: URL(fileURLWithPath: $0)) }.filter { seen.insert($0.url.resolvingSymlinksInPath().path).inserted }
    }

    private func lock(_ profile: AppProfile) throws -> PrefixLock {
        guard !busy.contains(profile.id) else { throw PorticoError.message("This app is already running or being changed. Close it before continuing.") }
        let lock = try PrefixLock(url: store.prefixURL(for: profile).deletingLastPathComponent().appendingPathComponent("operation.lock"))
        busy.insert(profile.id); return lock
    }
    private func environment(_ profile: AppProfile) -> [String: String] {
        var env = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("WINE") }
        env["WINEPREFIX"] = store.prefixURL(for: profile).path
        env["WINEARCH"] = "win64"
        env["WINEDEBUG"] = "fixme-all"
        env["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d"
        env["PATH"] = URL(fileURLWithPath: profile.runtimePath).deletingLastPathComponent().path + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        return env
    }
    private func logURL(_ profile: AppProfile, action: String) -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return store.logDirectory(for: profile).appendingPathComponent("\(stamp)-\(action)-\(UUID().uuidString.prefix(6)).log")
    }
    private func run(_ profile: AppProfile, arguments: [String], log: URL, directory: URL? = nil, timeout: TimeInterval? = nil) async throws -> Int32 {
        let runtime = try Self.validateRuntime(at: URL(fileURLWithPath: profile.runtimePath))
        return try await ProcessRunner.run(runtime.url, arguments: arguments, environment: environment(profile), directory: directory, log: log, timeout: timeout)
    }
    private func server(_ profile: AppProfile, arguments: [String], log: URL, timeout: TimeInterval? = nil) async throws -> Int32 {
        let wine = try Self.validateRuntime(at: URL(fileURLWithPath: profile.runtimePath))
        return try await ProcessRunner.run(wine.url.deletingLastPathComponent().appendingPathComponent("wineserver"), arguments: arguments, environment: environment(profile), log: log, timeout: timeout)
    }
    private func ensureIdle(_ profile: AppProfile, log: URL) async throws {
        guard FileManager.default.fileExists(atPath: store.prefixURL(for: profile).appendingPathComponent("system.reg").path) else { return }
        do {
            let code = try await server(profile, arguments: ["-w"], log: log, timeout: 5)
            guard code == 0 else { throw PorticoError.message("Wine could not confirm the environment is idle.") }
        }
        catch { throw PorticoError.message("A Windows process is still using this environment. Close its windows, or use Stop app, before making changes.") }
    }
    private func initialize(_ profile: AppProfile, log: URL) async throws {
        let prefix = store.prefixURL(for: profile)
        guard !FileManager.default.fileExists(atPath: prefix.appendingPathComponent(".portico-ready").path) else { return }
        try FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true)
        let code = try await run(profile, arguments: ["wineboot", "--init"], log: log, timeout: 120)
        guard code == 0 else { throw PorticoError.message(result(code: code, log: log).diagnostic ?? "Wine could not create the Windows environment.") }
        guard try await server(profile, arguments: ["-w"], log: log, timeout: 120) == 0 else {
            throw PorticoError.message("Wine initialization did not finish successfully. Try installing again.")
        }
        try Data("Wine initialization completed\n".utf8).write(to: prefix.appendingPathComponent(".portico-ready"), options: .atomic)
    }
    private func result(code: Int32, log: URL) -> RunResult {
        let text = Self.tail(log)
        return RunResult(exitCode: code, logURL: log, diagnostic: Diagnostics.explain(text, exitCode: code))
    }
    public static func tail(_ url: URL, limit: Int = 80_000) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let count = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: count > UInt64(limit) ? count - UInt64(limit) : 0)
        let data = (try? handle.readToEnd()) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    public func install(profile: AppProfile, installerURL: URL) async throws -> RunResult {
        guard ["exe", "msi"].contains(installerURL.pathExtension.lowercased()) else { throw PorticoError.message("Choose a Windows .exe or .msi installer.") }
        let operationLock = try lock(profile); defer { busy.remove(profile.id); withExtendedLifetime(operationLock) {} }
        let log = logURL(profile, action: "install")
        try await ensureIdle(profile, log: log)
        if FileManager.default.fileExists(atPath: store.prefixURL(for: profile).appendingPathComponent("system.reg").path) { _ = try await makeSnapshot(profile, log: log) }
        try await initialize(profile, log: log)
        let arguments = installerURL.pathExtension.lowercased() == "msi" ? ["msiexec", "/i", installerURL.path] : [installerURL.path]
        let code = try await run(profile, arguments: arguments, log: log, directory: installerURL.deletingLastPathComponent())
        _ = try await server(profile, arguments: ["-w"], log: log)
        return result(code: code, log: log)
    }

    public func importPortable(profile: AppProfile, sourceURL: URL) async throws -> WindowsExecutable {
        guard sourceURL.pathExtension.lowercased() == "exe" else { throw PorticoError.message("Choose the portable app's .exe file.") }
        let operationLock = try lock(profile); defer { busy.remove(profile.id); withExtendedLifetime(operationLock) {} }
        let log = logURL(profile, action: "import")
        try await ensureIdle(profile, log: log); try await initialize(profile, log: log)
        let destination = store.prefixURL(for: profile).appendingPathComponent("drive_c/PorticoApps/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Copy the containing folder: adjacent DLLs and resources are part of a portable app.
        let code = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), arguments: [sourceURL.deletingLastPathComponent().path, destination.path], log: log)
        guard code == 0 else { throw PorticoError.message("Could not copy the portable application's folder. See the import log.") }
        let relative = "PorticoApps/\(destination.lastPathComponent)/\(sourceURL.lastPathComponent)"
        return WindowsExecutable(name: sourceURL.deletingPathExtension().lastPathComponent, relativePath: relative)
    }

    public func discoverExecutables(profile: AppProfile) throws -> [WindowsExecutable] {
        let root = store.prefixURL(for: profile).appendingPathComponent("drive_c")
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else { return [] }
        var result: [WindowsExecutable] = []
        for case let item as URL in enumerator {
            let canonicalItem = item.standardizedFileURL
            let relative = canonicalItem.pathComponents.dropFirst(root.standardizedFileURL.pathComponents.count).joined(separator: "/")
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { if values.isDirectory == true { enumerator.skipDescendants() }; continue }
            let lower = relative.lowercased()
            if ["windows", "users", "programdata"].contains(lower.split(separator: "/").first.map(String.init) ?? "") { enumerator.skipDescendants(); continue }
            if item.pathExtension.lowercased() == "exe", !["unins", "uninstall", "crash", "updat"].contains(where: { item.lastPathComponent.lowercased().hasPrefix($0) }) {
                result.append(WindowsExecutable(name: item.deletingPathExtension().lastPathComponent, relativePath: relative))
            }
        }
        return result.sorted { a, b in
            let aIsTally = a.name.lowercased() == "tally", bIsTally = b.name.lowercased() == "tally"
            if aIsTally != bIsTally { return aIsTally }
            return a.relativePath.localizedStandardCompare(b.relativePath) == .orderedAscending
        }
    }

    public func launch(profile: AppProfile) async throws -> RunResult {
        let operationLock = try lock(profile); defer { busy.remove(profile.id); withExtendedLifetime(operationLock) {} }
        let executable = try store.executableURL(for: profile)
        guard FileManager.default.fileExists(atPath: executable.path) else { throw PorticoError.message("The saved executable is missing. Choose it again from the installed files.") }
        let log = logURL(profile, action: "launch")
        try await ensureIdle(profile, log: log)
        let code = try await run(profile, arguments: [executable.path], log: log, directory: executable.deletingLastPathComponent())
        // Launchers may exit before their child app. Hold the environment until all Wine clients close.
        _ = try await server(profile, arguments: ["-w"], log: log)
        return result(code: code, log: log)
    }

    public func runTool(profile: AppProfile, tool: String) async throws -> RunResult {
        guard ["winecfg", "notepad"].contains(tool) else { throw PorticoError.message("Unknown Windows tool.") }
        let operationLock = try lock(profile); defer { busy.remove(profile.id); withExtendedLifetime(operationLock) {} }
        let log = logURL(profile, action: tool)
        try await ensureIdle(profile, log: log); try await initialize(profile, log: log)
        let code = try await run(profile, arguments: [tool], log: log, directory: store.prefixURL(for: profile))
        _ = try await server(profile, arguments: ["-w"], log: log)
        return result(code: code, log: log)
    }

    public func uninstall(profile: AppProfile) async throws -> RunResult {
        let operationLock = try lock(profile)
        defer { busy.remove(profile.id); withExtendedLifetime(operationLock) {} }
        let log = logURL(profile, action: "uninstall")
        try await ensureIdle(profile, log: log)
        // Refuse to open an uninstaller unless a verified recovery point exists.
        _ = try await makeSnapshot(profile, log: log)
        let code = try await run(profile, arguments: ["uninstaller"], log: log, directory: store.prefixURL(for: profile))
        let waitCode = try await server(profile, arguments: ["-w"], log: log)
        return result(code: code == 0 ? waitCode : code, log: log)
    }

    public func checkIdleForRemoval(profile: AppProfile) async throws {
        let operationLock = try lock(profile)
        defer { busy.remove(profile.id); withExtendedLifetime(operationLock) {} }
        try await ensureIdle(profile, log: logURL(profile, action: "remove-check"))
    }

    public func waitForExistingSession(profile: AppProfile) async throws {
        guard FileManager.default.fileExists(atPath: store.prefixURL(for: profile).appendingPathComponent("system.reg").path) else { return }
        let operationLock = try lock(profile)
        defer { busy.remove(profile.id); withExtendedLifetime(operationLock) {} }
        let code = try await server(profile, arguments: ["-w"], log: logURL(profile, action: "reconnect"))
        guard code == 0 else { throw PorticoError.message("Could not reconnect to this Windows environment. Check its runtime and session log.") }
    }

    public func stop(profile: AppProfile) async throws {
        // WINEPREFIX scopes this to the selected app, never killall or a global wineserver.
        let code = try await server(profile, arguments: ["-k"], log: logURL(profile, action: "stop"), timeout: 10)
        guard code == 0 else { throw PorticoError.message("Wine could not stop this environment. Close the Windows windows and try again.") }
    }
    public func snapshots(profile: AppProfile) throws -> [PrefixSnapshot] {
        let directories = (try? FileManager.default.contentsOfDirectory(at: store.backupDirectory(for: profile), includingPropertiesForKeys: nil)) ?? []
        return directories.compactMap { try? JSONDecoder().decode(PrefixSnapshot.self, from: Data(contentsOf: $0.appendingPathComponent("snapshot.json"))) }.filter { $0.profileID == profile.id }.sorted { $0.createdAt > $1.createdAt }
    }
    public func snapshot(profile: AppProfile) async throws -> PrefixSnapshot {
        let operationLock = try lock(profile); defer { busy.remove(profile.id); withExtendedLifetime(operationLock) {} }
        let log = logURL(profile, action: "backup")
        try await ensureIdle(profile, log: log)
        return try await makeSnapshot(profile, log: log)
    }
    private func makeSnapshot(_ profile: AppProfile, log: URL) async throws -> PrefixSnapshot {
        let source = store.prefixURL(for: profile)
        guard FileManager.default.fileExists(atPath: source.appendingPathComponent("system.reg").path) else { throw PorticoError.message("Install an application before creating a backup.") }
        var snapshot = PrefixSnapshot(profileID: profile.id, runtimePath: profile.runtimePath)
        let integrity = try SnapshotIntegrity.capture(source)
        let destination = store.snapshotURL(for: snapshot)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: destination) } }
        let code = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), arguments: [source.path, destination.appendingPathComponent("prefix").path], log: log)
        guard code == 0 else { throw PorticoError.message("Backup could not finish. The original environment is unchanged.") }
        try integrity.verify(destination.appendingPathComponent("prefix"))
        let manifest = destination.appendingPathComponent("integrity.json")
        try JSONEncoder().encode(integrity).write(to: manifest, options: .atomic)
        snapshot.integritySHA256 = try EngineInstaller.digest(of: manifest)
        try JSONEncoder().encode(snapshot).write(to: destination.appendingPathComponent("snapshot.json"), options: .atomic)
        completed = true
        return snapshot
    }
    public func restore(profile: AppProfile, snapshot: PrefixSnapshot) async throws -> URL {
        guard snapshot.profileID == profile.id else { throw PorticoError.message("This backup belongs to a different app.") }
        guard snapshot.runtimePath == profile.runtimePath else { throw PorticoError.message("This backup uses a different Wine runtime. Restore it with its original runtime to avoid changing the Windows environment.") }
        let operationLock = try lock(profile); defer { busy.remove(profile.id); withExtendedLifetime(operationLock) {} }
        let log = logURL(profile, action: "restore")
        try await ensureIdle(profile, log: log)
        guard let expectedDigest = snapshot.integritySHA256 else {
            throw PorticoError.message("This older backup has no integrity record. It is preserved for manual recovery, but cannot be restored automatically. Create a new verified backup from a known working environment.")
        }
        let manifest = store.snapshotURL(for: snapshot).appendingPathComponent("integrity.json")
        guard try EngineInstaller.digest(of: manifest) == expectedDigest else {
            throw PorticoError.message("The backup integrity record is damaged. Nothing was changed.")
        }
        let integrity = try JSONDecoder().decode(SnapshotIntegrity.self, from: Data(contentsOf: manifest))
        let source = store.snapshotURL(for: snapshot).appendingPathComponent("prefix")
        try integrity.verify(source)
        guard FileManager.default.fileExists(atPath: source.appendingPathComponent("system.reg").path) else { throw PorticoError.message("The backup is incomplete. Nothing was changed.") }
        let destination = store.prefixURL(for: profile)
        let staging = destination.deletingLastPathComponent().appendingPathComponent("restore-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }
        let code = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), arguments: [source.path, staging.path], log: log)
        guard code == 0 else { throw PorticoError.message("Could not prepare the restore. The current environment is unchanged.") }
        try integrity.verify(staging)
        let rollback = destination.deletingLastPathComponent().appendingPathComponent("before-restore-\(UUID().uuidString)")
        let existed = FileManager.default.fileExists(atPath: destination.path)
        if existed { try FileManager.default.moveItem(at: destination, to: rollback) }
        do { try FileManager.default.moveItem(at: staging, to: destination) }
        catch { if existed { try? FileManager.default.moveItem(at: rollback, to: destination) }; throw error }
        return rollback
    }
}
