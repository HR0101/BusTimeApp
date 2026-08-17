import Foundation
import Combine
import ActivityKit
import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable {
    case automatic
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: return L10n.Settings.appearanceAutomatic
        case .system: return L10n.Settings.appearanceSystem
        case .light: return L10n.Settings.appearanceLight
        case .dark: return L10n.Settings.appearanceDark
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var cardOpacity: Double
    @Published private(set) var prefersLiveActivity: Bool
    @Published private(set) var isLiveActivityAvailable: Bool
    @Published private(set) var appearancePreference: AppearancePreference

    var shouldUseLiveActivity: Bool {
        prefersLiveActivity && isLiveActivityAvailable
    }

    private static let liveActivityPreferenceKey = "prefersLiveActivity"
    private static let cardOpacityPreferenceKey = "skyCardOpacity"
    private static let appearancePreferenceKey = "appearancePreference"

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
        appearancePreference = defaults.string(forKey: Self.appearancePreferenceKey)
            .flatMap(AppearancePreference.init(rawValue:)) ?? .automatic

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

    func setAppearancePreference(_ preference: AppearancePreference) {
        appearancePreference = preference
        defaults.set(preference.rawValue, forKey: Self.appearancePreferenceKey)
    }

    func preferredColorScheme(for palette: SkyPalette) -> ColorScheme? {
        switch appearancePreference {
        case .automatic:
            return palette.isNight ? .dark : .light
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
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
