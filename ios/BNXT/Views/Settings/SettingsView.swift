import SwiftUI

/// Settings (REQUIREMENTS §3.8): my club, language, show onboarding again, about the data.
struct SettingsView: View {
    let appModel: AppModel
    let favorites: FavoriteClubStore
    let onReplayOnboarding: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pickingClub = false

    var body: some View {
        NavigationStack {
            List {
                Section("My club") {
                    Button { pickingClub = true } label: {
                        AdaptiveStack(verticalAlignment: .center, spacing: 8) {
                            HStack(spacing: 12) {
                                ClubLogo(club: favorites.resolve(in: appModel.clubs), size: 34)
                                Text(verbatim: favorites.resolve(in: appModel.clubs)?.displayName ?? String(localized: "None"))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            Spacer(minLength: 0)
                            Text("Change").foregroundStyle(Theme.violetHigh)
                        }
                    }
                    .accessibilityIdentifier("settings.changeClub")
                }
                Section("Language") {
                    LabeledContent("English") { Image(systemName: "checkmark").foregroundStyle(Theme.lime) }
                    LabeledContent("Nederlands") { Text("Coming later") }.foregroundStyle(Theme.textTertiary)
                    LabeledContent("Français") { Text("Coming later") }.foregroundStyle(Theme.textTertiary)
                }
                Section {
                    Button("Show onboarding again") {
                        dismiss()
                        onReplayOnboarding()
                    }
                    .accessibilityIdentifier("settings.replayOnboarding")
                    LabeledContent("Version") {
                        Text(verbatim: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Scores, stats, logos and photos: BNXT League, used with permission.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ink)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("settings.done")
                }
            }
            .navigationDestination(isPresented: $pickingClub) {
                ScrollView {
                    ClubPickerGrid(appModel: appModel, selection: favorites.resolve(in: appModel.clubs)) { club in
                        favorites.choose(club)
                        pickingClub = false
                    }
                }
                .background(Theme.ink)
                .navigationTitle("Choose your club")
            }
        }
        .accessibilityIdentifier("settings")
    }
}
