import Foundation
import Combine

/// アプリ全体で発生するイベントです。
/// Viewは状態を直接変更せず、Coordinatorへイベントを送ります。
enum AppEvent {
    case launch
    case showTutorial
    case showSettings
    case selectBus(Bus)
    case notificationScheduled(String)
    case liveActivityFailed(String)
    case changeDesignMode(AppDesignMode)
    case dismiss
    case clearError
}

/// アプリの画面・モーダル状態を表す有限状態機械です。
enum AppState: Equatable {
    case dashboard
    case tutorial
    case settings
    case notificationOptions
    case notificationResult
    case liveActivityError
}

/// 画面遷移とアプリ横断状態を一元管理するCoordinatorです。
///
/// 画面側は `state` を描画し、ユーザー操作は `send(_:)` にイベントとして
/// 送ります。これにより、sheetやconfirmationDialogの表示状態がView内に
/// 分散しません。
@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var state: AppState = .dashboard
    @Published private(set) var selectedBus: Bus?
    @Published private(set) var notificationMessage: String?
    @Published private(set) var liveActivityErrorMessage: String?
    @Published private(set) var designMode: AppDesignMode

    private let defaults: UserDefaults
    private var hasStarted = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawValue = defaults.string(forKey: "appDesignMode") ?? AppDesignMode.neumorphic.rawValue
        self.designMode = AppDesignMode(rawValue: rawValue) ?? .neumorphic
    }

    func send(_ event: AppEvent) {
        switch event {
        case .launch:
            guard !hasStarted else { return }
            hasStarted = true

            if !defaults.bool(forKey: "hasSeenTutorial") {
                defaults.set(true, forKey: "hasSeenTutorial")
                state = .tutorial
            } else {
                state = .dashboard
            }

        case .showTutorial:
            guard state == .dashboard else { return }
            state = .tutorial

        case .showSettings:
            guard state == .dashboard else { return }
            state = .settings

        case let .selectBus(bus):
            guard state == .dashboard else { return }
            selectedBus = bus
            state = .notificationOptions

        case let .notificationScheduled(message):
            notificationMessage = message
            state = .notificationResult

        case let .liveActivityFailed(message):
            liveActivityErrorMessage = message
            state = .liveActivityError

        case let .changeDesignMode(mode):
            designMode = mode
            defaults.set(mode.rawValue, forKey: "appDesignMode")

        case .dismiss:
            selectedBus = nil
            state = .dashboard

        case .clearError:
            notificationMessage = nil
            liveActivityErrorMessage = nil
            selectedBus = nil
            state = .dashboard
        }
    }

    var isTutorialPresented: Bool { state == .tutorial }
    var isSettingsPresented: Bool { state == .settings }
    var isNotificationOptionsPresented: Bool { state == .notificationOptions }
    var isNotificationResultPresented: Bool { state == .notificationResult }
    var isLiveActivityErrorPresented: Bool { state == .liveActivityError }
}
