import SwiftUI

enum StoryStyle {
    static let copper = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.95, green: 0.65, blue: 0.37, alpha: 1) : UIColor(red: 0.52, green: 0.25, blue: 0.09, alpha: 1) })
    static let parchment = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1) : UIColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1) })
    static let ink = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.90, green: 0.84, blue: 0.72, alpha: 1) : UIColor(red: 0.16, green: 0.10, blue: 0.06, alpha: 1) })
    static let border = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.52, green: 0.31, blue: 0.16, alpha: 1) : UIColor(red: 0.62, green: 0.43, blue: 0.22, alpha: 1) })
    static let seal = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.46, green: 0.12, blue: 0.08, alpha: 1) : UIColor(red: 0.50, green: 0.10, blue: 0.06, alpha: 1) })
    static let gilded = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.92, green: 0.68, blue: 0.30, alpha: 1) : UIColor(red: 0.66, green: 0.39, blue: 0.10, alpha: 1) })
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
            .background(TabletopPaper().ignoresSafeArea())
    }
}
struct StoryCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(.ultraThinMaterial.opacity(0.42), in: RoundedRectangle(cornerRadius: 22))
            .background(StoryStyle.parchment.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(LinearGradient(colors: [StoryStyle.gilded.opacity(0.76), StoryStyle.border.opacity(0.28)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: StoryStyle.ink.opacity(0.10), radius: 12, y: 5)
            .foregroundStyle(StoryStyle.ink)
    }
}
struct StoryHeading: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) { Image(systemName: "shield.lefthalf.filled").font(.caption); Text(eyebrow.uppercased()).font(.caption.bold()).tracking(2) }.foregroundStyle(StoryStyle.copper)
            Text(title).font(.system(.largeTitle, design: .serif, weight: .bold)).foregroundStyle(StoryStyle.ink).fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(LinearGradient(colors: [StoryStyle.copper, StoryStyle.gilded, .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
        }
    }
}

struct TabletopPaper: View {
    var body: some View {
        ZStack {
            StoryStyle.parchment
            LinearGradient(colors: [StoryStyle.copper.opacity(0.11), .clear, StoryStyle.seal.opacity(0.055)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color.white.opacity(0.28), .clear], center: .top, startRadius: 20, endRadius: 520)
        }
    }
}

struct TabletopPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(.white).padding(.horizontal, 18).padding(.vertical, 13)
            .background(LinearGradient(colors: [StoryStyle.seal, StoryStyle.copper], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
            .overlay(Capsule().stroke(StoryStyle.gilded.opacity(0.72), lineWidth: 1))
            .shadow(color: StoryStyle.seal.opacity(configuration.isPressed ? 0 : 0.28), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
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
