import SwiftUI

/// Full-screen, non-dismissable: shown when the version policy requires an update (REQUIREMENTS §3.9).
struct UpdateRequiredView: View {
    let policy: VersionPolicy?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.lime)
                .accessibilityHidden(true)
            Text("Update required")
                .font(Theme.display(.largeTitle))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let message = policy?.message(for: Locale.current.language.languageCode?.identifier ?? "en") {
                Text(verbatim: message)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("This version of BNXT is no longer supported. Update the app to keep following your club.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if let url = policy?.storeURL {
                Link(destination: url) {
                    Text("Update in the App Store")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.lime)
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("update.required.button")
            } else {
                Text("Open the App Store and update BNXT.")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.ink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("update.required")
    }
}

/// The dismissable Home banner for an available update (REQUIREMENTS §3.9).
struct UpdateBanner: View {
    let latest: SemanticVersion
    let storeURL: URL?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(Theme.lime)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("A new version is available")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Version \(latest.description)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            if let storeURL {
                Link("Update", destination: storeURL)
                    .font(.subheadline.weight(.semibold))
                    .tint(Theme.lime)
                    .accessibilityIdentifier("update.banner.update")
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss")
            .accessibilityIdentifier("update.banner.dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("update.banner")
    }
}
