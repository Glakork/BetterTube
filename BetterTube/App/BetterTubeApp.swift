import SwiftUI

@main
struct BetterTubeApp: App {
    @StateObject private var preferences = Preferences()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferences)
                .tint(preferences.accent)
                .preferredColorScheme(preferences.colorScheme)
        }
    }
}

struct BrandMark: View {
    var size: CGFloat = 40
    @EnvironmentObject private var preferences: Preferences
    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: size * 0.42, weight: .black))
            .foregroundStyle(.white)
            .offset(x: size * 0.025)
            .frame(width: size, height: size)
            .background(preferences.accent.gradient, in: RoundedRectangle(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }
}
