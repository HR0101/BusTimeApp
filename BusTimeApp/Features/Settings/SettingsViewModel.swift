import Foundation
import Combine
import ActivityKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var prefersLiveActivity: Bool
    @Published private(set) var isLiveActivityAvailable: Bool

    var shouldUseLiveActivity: Bool {
        prefersLiveActivity && isLiveActivityAvailable
    }

    private static let liveActivityPreferenceKey = "prefersLiveActivity"

    private let defaults: UserDefaults
    private let liveActivityAvailability: () -> Bool
    private var hasExplicitLiveActivityPreference: Bool

    init(
        defaults: UserDefaults = .standard,
        liveActivityAvailability: @escaping () -> Bool = {
            ActivityAuthorizationInfo().areActivitiesEnabled
        }
    ) {
        self.defaults = defaults
        self.liveActivityAvailability = liveActivityAvailability

        let isAvailable = liveActivityAvailability()
        isLiveActivityAvailable = isAvailable
        hasExplicitLiveActivityPreference = defaults.object(
            forKey: Self.liveActivityPreferenceKey
        ) != nil
        prefersLiveActivity = hasExplicitLiveActivityPreference
            ? defaults.bool(forKey: Self.liveActivityPreferenceKey)
            : isAvailable
    }

    func setLiveActivityEnabled(_ isEnabled: Bool) {
        guard isLiveActivityAvailable else { return }
        hasExplicitLiveActivityPreference = true
        prefersLiveActivity = isEnabled
        defaults.set(isEnabled, forKey: Self.liveActivityPreferenceKey)
    }

    func refreshLiveActivityAvailability() {
        isLiveActivityAvailable = liveActivityAvailability()

        if !hasExplicitLiveActivityPreference {
            prefersLiveActivity = isLiveActivityAvailable
        }
    }
}
