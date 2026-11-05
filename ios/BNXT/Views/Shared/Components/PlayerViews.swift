import SwiftUI

/// A player's photo in a circle, or their initials.
struct PlayerAvatar: View {
    let player: Player
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            Circle().fill(Theme.surface3)
            if let url = player.photo?.small ?? player.photo?.url {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Text(verbatim: "\(player.firstName.prefix(1))\(player.lastName.prefix(1))")
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(Theme.textSecondary)
    }
}
