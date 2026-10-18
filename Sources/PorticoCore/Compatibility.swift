import Foundation
import Darwin
import Metal

public struct MacHardware: Sendable {
    public let chip: String
    public let appleSilicon: Bool
    public let memoryGB: Int
    public let graphics: String
    public let macOS: String
    public let freeStorageGB: Int?

    public init(chip: String, appleSilicon: Bool, memoryGB: Int, graphics: String, macOS: String, freeStorageGB: Int?) {
        self.chip = chip; self.appleSilicon = appleSilicon; self.memoryGB = memoryGB
        self.graphics = graphics; self.macOS = macOS; self.freeStorageGB = freeStorageGB
    }
    public static func detect(storageURL: URL) -> Self {
        func value(_ key: String) -> String? {
            var size = 0
            guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return nil }
            var buffer = [CChar](repeating: 0, count: size)
            guard sysctlbyname(key, &buffer, &size, nil, 0) == 0 else { return nil }
            return String(cString: buffer)
        }
        var arm: Int32 = 0; var length = MemoryLayout<Int32>.size
        let silicon = sysctlbyname("hw.optional.arm64", &arm, &length, nil, 0) == 0 && arm == 1
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let free = (try? FileManager.default.attributesOfFileSystem(forPath: storageURL.path)[.systemFreeSize]) as? NSNumber
        return Self(chip: value("machdep.cpu.brand_string") ?? (silicon ? "Apple silicon" : "Intel Mac"),
                    appleSilicon: silicon, memoryGB: Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824),
                    graphics: MTLCreateSystemDefaultDevice()?.name ?? "Metal GPU not detected",
                    macOS: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
                    freeStorageGB: free.map { Int($0.uint64Value / 1_073_741_824) })
    }
    public var guidance: [String] {
        var items = [appleSilicon
            ? "For the pinned Intel Wine build, Apple silicon needs Rosetta. Keep working apps on their current runtime."
            : "This is an Intel Mac. Portico's Intel release and each runtime need separate validation; Apple-silicon results do not establish compatibility here."]
        items.append(memoryGB < 16 ? "With less than 16 GB RAM, start with one lightweight Windows app at a time. This is a conservative suggestion, not an app requirement." : "Your memory is a reasonable starting point for business apps. RAM alone cannot predict gaming performance.")
        if let freeStorageGB, freeStorageGB < 20 { items.append("Less than 20 GB is currently free on the library volume. Make room before large installs: backups need additional space. This is a planning threshold, not a measured app requirement.") }
        items.append("The current Portico engine has no configured D3DMetal or DXVK gaming preset. Do not apply CrossOver or Steam Deck ratings directly to it.")
        return items
    }
}

public struct CompatibilitySuggestion: Identifiable, Sendable {
    public enum Category: String, CaseIterable, Sendable { case business = "Business apps", games = "Games" }
    public let id: String
    public let name: String
    public let category: Category
    public let status: String
    public let detail: String
    public let source: URL

    public static func catalog(for mac: MacHardware) -> [Self] {
        [
            Self(id: "tally", name: "TallyPrime 5.1", category: .business,
                 status: mac.appleSilicon ? "Limited user-reported evidence" : "Not tested on Intel",
                 detail: "A user reported Tally working in the M1 Pro / macOS 15.8.1 / Wine 11.0_1 setup after installing 5.1. This is not certification for your Mac or for printing, add-ons and licence workflows. Use the version your licence supports.",
                 source: URL(string: "https://help.tallysolutions.com/tally-prime/release-notes-tally-prime/release-notes-tallyprime-5-1/")!),
            Self(id: "libreoffice", name: "LibreOffice", category: .business, status: "Native Mac version available",
                 detail: "For documents and spreadsheets, start with the publisher's \(mac.appleSilicon ? "Apple Silicon" : "Intel") Mac download. Check current system requirements and document fidelity. Its Windows build has not been tested in Portico.",
                 source: URL(string: "https://www.libreoffice.org/download/")!),
            Self(id: "business", name: "Other Windows business apps", category: .business, status: "Check exact version first",
                 detail: "Look up the precise release in WineHQ. Apps needing Windows drivers, USB licence tokens, Office automation or services need individual testing. Install a trial in a separate environment with copied data.",
                 source: URL(string: "https://www.winehq.org/help")!),
            Self(id: "openttd", name: "OpenTTD", category: .games, status: "Native Mac version available",
                 detail: "A transport-management game with an official macOS download. Prefer that build and check its current requirements. The Windows edition is not tested in Portico.",
                 source: URL(string: "https://www.openttd.org/downloads/openttd-releases/latest")!),
            Self(id: "older", name: "Older single-player Windows games", category: .games, status: "Experimental · per-title testing",
                 detail: "Start with a demo or a game you own, without required anti-cheat. Check its exact version, graphics API and Mac reports. No Windows game is currently verified by Portico's test suite.",
                 source: URL(string: "https://www.winehq.org/help")!),
            Self(id: "modern", name: "Modern DirectX 11 / 12 games", category: .games, status: "Gaming runtime recommended",
                 detail: "Review CrossOver's Mac compatibility database for a purpose-built gaming runtime. Its graphics backends and fixes differ from Portico's standalone Wine engine; a CrossOver rating is not a Portico rating.",
                 source: URL(string: "https://www.codeweavers.com/compatibility")!),
            Self(id: "anticheat", name: "Games requiring kernel anti-cheat", category: .games, status: "Do not recommend in Portico",
                 detail: "Low-level Windows anti-cheat is a major compatibility barrier. More RAM or a faster GPU does not solve it. Check the publisher's supported platforms before buying.",
                 source: URL(string: "https://support.codeweavers.com/anti-cheat")!)
        ]
    }
}
