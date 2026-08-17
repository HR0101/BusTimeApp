import Foundation

/// UIテストを毎回同じ保存状態から始めるためのDebug専用補助です。
enum AppTestSupport {
    static func resetPersistentStateIfNeeded(defaults: UserDefaults = .standard) {
#if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-UITestResetState") else { return }
        [
            "home.serviceDay",
            "home.searchType",
            "home.searchTime",
            "preferredPartnerStop",
            "scheduledBusNotifications",
            "weatherCache.v1",
            "appearancePreference",
            "skyCardOpacity",
            "prefersLiveActivity"
        ].forEach { defaults.removeObject(forKey: $0) }
#endif
    }
}
