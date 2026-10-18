import Foundation

/// Allowlisted facts only. Do not add raw errors, profile fields, paths, or logs.
public enum SupportReport {
    public enum LibraryState: String, Sendable { case loading, ready, unavailable }
    public static func render(appVersion: String, build: String, profiles: [AppProfile],
                              libraryState: LibraryState, activeOperations: Int) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        #if arch(arm64)
        let architecture = "Apple silicon (arm64)"
        #elseif arch(x86_64)
        let architecture = "Intel (x86_64)"
        #else
        let architecture = "Other"
        #endif
        // Bundle version fields must not become arbitrary free-text export channels.
        func version(_ value: String) -> String {
            let valid = !value.isEmpty && value.count <= 40 && value.allSatisfy { "0123456789.-".contains($0) }
            return valid ? value : "unknown"
        }
        return """
        Portico support report · format 1
        App version: \(version(appVersion)) (build \(version(build)))
        macOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)
        App architecture: \(architecture)
        Library state: \(libraryState.rawValue)
        App profiles: \(profiles.count)
        Profiles with a launch executable selected: \(profiles.filter { $0.executablePath != nil }.count)
        Active operations: \(max(0, activeOperations))

        This report contains no company data, app names, licence details, file paths,
        profile identifiers, raw errors, or session logs. Nothing is uploaded.
        Compatibility and licence activation are not established by this report.
        """
    }
}
