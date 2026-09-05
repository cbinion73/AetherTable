import SwiftUI

enum StoryStyle {
    static let copper = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.95, green: 0.65, blue: 0.37, alpha: 1) : UIColor(red: 0.52, green: 0.25, blue: 0.09, alpha: 1) })
    static let parchment = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1) : UIColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1) })
    static let ink = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.90, green: 0.84, blue: 0.72, alpha: 1) : UIColor(red: 0.16, green: 0.10, blue: 0.06, alpha: 1) })
    static let border = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.52, green: 0.31, blue: 0.16, alpha: 1) : UIColor(red: 0.62, green: 0.43, blue: 0.22, alpha: 1) })
}

struct TabletopHeroArt: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("LibraryHero")
                .resizable()
                .scaledToFill()
                .frame(height: 250)
                .clipped()
            LinearGradient(colors: [.clear, Color.black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                Label("AETHER TABLE", systemImage: "die.face.5")
                    .font(.caption.bold()).tracking(2).foregroundStyle(.white.opacity(0.85))
                Text("Every story\nbegins at the table.")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(.white)
            }.padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(StoryStyle.border.opacity(0.8), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AetherTable tabletop fantasy artwork")
    }
}
struct StoryPage<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 22) { content }.padding(22).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity) }
            .background(StoryStyle.parchment.overlay(LinearGradient(colors: [StoryStyle.copper.opacity(0.05), .clear, StoryStyle.copper.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
}
struct StoryCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(StoryStyle.parchment.opacity(0.52), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(StoryStyle.border.opacity(0.55), lineWidth: 1))
            .foregroundStyle(StoryStyle.ink)
    }
}
struct StoryHeading: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) { Image(systemName: "shield.lefthalf.filled").font(.caption); Text(eyebrow.uppercased()).font(.caption.bold()).tracking(2) }.foregroundStyle(StoryStyle.copper)
            Text(title).font(.system(.largeTitle, design: .serif, weight: .bold)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
struct StoryAction: View {
    let title: String
    let detail: String
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
                Image(systemName: enabled ? "chevron.right" : "lock.fill").accessibilityHidden(true)
            }.multilineTextAlignment(.leading).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(16)
        }.buttonStyle(.plain).background(StoryStyle.parchment.opacity(0.58), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(StoryStyle.border.opacity(0.45), lineWidth: 1)).disabled(!enabled).opacity(enabled ? 1 : 0.65)
    }
}
