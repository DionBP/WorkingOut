import SwiftUI

@main
struct WorkingOutApp: App {
    @StateObject private var connectivity = PhoneConnectivityManager.shared
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system

    init() {
        UserProfile.autofillNameIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(connectivity)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
