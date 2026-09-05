import SwiftUI

enum StoryStyle {
    static let copper = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.95, green: 0.65, blue: 0.37, alpha: 1) : UIColor(red: 0.52, green: 0.25, blue: 0.09, alpha: 1) })
    static let parchment = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1) : UIColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1) })
    static let ink = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.90, green: 0.84, blue: 0.72, alpha: 1) : UIColor(red: 0.16, green: 0.10, blue: 0.06, alpha: 1) })
    static let border = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.52, green: 0.31, blue: 0.16, alpha: 1) : UIColor(red: 0.62, green: 0.43, blue: 0.22, alpha: 1) })
    static let seal = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.46, green: 0.12, blue: 0.08, alpha: 1) : UIColor(red: 0.50, green: 0.10, blue: 0.06, alpha: 1) })
    static let gilded = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.92, green: 0.68, blue: 0.30, alpha: 1) : UIColor(red: 0.66, green: 0.39, blue: 0.10, alpha: 1) })
    static let night = Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? UIColor(red: 0.045, green: 0.04, blue: 0.035, alpha: 1) : UIColor(red: 0.10, green: 0.065, blue: 0.040, alpha: 1) })
    static let candle = Color(red: 0.98, green: 0.78, blue: 0.39)
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

/// The campaign library is intentionally a different surface from a document page:
/// it is the player's table, where a campaign can be picked up and played.
struct CampaignTablePage<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 32)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(CampaignTableBackground().ignoresSafeArea())
    }
}

struct CampaignTableBackground: View {
    var body: some View {
        ZStack {
            StoryStyle.night
            LinearGradient(colors: [StoryStyle.seal.opacity(0.40), .clear, Color.black.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [StoryStyle.candle.opacity(0.12), .clear], center: .top, startRadius: 20, endRadius: 380)
        }
    }
}

struct CampaignTableHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(StoryStyle.seal)
                Circle().stroke(StoryStyle.gilded, lineWidth: 1.5)
                Image(systemName: "shield.lefthalf.filled").font(.title3.weight(.black)).foregroundStyle(StoryStyle.candle)
            }.frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text("AETHER TABLE").font(.caption2.bold()).tracking(2.5).foregroundStyle(StoryStyle.candle)
                Text("Campaign Chronicle").font(.system(.title3, design: .serif, weight: .bold)).foregroundStyle(.white)
            }
            Spacer()
            Image(systemName: "book.closed.fill").foregroundStyle(StoryStyle.candle.opacity(0.86)).accessibilityHidden(true)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AetherTable Campaign Chronicle")
    }
}

struct CampaignPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(StoryStyle.parchment, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).stroke(StoryStyle.gilded.opacity(0.8), lineWidth: 1)
                RoundedRectangle(cornerRadius: 14).inset(by: 5).stroke(StoryStyle.border.opacity(0.32), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.34), radius: 12, y: 8)
            .foregroundStyle(StoryStyle.ink)
    }
}

struct WaxSeal: View {
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles").font(.caption2)
            Text(label.uppercased()).font(.caption2.bold()).tracking(1.2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(StoryStyle.seal, in: Capsule())
        .overlay(Capsule().stroke(StoryStyle.gilded.opacity(0.85), lineWidth: 1))
    }
}

struct CharacterSheetHeader: View {
    let step: Int
    let total: Int
    let section: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("CHARACTER SHEET", systemImage: "person.text.rectangle.fill")
                    .font(.caption.bold()).tracking(1.6).foregroundStyle(StoryStyle.copper)
                Spacer()
                Text("PAGE \(step) / \(total)").font(.caption2.bold().monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(alignment: .lastTextBaseline) {
                Text(section).font(.system(.largeTitle, design: .serif, weight: .bold))
                Spacer()
                Text("LEVEL 1").font(.caption.bold()).tracking(1.4).foregroundStyle(StoryStyle.copper)
            }
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule().fill(index < step ? StoryStyle.copper : StoryStyle.border.opacity(0.16)).frame(height: 5)
                }
            }
        }
        .padding(18)
        .background(StoryStyle.parchment.opacity(0.86), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(StoryStyle.border.opacity(0.46), lineWidth: 1))
    }
}

struct SheetSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(StoryStyle.copper)
                Text(title.uppercased()).font(.caption.bold()).tracking(1.5).foregroundStyle(StoryStyle.copper)
                Rectangle().fill(StoryStyle.border.opacity(0.28)).frame(height: 1)
            }
            content
        }
        .padding(16)
        .background(StoryStyle.parchment.opacity(0.76), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(StoryStyle.border.opacity(0.38), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            Image("CharacterSheetLineArt").resizable().scaledToFill().frame(width: 170, height: 105).opacity(0.19).blendMode(.screen).allowsHitTesting(false).clipped()
        }
    }
}

struct SheetStat: View {
    let label: String
    let value: String
    let detail: String
    var body: some View {
        VStack(spacing: 3) {
            Text(label.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(StoryStyle.copper)
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(StoryStyle.ink)
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 82)
        .background(StoryStyle.parchment.opacity(0.78), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(StoryStyle.border.opacity(0.42), lineWidth: 1))
    }
}

/// An original AetherTable sheet frame: square, double-ruled, and deliberately
/// paper-like so it reads as a game aid rather than another application card.
struct OrnateSheetPanel<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.caption.weight(.bold))
                Text(title.uppercased()).font(.caption.bold()).tracking(1.35)
                Rectangle().fill(StoryStyle.ink.opacity(0.38)).frame(height: 1)
            }.foregroundStyle(StoryStyle.ink)
            content
        }
        .padding(15)
        .background(StoryStyle.parchment.opacity(0.94))
        .overlay {
            Rectangle().stroke(StoryStyle.ink.opacity(0.78), lineWidth: 1.25)
            Rectangle().inset(by: 5).stroke(StoryStyle.border.opacity(0.45), lineWidth: 1)
        }
        .overlay {
            Image("CharacterSheetLineArt")
                .resizable()
                .scaledToFill()
                .opacity(0.16)
                .blendMode(.screen)
                .allowsHitTesting(false)
                .clipped()
        }
        .overlay(alignment: .topLeading) { Circle().fill(StoryStyle.copper).frame(width: 6, height: 6).padding(3) }
        .overlay(alignment: .bottomTrailing) { Circle().fill(StoryStyle.copper).frame(width: 6, height: 6).padding(3) }
        .foregroundStyle(StoryStyle.ink)
    }
}

struct SheetAbilityTile: View {
    let ability: String
    let score: Int
    let modifier: Int
    let proficient: Bool
    var body: some View {
        VStack(spacing: 2) {
            Text(ability.uppercased()).font(.caption2.bold()).tracking(1).lineLimit(1)
            ZStack {
                Circle().stroke(StoryStyle.ink.opacity(0.72), lineWidth: 1.3).frame(width: 48, height: 48)
                Text(modifier.formatted(.number.sign(strategy: .always()))).font(.system(.title2, design: .rounded, weight: .bold))
            }.padding(.vertical, 2)
            Text("\(score)").font(.headline.monospacedDigit())
            Label(proficient ? "Save trained" : "Save", systemImage: proficient ? "checkmark.circle.fill" : "circle")
                .font(.caption2).foregroundStyle(proficient ? StoryStyle.copper : .secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 118)
        .padding(.vertical, 8)
        .background(StoryStyle.parchment.opacity(0.70))
        .overlay(Rectangle().stroke(StoryStyle.border.opacity(0.56), lineWidth: 1))
    }
}
struct StoryCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(StoryStyle.parchment.opacity(0.90))
            .overlay {
                Rectangle().stroke(StoryStyle.ink.opacity(0.72), lineWidth: 1.2)
                Rectangle().inset(by: 5).stroke(StoryStyle.border.opacity(0.42), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) { Circle().fill(StoryStyle.copper).frame(width: 6, height: 6).padding(3) }
            .overlay(alignment: .bottomTrailing) { Circle().fill(StoryStyle.copper).frame(width: 6, height: 6).padding(3) }
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
