import SwiftUI
import AppKit
import PorticoCore

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var search = ""
    @State private var confirmRestore: PrefixSnapshot?
    @State private var confirmStop = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 235)
            VStack(spacing: 0) {
                topbar
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let message = model.notice {
                            HStack(alignment: .top) { Image(systemName: "info.circle.fill").foregroundStyle(Palette.teal); Text(message).font(.system(size: 12)).textSelection(.enabled); Spacer(); Button { model.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }
                                .padding(14).background(Palette.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        }
                        if let profile = model.selected { detail(profile) } else { welcome }
                    }.padding(32).frame(maxWidth: 1120, alignment: .leading).frame(maxWidth: .infinity)
                }
            }.background(Palette.canvas)
        }
        .sheet(isPresented: $model.showAdd) { AddAppView().environmentObject(model) }
        .sheet(isPresented: $model.showRuntime) { RuntimeView().environmentObject(model) }
        .sheet(isPresented: $model.showLog) { LogView().environmentObject(model) }
        .alert("Something needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            if model.latestLog != nil { Button("View log") { model.openLog() } }
            Button("OK", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .alert("Stop the Windows app?", isPresented: $confirmStop) {
            Button("Stop app", role: .destructive) { if let profile = model.selected { model.stop(profile) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Unsaved work may be lost. This stops only the selected app's Windows environment.") }
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit().frame(width: 34, height: 34)
                Text("portico").font(.system(size: 27, weight: .semibold, design: .rounded)).tracking(-0.8).foregroundStyle(.white)
            }.padding(.top, 46).padding(.horizontal, 23).padding(.bottom, 33)
            Button { model.selectedID = nil } label: {
                HStack(spacing: 11) { Image(systemName: "square.grid.2x2"); Text("Overview"); Spacer() }
                    .font(.system(size: 13, weight: .medium)).padding(12).foregroundStyle(.white.opacity(model.selectedID == nil ? 1 : 0.65))
                    .background(model.selectedID == nil ? Color.white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 9))
            }.buttonStyle(.plain).padding(.horizontal, 12)
            HStack { Text("YOUR APPS").font(.system(size: 10, weight: .semibold)).tracking(1.7); Spacer(); Text("\(model.profiles.count)").font(.system(size: 10, weight: .medium)) }.foregroundStyle(.white.opacity(0.35)).padding(.horizontal, 24).padding(.top, 29).padding(.bottom, 12)
            if !model.profiles.isEmpty {
                HStack { Image(systemName: "magnifyingglass"); TextField("Find an app", text: $search, prompt: Text("Find an app").foregroundColor(.white.opacity(0.5))).textFieldStyle(.plain).foregroundStyle(.white) }.font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).padding(9).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 7)).padding(.horizontal, 18).padding(.bottom, 9)
            }
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(model.profiles.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { profile in
                        Button { model.selectedID = profile.id } label: {
                            HStack(spacing: 10) {
                                AppTile(name: profile.name, size: 33, executable: try? model.store.executableURL(for: profile))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.name).font(.system(size: 12, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                                    Text(model.operations[profile.id] != nil ? "In use" : profile.executablePath == nil ? "Finish setup" : "Installed").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                                }
                                Spacer(minLength: 0)
                                if model.operations[profile.id] != nil { Circle().fill(Color.mint).frame(width: 5, height: 5) }
                            }.padding(10).background(model.selectedID == profile.id ? .white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        }.buttonStyle(.plain)
                    }
                    if model.profiles.isEmpty { Text("Your Windows apps will\nappear here.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.3)).lineSpacing(5).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.top, 10) }
                }.padding(.horizontal, 12)
            }
            Button { model.showAdd = true } label: { Label("Add Windows app", systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(PrimaryStyle()).padding(18)
            Divider().overlay(.white.opacity(0.08))
            Button { model.showRuntime = true } label: {
                HStack(spacing: 10) { Image(systemName: "cpu").font(.system(size: 17)); VStack(alignment: .leading, spacing: 4) { Text("Runtime setup").font(.system(size: 12, weight: .medium)); Text(model.runtimes.isEmpty ? "Connect Wine to get started" : "\(model.runtimes.count) runtime\(model.runtimes.count == 1 ? "" : "s") available").font(.system(size: 10)).foregroundStyle(.white.opacity(0.38)) }; Spacer(); Image(systemName: "chevron.right").font(.system(size: 9)) }.foregroundStyle(.white.opacity(0.8)).padding(22)
            }.buttonStyle(.plain)
        }.background(Palette.navy)
    }
    private var topbar: some View {
        HStack {
            Text(model.selected?.name ?? "Your workspace").font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.ink)
            Spacer()
            StatusPill(title: "Runs on this Mac", color: Palette.muted)
            Rectangle().fill(Palette.line).frame(width: 1, height: 18).padding(.horizontal, 8)
            Button { model.showRuntime = true } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 15)).foregroundStyle(Palette.muted) }.buttonStyle(.plain).help("Runtime setup")
        }.padding(.horizontal, 32).frame(height: 62).background(.white.opacity(0.75)).overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 27) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 17) {
                    Text("A LITTLE LESS FRICTION").font(.system(size: 10, weight: .semibold)).tracking(2.1).foregroundStyle(Palette.indigo)
                    (Text("Windows apps.\n").foregroundStyle(Palette.ink) + Text("At home on your Mac.").foregroundStyle(Palette.indigo)).font(.system(size: 34, weight: .semibold, design: .rounded)).tracking(-1.0).fixedSize(horizontal: false, vertical: true)
                    Text("A local workspace for TallyPrime and the Windows tools your business runs on.").font(.system(size: 14)).foregroundStyle(Palette.muted).lineSpacing(5).frame(maxWidth: 380, alignment: .leading)
                    HStack(spacing: 10) {
                        Button { if model.runtimes.isEmpty { model.showRuntime = true } else { model.showAdd = true } } label: { Label(model.runtimes.isEmpty ? "Set up Portico" : "Add your first app", systemImage: "plus") }.buttonStyle(PrimaryStyle())
                        Link("Get TallyPrime ↗", destination: URL(string: "https://tallysolutions.com/download/")!).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                    }.padding(.top, 3)
                }.frame(maxWidth: .infinity, alignment: .leading)
                WindowArtwork()
            }.padding(.vertical, 14)
            HStack(alignment: .top, spacing: 14) {
                FeatureCard(icon: "laptopcomputer", title: "Keep work local", text: "Apps and files stay on your Mac. Work offline when your app and licence allow it.")
                FeatureCard(icon: "square.stack.3d.up", title: "Give each app its space", text: "Separate Windows environments keep each app's settings and dependencies together.")
                FeatureCard(icon: "clock.arrow.circlepath", title: "Have a way back", text: "Back up an environment before changes, then restore it if an update goes wrong.")
            }
            Surface {
                HStack(alignment: .top, spacing: 18) {
                    AppTile(name: "TallyPrime", size: 49)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("Start with TallyPrime").font(.system(size: 16, weight: .semibold)); StatusPill(title: "Your first workflow", color: Palette.indigo) }
                        Text("Use the official installer and a copy of your company data. Verify printing, exports and add-ons before moving your daily accounts.").font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                        Text("Portico manages Wine. It does not guarantee every Windows app or device will work.").font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.top, 3)
                    }
                }
            }
            HStack { Image(systemName: "externaldrive"); Text("Local library"); Spacer(); Button("Show in Finder") { model.reveal(model.store.rootURL) }.buttonStyle(.plain).foregroundStyle(Palette.indigo) }.font(.system(size: 11)).foregroundStyle(Palette.muted)
        }
    }
    private func detail(_ profile: AppProfile) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 18) {
                AppTile(name: profile.name, size: 73, executable: try? model.store.executableURL(for: profile))
                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.name).font(.system(size: 29, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
                    StatusPill(title: model.operations[profile.id] != nil ? "In use" : profile.executablePath == nil ? "Setup needed" : "Installed", color: profile.executablePath == nil ? .orange : Palette.teal)
                }
                Spacer()
                if model.selectedBusy { if model.stoppable.contains(profile.id) { Button("Stop app") { confirmStop = true }.buttonStyle(SecondaryStyle()) } }
                else { Button { model.launch(profile) } label: { Label("Launch app", systemImage: "play.fill") }.buttonStyle(PrimaryStyle()).disabled(profile.executablePath == nil) }
            }.padding(.vertical, 6)
            if let operation = model.operations[profile.id] {
                HStack(spacing: 12) { ProgressView().controlSize(.small); Text(operation).font(.system(size: 13)); Spacer() }.padding(17).background(Palette.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }
            Surface {
                VStack(alignment: .leading, spacing: 17) {
                    Text("Launch settings").font(.system(size: 15, weight: .semibold))
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("WINDOWS EXECUTABLE").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(Palette.muted)
                            if !model.executables.isEmpty {
                                Picker("Program", selection: Binding(get: { profile.executablePath ?? "" }, set: { model.chooseExecutable($0) })) {
                                    Text("Choose the installed app…").tag("")
                                    if let existing = profile.executablePath, !model.executables.contains(where: { $0.relativePath == existing }) { Text(existing).tag(existing) }
                                    ForEach(model.executables) { Text($0.relativePath).tag($0.relativePath) }
                                }.labelsHidden().frame(maxWidth: .infinity).disabled(model.selectedBusy)
                            } else { Text(profile.executablePath ?? "Install the app, then select its executable.").font(.system(size: 12)).foregroundStyle(Palette.muted).textSelection(.enabled) }
                        }
                        Spacer()
                        Button("Browse…") { model.browseExecutable(profile) }.buttonStyle(SecondaryStyle()).disabled(model.selectedBusy)
                    }
                    Divider()
                    HStack { Text("Pinned runtime").font(.system(size: 12, weight: .medium)); Spacer(); Text(URL(fileURLWithPath: profile.runtimePath).pathComponents.first(where: { $0.hasSuffix(".app") }) ?? "Wine").font(.system(size: 12)).foregroundStyle(Palette.muted) }
                    Text("This app keeps its chosen runtime. Installing another engine does not switch it automatically.").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
            }
            HStack(spacing: 12) {
                Button { model.install(profile) } label: { Label("Run installer", systemImage: "square.and.arrow.down") }.buttonStyle(SecondaryStyle()).disabled(model.selectedBusy)
                Button { model.reveal(model.store.prefixURL(for: profile).appendingPathComponent("drive_c")) } label: { Label("Open C: drive", systemImage: "folder") }.buttonStyle(SecondaryStyle())
                Button { model.runTool(profile, tool: "winecfg") } label: { Label("Windows settings", systemImage: "gearshape") }.buttonStyle(SecondaryStyle()).disabled(model.selectedBusy)
                Spacer()
                Button { model.openLog() } label: { Label("Session log", systemImage: "doc.text.magnifyingglass") }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.indigo)
            }
            Surface {
                VStack(alignment: .leading, spacing: 17) {
                    HStack { VStack(alignment: .leading, spacing: 6) { Text("Backups & recovery").font(.system(size: 15, weight: .semibold)); Text("Close the Windows app before backing up. External folders are not included.").font(.system(size: 11)).foregroundStyle(Palette.muted) }; Spacer(); Button("Create backup") { model.backup(profile) }.buttonStyle(SecondaryStyle()).disabled(model.selectedBusy) }
                    if model.backups.isEmpty {
                        HStack(spacing: 11) { Image(systemName: "clock.arrow.circlepath").font(.system(size: 24)).foregroundStyle(Palette.line); Text("No backups yet. Save a known working setup before making changes.").font(.system(size: 12)).foregroundStyle(Palette.muted) }.padding(.vertical, 14)
                    } else {
                        ForEach(model.backups.prefix(5)) { backup in
                            HStack { Image(systemName: "archivebox").foregroundStyle(Palette.teal); Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)); Spacer(); Button(backup.integritySHA256 == nil ? "Legacy backup" : "Restore") { confirmRestore = backup }.disabled(model.selectedBusy || backup.integritySHA256 == nil).help(backup.integritySHA256 == nil ? "This older backup has no integrity record. Its files are preserved for manual recovery." : "Verify and restore this backup") }.padding(.vertical, 5)
                        }
                        Button("Show all backup files") { model.reveal(model.store.backupDirectory(for: profile)) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.indigo)
                    }
                }
            }
            if !profile.notes.isEmpty { HStack(alignment: .top, spacing: 9) { Image(systemName: "info.circle"); Text(profile.notes).lineSpacing(4) }.font(.system(size: 12)).foregroundStyle(Palette.muted).padding(.horizontal, 3) }
        }
    }
}
