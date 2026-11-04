import SwiftUI

@main
struct BNXTApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.lime)
        }
    }
}
