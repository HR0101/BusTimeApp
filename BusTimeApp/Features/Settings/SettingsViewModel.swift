import Foundation
import Combine
import ActivityKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var cardOpacity: Double
    @Published private(set) var prefersLiveActivity: Bool
    @Published private(set) var isLiveActivityAvailable: Bool

    var shouldUseLiveActivity: Bool {
        prefersLiveActivity && isLiveActivityAvailable
    }

    private static let liveActivityPreferenceKey = "prefersLiveActivity"
    private static let cardOpacityPreferenceKey = "skyCardOpacity"

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

        // 未設定なら標準の濃さから始めます。
        cardOpacity = defaults.object(forKey: Self.cardOpacityPreferenceKey) != nil
            ? defaults.double(forKey: Self.cardOpacityPreferenceKey)
            : SkyCardOpacity.standard

        let isAvailable = liveActivityAvailability()
        isLiveActivityAvailable = isAvailable
        hasExplicitLiveActivityPreference = defaults.object(
            forKey: Self.liveActivityPreferenceKey
        ) != nil
        prefersLiveActivity = hasExplicitLiveActivityPreference
            ? defaults.bool(forKey: Self.liveActivityPreferenceKey)
            : isAvailable
    }

    /// カードの地の濃さを決め、次回起動時にも引き継げるよう保存します。
    /// - Parameter opacity: 0が最も透け、1が最も濃い状態です。
    func setCardOpacity(_ opacity: Double) {
        let clamped = min(max(opacity, SkyCardOpacity.minimum), SkyCardOpacity.maximum)
        cardOpacity = clamped
        defaults.set(clamped, forKey: Self.cardOpacityPreferenceKey)
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
