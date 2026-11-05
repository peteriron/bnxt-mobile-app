import SwiftUI

/// Shown when a screen has nothing to show: no network and nothing cached (§4 Offline).
struct LoadFailedView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Can't load league data", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Check your connection and try again.")
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("load.retry")
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("load.failed")
    }
}

/// "Offline · updated 14:05": the data on screen came from the cache (§4 Offline).
struct CachedNote: View {
    let date: Date

    var body: some View {
        Label {
            Text("Offline · updated \(date.formatted(.relative(presentation: .named)))")
        } icon: {
            Image(systemName: "icloud.slash")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 4)
        .accessibilityIdentifier("load.cached")
    }
}
