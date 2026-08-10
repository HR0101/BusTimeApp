import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var selectedMode: AppDesignMode

    init(defaults: UserDefaults = .standard) {
        let rawValue = defaults.string(forKey: "appDesignMode") ?? AppDesignMode.neumorphic.rawValue
        selectedMode = AppDesignMode(rawValue: rawValue) ?? .neumorphic
    }

    func select(_ mode: AppDesignMode) {
        selectedMode = mode
    }
}
