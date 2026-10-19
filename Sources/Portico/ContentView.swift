import SwiftUI
import AppKit
import PorticoCore

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    private enum SidebarItem: Hashable { case allApps, app(UUID) }
    @State private var search = ""
    @State private var confirmRestore: PrefixSnapshot?
    @State private var confirmStop = false
    @State private var confirmUninstall = false
    @State private var confirmRemove = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 245, max: 300)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let message = model.notice {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle").foregroundStyle(Color.accentColor)
                            Text(message).font(.callout).textSelection(.enabled)
                            Spacer()
                            Button { model.notice = nil } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).help("Dismiss notification").accessibilityLabel("Dismiss notification")
                        }.padding(14).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    if let profile = model.selected { detail(profile) } else { welcome }
                }.padding(28).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(Palette.canvas)
            .navigationTitle(model.selected?.name ?? "Library")
            .toolbar {
                ToolbarItemGroup {
                    Button { model.showAdd = true } label: { Label("Add Windows app", systemImage: "plus") }.help("Add Windows app (⌘N)")
                    Button { model.showRuntime = true } label: { Label("Runtime settings", systemImage: "gearshape") }.help("Runtime settings (⌘,)")
                    if model.selected != nil {
                        Button { model.openLog() } label: { Label("Session log", systemImage: "doc.text.magnifyingglass") }.help("View session log")
                    }
                }
            }
        }
        .sheet(isPresented: $model.showCompatibility) { CompatibilityView().environmentObject(model) }
        .sheet(isPresented: $model.showRemovedApps) { RemovedAppsView().environmentObject(model) }
        .sheet(isPresented: $model.showAdd) { AddAppView().environmentObject(model) }
        .sheet(isPresented: $model.showRuntime) { RuntimeView().environmentObject(model) }
        .sheet(isPresented: $model.showSupport) { SupportReportView().environmentObject(model) }
        .sheet(isPresented: $model.showLog) { LogView().environmentObject(model) }
        .alert("Something needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            if model.latestLog != nil { Button("View log") { model.openLog() } }
            Button("OK", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .alert("Stop the Windows app?", isPresented: $confirmStop) {
            Button("Stop app", role: .destructive) { if let profile = model.selected { model.stop(profile) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Unsaved work may be lost. This stops only the selected app's Windows environment.") }
        .alert("Open Windows uninstaller?", isPresented: $confirmUninstall) {
            Button("Back up and continue") { if let profile = model.selected { model.uninstall(profile) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Portico first creates a verified backup, then opens this environment's Windows uninstaller. Choose the program there. Uninstallers may delete app data; external folders are not backed up. For portable apps, use Remove from library instead.") }
        .alert("Remove this app from the library?", isPresented: $confirmRemove) {
            Button("Remove from library") { if let profile = model.selected { model.removeFromLibrary(profile) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The entry will be hidden. Its Windows environment, data, runtime and backups stay on disk. Recover it from Removed apps. This does not free disk space or surrender a licence.") }
        .alert("Restore this backup?", isPresented: Binding(get: { confirmRestore != nil }, set: { if !$0 { confirmRestore = nil } })) {
            Button("Restore") { if let profile = model.selected, let snapshot = confirmRestore { model.restore(profile, snapshot: snapshot) }; confirmRestore = nil }
            Button("Cancel", role: .cancel) { confirmRestore = nil }
        } message: { Text("Portico will preserve the current environment in a separate folder before replacing it. External data files are not included.") }
        .task(id: model.selectedID) { await model.refreshDetails() }
        .disabled(model.storageFailed || model.storageLoading)
        .overlay {
            if model.storageFailed {
                VStack(spacing: 18) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 36)).foregroundStyle(Palette.indigo)
                    Text("Library unavailable").font(.title2.bold())
                    Text(model.error ?? "Close the other Portico copy and reopen this app.").multilineTextAlignment(.center).frame(maxWidth: 470)
                    HStack {
                        Button("Show library folder") { model.reveal(model.store.rootURL) }
                        Button("Quit Portico") { NSApp.terminate(nil) }
                    }
                }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.canvas)
            } else if model.storageLoading {
                VStack(spacing: 18) {
                    ProgressView()
                    Text("Opening your library…").font(.title3.bold())
                    Text("If macOS asks for access to the library folder, allow it to continue.").foregroundStyle(Palette.muted)
                    Button("Quit Portico") { NSApp.terminate(nil) }
                }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.canvas)
            }
        }
    }
    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: Binding<SidebarItem?>(
                get: { model.selectedID.map(SidebarItem.app) ?? .allApps },
                set: { selection in
                    switch selection {
                    case .allApps: model.selectedID = nil
                    case .app(let id): model.selectedID = id
                    case nil: break
                    }
                }
            )) {
                Section("Library") {
                    Label("All Apps", systemImage: "square.grid.2x2").tag(SidebarItem.allApps)
                    Button { model.openCompatibility() } label: { Label("This Mac & Compatibility", systemImage: "laptopcomputer") }.buttonStyle(.plain)
                    Button { model.showRemovedApps = true } label: {
                        Label("Removed Apps", systemImage: "archivebox").badge(model.removedProfiles.count)
                    }.buttonStyle(.plain)
                }
                Section("Windows Apps") {
                    ForEach(model.activeProfiles.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { profile in
                        HStack(spacing: 10) {
                            AppTile(name: profile.name, size: 28, executable: try? model.store.executableURL(for: profile))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.name).lineLimit(1)
                                Text(model.operations[profile.id] != nil ? "In use" : profile.executablePath == nil ? "Setup needed" : "Installed")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4).tag(SidebarItem.app(profile.id))
                    }
                    if model.activeProfiles.isEmpty { Text("Add an app to get started.").font(.callout).foregroundStyle(.secondary) }
                    else if !search.isEmpty && !model.activeProfiles.contains(where: { $0.name.localizedCaseInsensitiveContains(search) }) {
                        Text("No matching apps").foregroundStyle(.secondary)
                    }
                }
            }.listStyle(.sidebar)
            .searchable(text: $search, placement: .sidebar, prompt: "Search apps")
            Divider()
            HStack {
                Label("\(model.activeProfiles.count) apps", systemImage: "square.stack").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { model.showAdd = true } label: { Image(systemName: "plus") }.buttonStyle(.borderless)
                    .help("Add Windows app").accessibilityLabel("Add Windows app")
            }.padding(14)
        }.navigationTitle("Portico")
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Apps").font(.largeTitle.weight(.bold))
                Text("Open a Windows app or add one to your library.").foregroundStyle(.secondary)
            }
            if model.activeProfiles.isEmpty {
                ContentUnavailableView {
                    Label("No Windows Apps", systemImage: "square.stack.3d.up")
                } description: { Text("Add an official Windows installer or a portable app to get started.") }
                actions: { Button("Add Windows App…") { model.showAdd = true }.buttonStyle(.borderedProminent) }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 16)], spacing: 16) {
                    ForEach(model.activeProfiles) { profile in
                        Button { model.selectedID = profile.id } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                AppTile(name: profile.name, size: 48, executable: try? model.store.executableURL(for: profile))
                                Text(profile.name).font(.headline).foregroundStyle(.primary)
                                Text(model.operations[profile.id] != nil ? "In use" : "View app").font(.callout).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                }
            }
            GroupBox {
                HStack(spacing: 12) {
                    Image(systemName: "laptopcomputer").font(.title2).foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Find the right fit for your Mac").font(.headline)
                        Text("View hardware details and app compatibility guidance.").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Explore…") { model.openCompatibility() }
                }.padding(8)
            }
            HStack { Label("Library stored on this Mac", systemImage: "internaldrive").foregroundStyle(.secondary); Spacer(); Button("Show in Finder") { model.reveal(model.store.rootURL) } }.font(.callout)
        }
    }
    private func detail(_ profile: AppProfile) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 18) {
                AppTile(name: profile.name, size: 64, executable: try? model.store.executableURL(for: profile))
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name).font(.largeTitle.weight(.bold))
                    Label(model.selectedBusy ? "In use" : profile.executablePath == nil ? "Setup needed" : "Installed",
                          systemImage: model.selectedBusy ? "circle.dotted" : profile.executablePath == nil ? "exclamationmark.circle" : "checkmark.circle")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if model.selectedBusy {
                    if model.stoppable.contains(profile.id) { Button("Stop…", role: .destructive) { confirmStop = true }.buttonStyle(.bordered) }
                } else {
                    Button { model.launch(profile) } label: { Label("Open", systemImage: "play.fill") }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(profile.executablePath == nil)
                }
            }.padding(.vertical, 8)
            if let operation = model.operations[profile.id] {
                HStack(spacing: 12) { ProgressView().controlSize(.small); Text(operation).font(.callout); Spacer() }
                    .padding(14).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
            Surface {
                VStack(alignment: .leading, spacing: 16) {
                    Label("App Tools", systemImage: "wrench.and.screwdriver").font(.headline)
                    HStack(spacing: 12) {
                        Button { model.install(profile) } label: { Label("Run Installer…", systemImage: "square.and.arrow.down") }.disabled(model.selectedBusy)
                        Button { model.reveal(model.store.prefixURL(for: profile).appendingPathComponent("drive_c")) } label: { Label("Open C: Drive", systemImage: "folder") }
                        Button { model.runTool(profile, tool: "winecfg") } label: { Label("Windows Settings", systemImage: "gearshape") }.disabled(model.selectedBusy)
                    }.buttonStyle(.bordered)
                    Divider()
                    DisclosureGroup("Launch Settings") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Picker("Program", selection: Binding(get: { profile.executablePath ?? "" }, set: { model.chooseExecutable($0) })) {
                                    Text("Choose an executable…").tag("")
                                    if let existing = profile.executablePath, !model.executables.contains(where: { $0.relativePath == existing }) { Text(existing).tag(existing) }
                                    ForEach(model.executables) { Text($0.relativePath).tag($0.relativePath) }
                                }.disabled(model.selectedBusy)
                                Button("Browse…") { model.browseExecutable(profile) }.disabled(model.selectedBusy)
                            }
                            LabeledContent("Runtime", value: URL(fileURLWithPath: profile.runtimePath).pathComponents.first(where: { $0.hasSuffix(".app") }) ?? "Wine")
                            Text("This app keeps its original runtime when you add another engine.").font(.caption).foregroundStyle(.secondary)
                        }.padding(.top, 12)
                    }.font(.callout)
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("Backups", systemImage: "clock.arrow.circlepath").font(.headline)
                        Spacer()
                        Button { model.backup(profile) } label: { Label("Create Backup", systemImage: "plus") }.disabled(model.selectedBusy)
                    }
                    Text("Close the Windows app first. Files outside its environment need a separate backup.").font(.callout).foregroundStyle(.secondary)
                    if model.backups.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "archivebox").font(.title2).foregroundStyle(.tertiary)
                            Text("No backups yet").foregroundStyle(.secondary)
                        }.padding(.vertical, 14)
                    } else {
                        ForEach(model.backups.prefix(5)) { backup in
                            HStack {
                                Image(systemName: "archivebox").foregroundStyle(.secondary)
                                Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                                Spacer()
                                Button(backup.integritySHA256 == nil ? "Legacy Backup" : "Restore…") { confirmRestore = backup }
                                    .disabled(model.selectedBusy || backup.integritySHA256 == nil)
                                    .help(backup.integritySHA256 == nil ? "Preserved for manual recovery; no integrity record is available." : "Verify and restore this backup")
                            }.font(.callout)
                        }
                        Button("Show All Backups in Finder") { model.reveal(model.store.backupDirectory(for: profile)) }.font(.callout)
                    }
                }
            }
            Surface {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Uninstall a program, or hide this library entry while retaining its files.").font(.callout).foregroundStyle(.secondary)
                        HStack {
                            Button("Uninstall Program…", role: .destructive) { confirmUninstall = true }.disabled(model.selectedBusy)
                            Button("Remove from Library…", role: .destructive) { confirmRemove = true }.disabled(model.selectedBusy)
                        }.buttonStyle(.bordered)
                    }.padding(.top, 12)
                } label: { Label("Manage App", systemImage: "ellipsis.circle").font(.headline) }
            }
            if !profile.notes.isEmpty {
                Label(profile.notes, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
