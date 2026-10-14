import XCTest
@testable import PorticoCore

final class ReleaseReadinessTests: XCTestCase {
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
