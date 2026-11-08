import SwiftUI

extension RGB {
    /// Light plate behind dark logos (§7.26).
    static let logoPlate = RGB(hex: 0xECEBF3)
}

/// A club logo at a fixed size. Dark logos sit on a light plate; without a logo (config-only club, offline)
/// it shows the club's initials on its colour.
struct ClubLogo: View {
    let club: Club?
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            if club?.needsLogoPlate == true {
                Circle().fill(RGB.logoPlate.color)
            }
            if let url = club?.logoURL {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        initials
                    }
                }
                .padding(club?.needsLogoPlate == true ? size * 0.14 : 0)
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: club?.displayName ?? ""))
    }

    private var initials: some View {
        Circle()
            .fill((club?.graphicColor ?? .violet).color.opacity(0.35))
            .overlay {
                Text(verbatim: String((club?.shortName ?? "?").prefix(3)))
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.5)
            }
    }
}

/// W/L squares for the last results, newest last.
struct FormStrip: View {
    let wins: [Bool]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(wins.enumerated()), id: \.offset) { _, won in
                Text(won ? "W" : "L")
                    .font(.caption2.weight(.heavy))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(won ? Theme.win : Theme.loss)
                    .background((won ? Theme.win : Theme.loss).opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: wins.map { $0 ? "W" : "L" }.joined(separator: " ")))
        .accessibilityHint("Last results, oldest first")
    }
}

/// A section title with an optional trailing action ("See all").
struct SectionHeader: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        AdaptiveStack(verticalAlignment: .firstTextBaseline, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .font(.subheadline.weight(.medium))
                .tint(Theme.violetHigh)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Horizontal filter chips (prototype: "All clubs / My club", stat categories).
struct ChipBar<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    /// An accessibility identifier per chip, for UI tests.
    var identifier: ((Value) -> String)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.value) { option in
                    let selected = option.value == selection
                    Button {
                        selection = option.value
                    } label: {
                        Text(verbatim: option.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 34)
                            .foregroundStyle(selected ? Theme.ink : Theme.textSecondary)
                            .background(selected ? Theme.textPrimary : Theme.surface2, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier(identifier?(option.value) ?? "")
                }
            }
            .padding(.horizontal)
        }
    }
}
