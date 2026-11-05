import SwiftUI

/// Temporary content for tabs whose feature hasn't been built yet (REQUIREMENTS.md §8).
struct PlaceholderScreen<Header: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var header: Header

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                // Large title in the brand display face (the prototype's look).
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

extension PlaceholderScreen where Header == EmptyView {
    init(title: LocalizedStringKey) {
        self.init(title: title) { EmptyView() }
    }
}
