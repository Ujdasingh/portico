import SwiftUI
import AppKit

@main
struct PorticoApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup("Portico") {
            ContentView().environmentObject(model).frame(minWidth: 980, minHeight: 700)
                .preferredColorScheme(.light)
                .onAppear { appDelegate.model = model; NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1140, height: 790)
        .commands {
            CommandGroup(replacing: .newItem) { Button("Add Windows App…") { model.showAdd = true }.keyboardShortcut("n") }
            CommandGroup(replacing: .help) { Button("Support Report…") { model.openSupportReport() } }
            CommandGroup(after: .appSettings) { Button("Runtime Setup…") { model.showRuntime = true }.keyboardShortcut(",") }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            guard let model, !model.operations.isEmpty || model.runtimeProgress != nil else { return .terminateNow }
            let alert = NSAlert(); alert.messageText = "An operation is still running"
            alert.informativeText = "Close your Windows apps and let installations or backups finish before quitting Portico."
            alert.addButton(withTitle: "Keep Portico Open")
            alert.runModal(); return .terminateCancel
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
