import XCTest
@testable import PorticoCore

final class ReleaseReadinessTests: XCTestCase {
    func testSupportReportDoesNotIncludePrivateProfileFields() {
        let profile = AppProfile(name: "Private Company", runtimePath: "/Users/secret/Wine/bin/wine",
                                 executablePath: "secret/accounts.exe", notes: "licence-secret")
        let report = SupportReport.render(appVersion: "0.2.2", build: "4", profiles: [profile],
                                          libraryState: .ready, activeOperations: 1)
        for secret in [profile.name, profile.runtimePath, profile.executablePath!, profile.notes, profile.id.uuidString] {
            XCTAssertFalse(report.contains(secret))
        }
        XCTAssertTrue(report.contains("App profiles: 1"))
        XCTAssertTrue(report.contains("Active operations: 1"))
        let malformed = SupportReport.render(appVersion: "private@example.com", build: "/Users/secret", profiles: [],
                                             libraryState: .unavailable, activeOperations: -1)
        XCTAssertFalse(malformed.contains("private@example.com"))
        XCTAssertFalse(malformed.contains("/Users/secret"))
        XCTAssertTrue(malformed.contains("App version: unknown"))
    }

    func testDuplicateLibraryIdentifiersNeverOverwriteMetadata() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LibraryStore(rootURL: root)
        let profile = AppProfile(name: "Test", runtimePath: "/runtime/wine")
        try store.save([profile])
        let original = try Data(contentsOf: store.libraryURL)
        XCTAssertThrowsError(try store.save([profile, profile]))
        XCTAssertEqual(try Data(contentsOf: store.libraryURL), original)
        let invalid = try JSONEncoder().encode([profile, profile])
        try invalid.write(to: store.libraryURL)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: store.libraryURL), invalid)
    }

    func testInvalidLibraryPathsAreRejectedBeforeSave() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LibraryStore(rootURL: root)
        let valid = AppProfile(name: "Test", runtimePath: "/runtime/wine", executablePath: "Program Files/app.exe")
        try store.save([valid])
        for path in ["../outside.exe", "/outside.exe", "", "bad\0.exe"] {
            var invalid = valid; invalid.executablePath = path
            XCTAssertThrowsError(try store.save([invalid]))
            XCTAssertEqual(try store.load(), [valid])
        }
        var invalid = valid; invalid.runtimePath = "relative/wine"
        XCTAssertThrowsError(try store.save([invalid]))
        XCTAssertEqual(try store.load(), [valid])
    }

    func testRemovedProfileRoundTripsAndCanBeRecoveredWithoutChangingPaths() throws {
        var profile = AppProfile(name: "Keep data", runtimePath: "/runtime/wine", executablePath: "app.exe")
        let original = profile
        profile.removedAt = Date()
        var recovered = try JSONDecoder().decode(AppProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertNotNil(recovered.removedAt)
        recovered.removedAt = nil
        XCTAssertEqual(recovered, original)
        let legacy = try JSONDecoder().decode(AppProfile.self, from: JSONEncoder().encode(original))
        XCTAssertNil(legacy.removedAt)
    }
    func testCompatibilityAdviceAdaptsToHardwareWithoutInventingGameSupport() {
        let low = MacHardware(chip: "Test", appleSilicon: true, memoryGB: 8, graphics: "GPU", macOS: "15.0", freeStorageGB: 10)
        XCTAssertTrue(low.guidance.contains { $0.contains("Rosetta") })
        XCTAssertTrue(low.guidance.contains { $0.contains("less than 16") })
        XCTAssertTrue(low.guidance.contains { $0.contains("Less than 20") })
        let intel = MacHardware(chip: "Intel", appleSilicon: false, memoryGB: 32, graphics: "GPU", macOS: "14.0", freeStorageGB: nil)
        XCTAssertFalse(intel.guidance.contains { $0.contains("Rosetta") })
        XCTAssertFalse(intel.guidance.contains { $0.contains("Less than 20") })
        let catalog = CompatibilitySuggestion.catalog(for: intel)
        XCTAssertEqual(catalog.first { $0.id == "tally" }?.status, "Not tested on Intel")
        XCTAssertEqual(catalog.first { $0.id == "anticheat" }?.status, "Do not recommend in Portico")
        XCTAssertTrue(catalog.filter { $0.category == .games }.allSatisfy { !$0.status.contains("Verified") })
        XCTAssertTrue(catalog.allSatisfy { $0.source.scheme == "https" })
    }

    func testLibraryLocationDoesNotTouchDiskBeforeBackgroundPreparation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(location: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        try store.prepare()
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Apps").path))
        XCTAssertEqual(try store.load(), [])
    }

    func testLibraryLifetimeLockRejectsDuplicateAndReleasesOnClose() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var session: LibrarySession? = try LibrarySession(root: root)
        XCTAssertNotNil(session)
        XCTAssertThrowsError(try LibrarySession(root: root))
        session = nil
        let reopened = try LibrarySession(root: root)
        withExtendedLifetime(reopened) { XCTAssertTrue(FileManager.default.fileExists(atPath: root.path)) }
    }
    func testIconExtractionReassemblesGroupAndRejectsMalformedOffsets() throws {
        var pe = fixture()
        let ico = try WindowsIcon.extract(from: pe)
        XCTAssertEqual(Array(ico.prefix(6)), [0, 0, 1, 0, 1, 0])
        XCTAssertEqual(Array(ico.suffix(4)), [10, 20, 30, 40])
        XCTAssertEqual(ico.count, 26)
        // Invalid data-entry RVA must never index into arbitrary file memory.
        put(&pe, 512 + 80, 0xfffffff0, 4)
        XCTAssertThrowsError(try WindowsIcon.extract(from: pe))
        XCTAssertThrowsError(try WindowsIcon.extract(from: Data(fixture().prefix(600))))
    }
    func testMalformedIconInputsNeverProduceAnImage() {
        for n in [0, 1, 2, 63, 128, 512, 4096] {
            XCTAssertThrowsError(try WindowsIcon.extract(from: Data(repeating: 255, count: n)))
        }
        var pe = fixture()
        put(&pe, 512 + 128 + 4, 65535, 2)
        XCTAssertThrowsError(try WindowsIcon.extract(from: pe))
    }
    private func put(_ data: inout Data, _ offset: Int, _ value: Int, _ size: Int) {
        for i in 0..<size { data[offset + i] = UInt8((value >> (8 * i)) & 255) }
    }
    private func fixture() -> Data {
        var d = Data(repeating: 0, count: 1024)
        put(&d, 0, 0x5a4d, 2); put(&d, 60, 64, 4)
        put(&d, 64, 0x4550, 4); put(&d, 70, 1, 2); put(&d, 84, 224, 2)
        put(&d, 88, 0x10b, 2); put(&d, 200, 4096, 4); put(&d, 204, 512, 4)
        put(&d, 324, 4096, 4); put(&d, 328, 512, 4); put(&d, 332, 512, 4)
        func entry(_ at: Int, _ id: Int, _ node: Int) { put(&d, 512 + at, id, 4); put(&d, 516 + at, node, 4) }
        put(&d, 526, 2, 2)
        entry(16, 3, 0x80000020); entry(24, 14, 0x800000a0)
        put(&d, 512 + 32 + 14, 1, 2); entry(48, 1, 0x80000038)
        put(&d, 512 + 56 + 14, 1, 2); entry(72, 1033, 80)
        put(&d, 512 + 80, 4096 + 120, 4); put(&d, 512 + 84, 4, 4)
        d.replaceSubrange(632..<636, with: [10, 20, 30, 40])
        put(&d, 512 + 160 + 14, 1, 2); entry(176, 1, 0x800000b8)
        put(&d, 512 + 184 + 14, 1, 2); entry(200, 1033, 208)
        put(&d, 512 + 208, 4096 + 128, 4); put(&d, 512 + 212, 20, 4)
        put(&d, 512 + 130, 1, 2); put(&d, 512 + 132, 1, 2)
        put(&d, 512 + 134, 16, 1); put(&d, 512 + 135, 16, 1)
        put(&d, 512 + 138, 1, 2); put(&d, 512 + 140, 32, 2)
        put(&d, 512 + 142, 4, 4); put(&d, 512 + 146, 1, 2)
        return d
    }
}
