import XCTest
@testable import PorticoCore

final class PorticoCoreTests: XCTestCase {
    var root: URL!
    var store: LibraryStore!
    var runtime: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("Portico Tests \(UUID().uuidString)")
        store = try LibraryStore(rootURL: root)
        let bin = root.appendingPathComponent("Fake Runtime/bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        runtime = bin.appendingPathComponent("wine")
        // Fixture emulates process protocol, not Windows compatibility.
        let wine = """
        #!/bin/sh
        if [ "$1" = "wineboot" ]; then
          mkdir -p "$WINEPREFIX/drive_c/windows/system32"
          printf 'registry' > "$WINEPREFIX/system.reg"
          exit 0
        fi
        printf 'PREFIX=%s\\nCWD=%s\\nARG=%s\\n' "$WINEPREFIX" "$PWD" "$1"
        if [ -f "$WINEPREFIX/slow" ]; then sleep 1; fi
        exit 0
        """
        try writeExecutable(wine, to: runtime)
        try writeExecutable("#!/bin/sh\nexit 0\n", to: bin.appendingPathComponent("wineserver"))
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }
    func writeExecutable(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
    func profile() -> AppProfile { AppProfile(name: "Test & Business", runtimePath: runtime.path) }
    func prepare(_ profile: AppProfile) throws -> URL {
        let prefix = store.prefixURL(for: profile)
        try FileManager.default.createDirectory(at: prefix.appendingPathComponent("drive_c/Program Files/Test App"), withIntermediateDirectories: true)
        try Data("registry".utf8).write(to: prefix.appendingPathComponent("system.reg"))
        try Data().write(to: prefix.appendingPathComponent(".portico-ready"))
        return prefix
    }
    func testLibraryRoundTripAndCorruptionDoesNotOverwrite() throws {
        let app = profile(); try store.save([app]); XCTAssertEqual(try store.load(), [app])
        let broken = Data("{bad json".utf8); try broken.write(to: store.libraryURL)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: store.libraryURL), broken)
    }
    func testExecutablePathRejectsTraversalAndSymlinkEscape() throws {
        let app = profile(); let prefix = try prepare(app)
        XCTAssertThrowsError(try LibraryStore.containedURL(relativePath: "../outside.exe", root: prefix))
        XCTAssertThrowsError(try LibraryStore.containedURL(relativePath: "/tmp/outside.exe", root: prefix))
        try FileManager.default.createSymbolicLink(at: prefix.appendingPathComponent("escape"), withDestinationURL: root)
        XCTAssertThrowsError(try LibraryStore.containedURL(relativePath: "escape/outside.exe", root: prefix))
    }
    func testLaunchPreservesSpacesAndShellCharactersAndWorkingDirectory() async throws {
        var app = profile(); let prefix = try prepare(app)
        app.executablePath = "Program Files/Test App/a;$(touch INJECTED).exe"
        let executable = try store.executableURL(for: app)
        try Data("MZ".utf8).write(to: executable)
        let result = try await WineService(store: store).launch(profile: app)
        XCTAssertEqual(result.exitCode, 0)
        let text = try String(contentsOf: result.logURL)
        let workingPath = text.components(separatedBy: "\n").first(where: { $0.hasPrefix("CWD=") })!.dropFirst(4)
        XCTAssertEqual(URL(fileURLWithPath: String(workingPath)).resolvingSymlinksInPath().standardizedFileURL,
                       executable.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL)
        XCTAssertTrue(text.contains("ARG=" + executable.path))
        XCTAssertTrue(text.contains("PREFIX=" + prefix.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: executable.deletingLastPathComponent().appendingPathComponent("INJECTED").path))
    }
    func testDiscoveryFiltersSystemAndUninstallerButFindsTally() async throws {
        let app = profile(); let prefix = try prepare(app)
        for path in ["drive_c/Program Files/Test App/Tally.exe", "drive_c/Program Files/Test App/uninstall.exe", "drive_c/windows/system32/cmd.exe"] {
            let file = prefix.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: file)
        }
        let found = try await WineService(store: store).discoverExecutables(profile: app)
        XCTAssertEqual(found.map(\.name), ["Tally"])
    }
    func testSnapshotRestorePreservesPriorDataAndDoesNotFollowSymlinks() async throws {
        let app = profile(); let prefix = try prepare(app); let service = WineService(store: store)
        let data = prefix.appendingPathComponent("drive_c/accounts.txt")
        try Data("before".utf8).write(to: data)
        let external = root.appendingPathComponent("external")
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: prefix.appendingPathComponent("drive_c/shared"), withDestinationURL: external)
        let snapshot = try await service.snapshot(profile: app)
        let copiedLink = store.snapshotURL(for: snapshot).appendingPathComponent("prefix/drive_c/shared")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: copiedLink.path), external.path)
        try Data("after".utf8).write(to: data)
        let rollback = try await service.restore(profile: app, snapshot: snapshot)
        XCTAssertEqual(try String(contentsOf: data), "before")
        XCTAssertEqual(try String(contentsOf: rollback.appendingPathComponent("drive_c/accounts.txt")), "after")
    }
    func testForeignSnapshotCannotReplaceEnvironment() async throws {
        let app = profile(); _ = try prepare(app)
        let foreign = PrefixSnapshot(profileID: UUID(), runtimePath: runtime.path)
        do { _ = try await WineService(store: store).restore(profile: app, snapshot: foreign); XCTFail("Should refuse") }
        catch { XCTAssertTrue(error.localizedDescription.contains("different app")) }
    }
    func testSecondOperationCannotSnapshotWhileAppRuns() async throws {
        var app = profile(); let prefix = try prepare(app)
        app.executablePath = "Program Files/Test App/app.exe"
        try Data().write(to: try store.executableURL(for: app)); try Data().write(to: prefix.appendingPathComponent("slow"))
        let service = WineService(store: store)
        let running = Task { [app] in try await service.launch(profile: app) }
        try await Task.sleep(nanoseconds: 100_000_000)
        do { _ = try await service.snapshot(profile: app); XCTFail("Snapshot must refuse a running app") }
        catch { XCTAssertTrue(error.localizedDescription.contains("already running")) }
        _ = try await running.value
    }
    func testRuntimeValidationRejectsIncompleteBundle() throws {
        let orphan = root.appendingPathComponent("wine"); try writeExecutable("#!/bin/sh\nexit 0", to: orphan)
        XCTAssertThrowsError(try WineService.validateRuntime(at: orphan))
        XCTAssertNoThrow(try WineService.validateRuntime(at: runtime))
    }
    func testChecksumAndActionableDiagnostics() throws {
        let file = root.appendingPathComponent("hash"); try Data("abc".utf8).write(to: file)
        XCTAssertEqual(try EngineInstaller.digest(of: file), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertTrue(Diagnostics.explain("Bad CPU type in executable", exitCode: 1)!.contains("Rosetta"))
        XCTAssertTrue(Diagnostics.explain("err:module:import_dll library missing.dll not found", exitCode: 1)!.contains("component"))
        XCTAssertNil(Diagnostics.explain("normal output", exitCode: 0))
    }
    func testTimeoutReturnsInsteadOfHanging() async throws {
        let helper = root.appendingPathComponent("wait"); try writeExecutable("#!/bin/sh\nexec sleep 10\n", to: helper)
        do { _ = try await ProcessRunner.run(helper, arguments: [], log: root.appendingPathComponent("timeout.log"), timeout: 0.1); XCTFail("Expected timeout") }
        catch { XCTAssertTrue(error.localizedDescription.contains("timed out")) }
    }
}
