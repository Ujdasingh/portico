import SwiftUI
import PorticoCore

struct AddAppView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var portable = false
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack { AppTile(name: name.isEmpty ? "App" : name, size: 54); VStack(alignment: .leading, spacing: 6) { Text("Add a Windows app").font(.system(size: 23, weight: .semibold, design: .rounded)); Text("A new environment. A place in your library.").font(.system(size: 12)).foregroundStyle(Palette.muted) }; Spacer() }
            VStack(alignment: .leading, spacing: 9) { Text("App name").font(.system(size: 12, weight: .medium)); TextField("For example, TallyPrime", text: $name).textFieldStyle(.roundedBorder).controlSize(.large) }
            VStack(alignment: .leading, spacing: 9) {
                Text("How would you like to add it?").font(.system(size: 12, weight: .medium))
                Picker("Installation type", selection: $portable) { Text("Run an installer").tag(false); Text("Copy a portable app").tag(true) }.pickerStyle(.segmented)
                Text(portable ? "Select an .exe in its own dedicated folder. Portico copies that entire folder so DLLs and resources stay together." : "Select the official .exe or .msi installer. Complete its normal Windows setup, then choose the installed program.").font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }
            if model.runtimes.isEmpty {
                Label("Connect a Wine runtime before adding an app.", systemImage: "cpu").font(.system(size: 12)).foregroundStyle(Palette.indigo)
            } else {
                VStack(alignment: .leading, spacing: 8) { Text("Runtime for this app").font(.system(size: 12, weight: .medium)); Picker("Runtime", selection: $model.preferredRuntime) { ForEach(model.runtimes) { Text($0.displayName).tag($0.url.path) } }.labelsHidden() }
            }
            Text("Windows applications can access files your Mac account can access. A Wine environment is not a security sandbox.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3)
            Divider()
            HStack { Link("Official TallyPrime download ↗", destination: URL(string: "https://tallysolutions.com/download/")!).font(.system(size: 11)); Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(.bordered); Button(model.runtimes.isEmpty ? "Set up runtime" : "Choose file…") { if model.runtimes.isEmpty { dismiss(); model.showRuntime = true } else { model.addApp(name: name, portable: portable) } }.buttonStyle(.borderedProminent) }
        }.padding(30).frame(width: 570).background(Palette.canvas)
    }
}

struct RuntimeView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack { Image(systemName: "cpu").font(.system(size: 28)).foregroundStyle(Palette.indigo).frame(width: 55, height: 55).background(Palette.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 14)); VStack(alignment: .leading, spacing: 6) { Text("Connect the engine").font(.system(size: 24, weight: .semibold, design: .rounded)); Text("Wine runs the Windows code. Portico takes care of the setup.").font(.system(size: 12)).foregroundStyle(Palette.muted) } }
            Surface {
                VStack(alignment: .leading, spacing: 13) {
                    HStack { Text("Wine 11.0").font(.system(size: 17, weight: .semibold)); Spacer(); StatusPill(title: "Open source", color: Palette.indigo) }
                    Text("Download the pinned upstream Mac build, verified against its published SHA-256 checksum. About 177 MB to download; more space is needed after extraction.").font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                    Text("This upstream build is not notarized. macOS may require an explicit trust decision in Privacy & Security. Portico never disables Gatekeeper. Some apps also need the upstream GStreamer multimedia dependency.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
                    HStack { Button { model.downloadRuntime() } label: { Label("Download Wine", systemImage: "arrow.down.circle") }.buttonStyle(.borderedProminent).disabled(model.runtimeProgress != nil); Link("Upstream release ↗", destination: URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.0_1")!).font(.system(size: 11)); Spacer() }
                }
            }
            HStack { Text("Already have Wine?").font(.system(size: 13, weight: .medium)); Spacer(); Button("Choose Wine app…") { model.selectRuntime() }.buttonStyle(.bordered).disabled(model.runtimeProgress != nil) }
            if !model.runtimes.isEmpty {
                Picker("Selected runtime", selection: $model.preferredRuntime) { ForEach(model.runtimes) { Text($0.displayName).tag($0.url.path) } }
                Text(model.preferredRuntime).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted).textSelection(.enabled).lineLimit(3)
                HStack { Button("1. Check engine") { model.checkRuntime() }.buttonStyle(.bordered); Button("2. Open Windows test") { model.createTestApp() }.buttonStyle(.bordered) }.disabled(model.runtimeProgress != nil)
            }
            if let progress = model.runtimeProgress { HStack(spacing: 11) { ProgressView().controlSize(.small); Text(progress).font(.system(size: 12)) }.padding(13).frame(maxWidth: .infinity, alignment: .leading).background(Palette.indigo.opacity(0.06), in: RoundedRectangle(cornerRadius: 9)) }
            if let check = model.runtimeCheck { Text(check).font(.system(size: 12)).foregroundStyle(Palette.muted).textSelection(.enabled).lineSpacing(4) }
            HStack { Text("Each app keeps the runtime it was created with.").font(.system(size: 11)).foregroundStyle(Palette.muted); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(.borderedProminent) }
        }.padding(30).frame(width: 640).background(Palette.canvas).interactiveDismissDisabled(model.runtimeProgress != nil)
    }
}

struct LogView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { VStack(alignment: .leading, spacing: 6) { Text("Session log").font(.system(size: 22, weight: .semibold, design: .rounded)); Text("Logs stay on this Mac. Review them before sharing: they may contain file paths or app data.").font(.system(size: 11)).foregroundStyle(Palette.muted) }; Spacer() }
            ScrollView([.horizontal, .vertical]) { Text(model.latestLog == nil ? "No session log yet. Logs appear after an app operation." : model.logText.isEmpty ? "The process did not write any diagnostic output." : model.logText).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(15) }.frame(height: 390).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            HStack { Button("Refresh") { if let url = model.latestLog { model.logText = WineService.tail(url) } }; Button("Show log file") { if let url = model.latestLog { NSWorkspace.shared.activateFileViewerSelecting([url]) } }.disabled(model.latestLog == nil); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(.borderedProminent) }
        }.padding(28).frame(width: 760).background(Palette.canvas)
    }
}

struct SupportReportView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Support report").font(.system(size: 23, weight: .semibold))
            Text("Review the report below before saving or sharing it. Nothing is uploaded automatically.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
            ScrollView {
                Text(model.supportReport).font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }.frame(height: 290).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button("Refresh") { model.openSupportReport() }.buttonStyle(.bordered)
                Button("Save report…") { model.saveSupportReport() }.buttonStyle(.bordered)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(.borderedProminent)
            }
        }.padding(28).frame(width: 660).background(Palette.canvas)
    }
}
