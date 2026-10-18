import SwiftUI
import PorticoCore

struct CompatibilityView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var category = CompatibilitySuggestion.Category.business
    @State private var search = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("This Mac & compatibility").font(.system(size: 24, weight: .semibold))
                    Text("Local hardware guidance · recommendations reviewed 18 October 2026").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Button("Refresh") { model.openCompatibility() }
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            if let mac = model.hardware {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Surface {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(mac.chip).font(.headline)
                                Text("\(mac.memoryGB) GB RAM · macOS \(mac.macOS) · \(mac.graphics)")
                                Text(mac.freeStorageGB.map { "\($0) GB free on the library volume" } ?? "Available library storage could not be read")
                                Text("\(model.runtimes.count) Wine runtime(s) detected. Existing app settings are not changed.").foregroundStyle(Palette.muted)
                            }.font(.system(size: 12))
                        }
                        ForEach(mac.guidance, id: \.self) { text in
                            Label(text, systemImage: "info.circle").font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                        }
                        Picker("Category", selection: $category) {
                            ForEach(CompatibilitySuggestion.Category.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                        TextField("Find an app, game or requirement", text: $search).textFieldStyle(.roundedBorder)
                        let suggestions = CompatibilitySuggestion.catalog(for: mac).filter {
                            $0.category == category && (search.isEmpty || ($0.name + " " + $0.detail).localizedCaseInsensitiveContains(search))
                        }
                        if suggestions.isEmpty { Text("No matching entry. Check WineHQ or the publisher for this exact app version.").font(.system(size: 12)) }
                        ForEach(suggestions) { item in
                            Surface {
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(item.name).font(.system(size: 16, weight: .semibold))
                                    Text(item.status).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.indigo)
                                    Text(item.detail).font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                                    Link("Publisher / reference ↗", destination: item.source).font(.system(size: 12))
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        Text("Suggestions are guidance, not benchmarks or compatibility guarantees. No hardware report is uploaded. Native Mac apps are installed outside Portico; Windows installers use Add Windows app.")
                            .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }.padding(2)
                }
            } else { ProgressView("Reading this Mac's configuration…").frame(maxWidth: .infinity, minHeight: 300) }
        }.padding(26).frame(width: 780, height: 650).background(Palette.canvas)
    }
}

struct RemovedAppsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Removed apps").font(.system(size: 23, weight: .semibold))
            Text("These entries are hidden from your library. Their environments and backups remain on disk; removing an entry does not free space.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
            ScrollView {
                VStack(spacing: 12) {
                    if model.removedProfiles.isEmpty { Text("No removed apps.").padding(30) }
                    ForEach(model.removedProfiles) { profile in
                        HStack {
                            Text(profile.name); Spacer()
                            Button("Recover") { model.recoverRemovedApp(profile) }
                            Button("Show files") { model.reveal(model.store.prefixURL(for: profile).deletingLastPathComponent()) }
                        }.padding(12).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
                    }
                }
            }.frame(height: 260)
            HStack { Spacer(); Button("Done") { dismiss() }.buttonStyle(.borderedProminent) }
        }.padding(26).frame(width: 620).background(Palette.canvas)
    }
}
