import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PorticoCore

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [AppProfile] = []
    @Published var selectedID: UUID?
    @Published var runtimes: [WineRuntime] = []
    @Published var preferredRuntime = ""
    @Published var operations: [UUID: String] = [:]
    @Published var stoppable: Set<UUID> = []
    private var stopRequested: Set<UUID> = []
    @Published var backups: [PrefixSnapshot] = []
    @Published var executables: [WindowsExecutable] = []
    @Published var error: String?
    @Published var notice: String?
    @Published var latestLog: URL?
    @Published var showAdd = false
    @Published var showRuntime = false
    @Published var runtimeProgress: String?
    @Published var runtimeCheck: String?
    @Published var showLog = false
    @Published var logText = ""
    @Published var storageFailed = false
    let store: LibraryStore
    let service: WineService
    private var librarySession: LibrarySession?

    init() {
        let portableRoot = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Portico Data")
        let root = ProcessInfo.processInfo.environment["PORTICO_HOME"].map { URL(fileURLWithPath: $0) }
            ?? (FileManager.default.fileExists(atPath: portableRoot.appendingPathComponent(".portable-library").path) ? portableRoot.resolvingSymlinksInPath() : nil)
            ?? (Bundle.main.object(forInfoDictionaryKey: "PorticoLibraryPath") as? String).map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Portico")
        do { store = try LibraryStore(rootURL: root) }
        catch {
            // Display a recovery screen, never silently start a new permanent library.
            store = try! LibraryStore(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("Portico-error-\(UUID().uuidString)"))
            self.error = "Cannot open the Portico library: \(error.localizedDescription)"; storageFailed = true
        }
        service = WineService(store: store)
        do {
            if !storageFailed { librarySession = try LibrarySession(root: store.rootURL) }
            profiles = try store.load()
        }
        catch { self.error = "The library could not be opened. Your files are untouched. \(error.localizedDescription)"; storageFailed = true }
        selectedID = profiles.first?.id
        if !storageFailed { refreshRuntimes() }
        if let configured = ProcessInfo.processInfo.environment["PORTICO_WINE"], let runtime = try? WineService.validateRuntime(at: URL(fileURLWithPath: configured)) {
            addRuntime(runtime); preferredRuntime = runtime.url.path
        }
        if !storageFailed {
            for profile in profiles {
                perform(profile, status: "Checking previous session…", canStop: true) {
                    try await self.service.waitForExistingSession(profile: profile)
                }
            }
        }
    }
    var selected: AppProfile? { profiles.first { $0.id == selectedID } }
    var selectedBusy: Bool { selectedID.map { operations[$0] != nil } ?? false }
    var runningCount: Int { operations.count }
    @discardableResult
    func save() -> Bool {
        guard !storageFailed else { return false }
        do { try store.save(profiles); return true }
        catch { self.error = "Could not save the library: \(error.localizedDescription)"; return false }
    }
    func refreshRuntimes() {
        let found = WineService.detectRuntimes(extraRoot: store.rootURL.appendingPathComponent("Runtimes"))
        for runtime in found { addRuntime(runtime) }
        for profile in profiles {
            if let runtime = try? WineService.validateRuntime(at: URL(fileURLWithPath: profile.runtimePath)) { addRuntime(runtime) }
        }
        if preferredRuntime.isEmpty { preferredRuntime = runtimes.first?.url.path ?? "" }
    }
    func addRuntime(_ runtime: WineRuntime) {
        if !runtimes.contains(where: { $0.id == runtime.id }) { runtimes.append(runtime) }
    }
    func selectRuntime() {
        let panel = NSOpenPanel(); panel.title = "Choose a Wine runtime"
        panel.message = "Select Wine Stable.app or its wine executable. Keep its complete app bundle together."
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let runtime = try WineService.validateRuntime(at: url); addRuntime(runtime); preferredRuntime = runtime.url.path; runtimeCheck = nil }
        catch { self.error = error.localizedDescription }
    }
    func downloadRuntime() {
        guard runtimeProgress == nil else { return }
        runtimeProgress = "Preparing download…"
        Task {
            do {
                let runtime = try await EngineInstaller.install(into: store.rootURL.appendingPathComponent("Runtimes")) { [weak self] message in
                    Task { @MainActor in self?.runtimeProgress = message }
                }
                addRuntime(runtime); preferredRuntime = runtime.url.path
                runtimeProgress = nil; runtimeCheck = "Download verified. Run the engine check before installing an app."
            } catch { runtimeProgress = nil; self.error = error.localizedDescription }
        }
    }
    func checkRuntime() {
        guard !preferredRuntime.isEmpty, runtimeProgress == nil else { return }
        let path = preferredRuntime
        runtimeProgress = "Checking Wine and processor compatibility…"
        Task {
            let log = store.rootURL.appendingPathComponent("Logs/runtime-check.log")
            do {
                let code = try await ProcessRunner.run(URL(fileURLWithPath: path), arguments: ["--version"], log: log, timeout: 15)
                let output = WineService.tail(log)
                if code == 0 { runtimeCheck = "Wine starts successfully. A Windows app test will check the rest of the environment." }
                else { runtimeCheck = Diagnostics.explain(output, exitCode: code) }
                latestLog = log
            } catch { runtimeCheck = "Wine could not start: \(error.localizedDescription). Check Privacy & Security if macOS blocked the runtime." }
            runtimeProgress = nil
        }
    }
    func chooseWindowsFile(portable: Bool) -> URL? {
        let panel = NSOpenPanel(); panel.title = portable ? "Choose a portable Windows app" : "Choose a Windows installer"
        panel.message = portable ? "Portico copies the ENTIRE containing folder, including DLLs and data. Choose an app in its own dedicated folder, not your Downloads folder." : "Choose an official .exe or .msi installer. It runs locally in this app's own Wine environment."
        panel.allowedContentTypes = portable ? [UTType(filenameExtension: "exe")!] : [UTType(filenameExtension: "exe")!, UTType(filenameExtension: "msi")!]
        return panel.runModal() == .OK ? panel.url : nil
    }
    func addApp(name: String, portable: Bool) {
        guard !storageFailed, !preferredRuntime.isEmpty else { showRuntime = true; return }
        guard let source = chooseWindowsFile(portable: portable) else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var profile = AppProfile(name: cleanName.isEmpty ? source.deletingPathExtension().lastPathComponent : cleanName, runtimePath: preferredRuntime)
        profile.notes = profile.name.lowercased().contains("tally") ? "Test with copied company data before moving your daily work. Check printing, exports, add-ons and any signature token." : "Compatibility depends on the Windows app and its dependencies."
        profiles.append(profile); selectedID = profile.id
        guard save() else { profiles.removeAll { $0.id == profile.id }; selectedID = profiles.first?.id; return }
        showAdd = false
        if portable {
            perform(profile, status: "Copying portable app…") {
                let executable = try await self.service.importPortable(profile: profile, sourceURL: source)
                if let index = self.profiles.firstIndex(where: { $0.id == profile.id }) { self.profiles[index].executablePath = executable.relativePath; self.save() }
                self.notice = "Portable app copied. You can launch it from your library."
            }
        } else { install(profile, source: source) }
    }
    func install(_ profile: AppProfile, source: URL? = nil) {
        guard let file = source ?? chooseWindowsFile(portable: false) else { return }
        perform(profile, status: "Installer running · finish its Windows steps", canStop: true) {
            let result = try await self.service.install(profile: profile, installerURL: file)
            self.handle(result, profile: profile)
            let found = try await self.service.discoverExecutables(profile: profile)
            if let best = found.first(where: { $0.name.lowercased() == "tally" }) ?? (found.count == 1 ? found.first : nil),
               let index = self.profiles.firstIndex(where: { $0.id == profile.id }), self.profiles[index].executablePath == nil {
                self.profiles[index].executablePath = best.relativePath; self.save()
            }
            if result.exitCode == 0, !self.stopRequested.contains(profile.id) { self.notice = found.isEmpty ? "Installer closed. If the app was installed outside C:, reinstall it in this environment's C: drive." : "Installer closed. Review the launch executable below." }
        }
    }
    func launch(_ profile: AppProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) { profiles[index].lastLaunchedAt = Date(); save() }
        perform(profile, status: "Running · close the Windows app to finish", canStop: true) { self.handle(try await self.service.launch(profile: profile), profile: profile) }
    }
    func runTool(_ profile: AppProfile, tool: String) {
        perform(profile, status: "\(tool == "notepad" ? "Windows test" : "Windows settings") open", canStop: true) { self.handle(try await self.service.runTool(profile: profile, tool: tool), profile: profile) }
    }
    func createTestApp() {
        guard !preferredRuntime.isEmpty else { showRuntime = true; return }
        let profile = AppProfile(name: "Windows test", runtimePath: preferredRuntime, executablePath: "windows/system32/notepad.exe", notes: "Wine's included Windows Notepad. Use it to verify that Windows windows open on your Mac.")
        profiles.append(profile); selectedID = profile.id
        guard save() else { profiles.removeAll { $0.id == profile.id }; selectedID = profiles.first?.id; return }
        showRuntime = false
        runTool(profile, tool: "notepad")
    }
    func stop(_ profile: AppProfile) {
        guard stoppable.contains(profile.id) else { return }
        stopRequested.insert(profile.id)
        Task { do { try await service.stop(profile: profile) } catch { stopRequested.remove(profile.id); self.error = error.localizedDescription } }
    }
    func backup(_ profile: AppProfile) {
        perform(profile, status: "Creating backup…") {
            _ = try await self.service.snapshot(profile: profile)
            self.notice = "Windows environment backed up. Files stored outside it need their own backup."
        }
    }
    func restore(_ profile: AppProfile, snapshot: PrefixSnapshot) {
        perform(profile, status: "Restoring backup…") {
            let rollback = try await self.service.restore(profile: profile, snapshot: snapshot)
            self.notice = "Backup restored. The previous environment was preserved at \(rollback.lastPathComponent)."
        }
    }
    func perform(_ profile: AppProfile, status: String, canStop: Bool = false, operation: @escaping @MainActor () async throws -> Void) {
        guard operations[profile.id] == nil, !storageFailed else { return }
        operations[profile.id] = status; notice = nil
        if canStop { stoppable.insert(profile.id) }
        Task {
            do { try await operation() }
            catch { if !stopRequested.contains(profile.id) { self.error = error.localizedDescription } }
            operations[profile.id] = nil
            stoppable.remove(profile.id); stopRequested.remove(profile.id)
            findLatestLog(profile)
            await refreshDetails()
        }
    }
    func handle(_ result: RunResult, profile: AppProfile) {
        latestLog = result.logURL
        if stopRequested.contains(profile.id) { notice = "Windows environment stopped."; return }
        if result.exitCode != 0 { error = result.diagnostic ?? "The app exited unexpectedly." }
        else if let diagnostic = result.diagnostic { notice = diagnostic }
    }
    func refreshDetails() async {
        guard let profile = selected else { backups = []; executables = []; return }
        do {
            let nextBackups = try await service.snapshots(profile: profile)
            let nextExecutables = try await service.discoverExecutables(profile: profile)
            guard selectedID == profile.id else { return }
            backups = nextBackups; executables = nextExecutables; findLatestLog(profile)
        } catch { self.error = error.localizedDescription }
    }
    func chooseExecutable(_ relative: String) {
        guard let index = profiles.firstIndex(where: { $0.id == selectedID }), !selectedBusy else { return }
        profiles[index].executablePath = relative.isEmpty ? nil : relative; save()
    }
    func browseExecutable(_ profile: AppProfile) {
        let panel = NSOpenPanel(); panel.title = "Choose the installed program"
        let root = store.prefixURL(for: profile).appendingPathComponent("drive_c")
        panel.directoryURL = root; panel.allowedContentTypes = [UTType(filenameExtension: "exe")!]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard url.path.hasPrefix(root.path + "/") else { error = "Choose an executable inside this app's C: drive. Use Add app to import a separate portable app."; return }
        let relative = String(url.path.dropFirst(root.path.count + 1))
        do { _ = try LibraryStore.containedURL(relativePath: relative, root: root); chooseExecutable(relative) }
        catch { self.error = error.localizedDescription }
    }
    func findLatestLog(_ profile: AppProfile) {
        let logs = (try? FileManager.default.contentsOfDirectory(at: store.logDirectory(for: profile), includingPropertiesForKeys: nil)) ?? []
        latestLog = logs.filter { $0.pathExtension == "log" }.sorted { $0.lastPathComponent > $1.lastPathComponent }.first
    }
    func openLog() { if let profile = selected { findLatestLog(profile) }; guard let latestLog else { return }; logText = WineService.tail(latestLog); showLog = true }
    func reveal(_ url: URL) { NSWorkspace.shared.open(url) }
}
