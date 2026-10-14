import SwiftUI
import PorticoCore

enum Palette {
    static let canvas = Color(red: 0.965, green: 0.967, blue: 0.978)
    static let ink = Color(red: 0.12, green: 0.15, blue: 0.23)
    static let muted = Color(red: 0.44, green: 0.47, blue: 0.55)
    static let indigo = Color(red: 0.34, green: 0.31, blue: 0.88)
    static let teal = Color(red: 0.05, green: 0.53, blue: 0.47)
    static let navy = Color(red: 0.075, green: 0.10, blue: 0.17)
    static let line = Color(red: 0.88, green: 0.89, blue: 0.93)
}
struct PrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 17).padding(.vertical, 11)
            .background(Palette.indigo.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}
struct SecondaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.ink)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(configuration.isPressed ? Palette.line : Color.white, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.line, lineWidth: 1))
    }
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
            RoundedRectangle(cornerRadius: size * 0.23).fill(LinearGradient(colors: [Palette.indigo, Color(red: 0.29, green: 0.43, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
            if name.lowercased().contains("test") { Image(systemName: "doc.text").font(.system(size: size * 0.4, weight: .medium)).foregroundStyle(.white) }
            else { Text(String(name.prefix(1)).uppercased()).font(.system(size: size * 0.45, weight: .semibold, design: .rounded)).foregroundStyle(.white) }
            }
        }.frame(width: size, height: size)
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
    var body: some View { content.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line.opacity(0.7), lineWidth: 1)) }
}
struct FeatureCard: View {
    let icon: String; let title: String; let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.indigo).frame(width: 38, height: 38).background(Palette.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(text).font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.padding(19).frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading).background(.white, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line.opacity(0.6)))
    }
}
struct WindowArtwork: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26).fill(Palette.indigo.opacity(0.06)).frame(width: 228, height: 200).rotationEffect(.degrees(-9))
            RoundedRectangle(cornerRadius: 18).fill(.white).frame(width: 200, height: 150).shadow(color: Palette.indigo.opacity(0.12), radius: 20, y: 12).rotationEffect(.degrees(7)).offset(x: 12, y: -5)
            VStack(spacing: 0) {
                HStack(spacing: 4) { ForEach(0..<3) { _ in Circle().fill(Color.white.opacity(0.45)).frame(width: 5, height: 5) }; Spacer() }.padding(12).background(Palette.indigo)
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 7) { ForEach(0..<4) { _ in RoundedRectangle(cornerRadius: 2).fill(Palette.indigo.opacity(0.14)).frame(width: 36, height: 5) } }.padding(.top, 3)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(Palette.ink.opacity(0.7)).frame(width: 64, height: 7)
                        ForEach(0..<3) { index in RoundedRectangle(cornerRadius: 2).fill(Palette.indigo.opacity(0.10)).frame(width: CGFloat(86 - index * 10), height: 5) }
                        HStack(alignment: .bottom, spacing: 6) { ForEach(0..<5) { i in RoundedRectangle(cornerRadius: 3).fill(i == 4 ? Palette.teal : Palette.indigo.opacity(0.3)).frame(width: 12, height: CGFloat([17, 28, 22, 37, 47][i])) } }
                    }
                }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(width: 210).background(.white).clipShape(RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.line)).rotationEffect(.degrees(-5)).offset(x: -10, y: 5)
            Image(systemName: "arrow.up.right").font(.system(size: 19, weight: .semibold)).foregroundStyle(.white).frame(width: 47, height: 47).background(Palette.teal, in: RoundedRectangle(cornerRadius: 14)).rotationEffect(.degrees(8)).offset(x: 92, y: 73)
        }.frame(width: 260, height: 245).accessibilityHidden(true)
    }
}
