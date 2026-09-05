import SwiftUI

enum StoryStyle {
    static let copper = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.95, green: 0.65, blue: 0.37, alpha: 1) : UIColor(red: 0.52, green: 0.25, blue: 0.09, alpha: 1) })
    static let parchment = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1) : UIColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1) })
}
struct StoryPage<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 22) { content }.padding(22).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity) }
            .background(StoryStyle.parchment)
    }
}
struct StoryCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 12) { content }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.background, in: RoundedRectangle(cornerRadius: 20)) }
}
struct StoryHeading: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased()).font(.caption.bold()).tracking(2).foregroundStyle(StoryStyle.copper)
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
        }.buttonStyle(.plain).background(.background, in: RoundedRectangle(cornerRadius: 16)).disabled(!enabled).opacity(enabled ? 1 : 0.65)
    }
}
