import SwiftUI
import PorticoCore

enum Palette {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let ink = Color.primary
    static let muted = Color.secondary
    static let indigo = Color.accentColor
    static let teal = Color(nsColor: .systemTeal)
    static let line = Color(nsColor: .separatorColor)
}
struct StatusPill: View {
    let title: String
    var color: Color = Palette.teal
    var body: some View {
        HStack(spacing: 6) { Circle().fill(color).frame(width: 5, height: 5); Text(title).font(.system(size: 11, weight: .semibold)) }
            .foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 6).background(color.opacity(0.09), in: Capsule())
    }
}
struct AppTile: View {
    let name: String
    var size: CGFloat = 48
    var executable: URL? = nil
    @State private var appIcon: NSImage?
    var body: some View {
        ZStack {
            if let appIcon {
                Image(nsImage: appIcon).resizable().interpolation(.high).scaledToFit().padding(size * 0.04)
            } else {
                RoundedRectangle(cornerRadius: size * 0.23).fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                Image(systemName: "app.dashed").font(.system(size: size * 0.48, weight: .regular)).foregroundStyle(.secondary)
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
        .task(id: executable) {
            appIcon = nil
            guard let executable else { return }
            let data = await Task.detached(priority: .utility) { WindowsIcon.load(executable: executable) }.value
            guard !Task.isCancelled else { return }
            appIcon = data.flatMap(NSImage.init(data:))
        }
    }
}
struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line.opacity(0.35)))
    }
}
