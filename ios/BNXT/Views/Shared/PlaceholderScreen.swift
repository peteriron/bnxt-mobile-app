import SwiftUI

/// Temporary content for tabs whose feature hasn't been built yet (REQUIREMENTS.md §8).
struct PlaceholderScreen: View {
    let title: LocalizedStringKey

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Large title in the brand display face (the prototype's look). The nav bar keeps an
                // inline title until nav-bar styling lands in Phase 2.
                Text(title)
                    .font(Theme.display(.largeTitle))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("BNXT League \(Season.current.label)")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.lime)
                Text("This screen is coming soon.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .accessibilityElement(children: .contain)
        }
        .background(Theme.ink)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
