import SwiftUI
import UIKit

// MARK: - Neumorphic design system

enum AppDesignMode: String, CaseIterable, Identifiable {
    case neumorphic
    case claymorphic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neumorphic: return "Neumorphism"
        case .claymorphic: return "Claymorphism"
        }
    }

    var shortTitle: String {
        switch self {
        case .neumorphic: return "ネオ"
        case .claymorphic: return "クレイ"
        }
    }
}

private struct AppDesignModeKey: EnvironmentKey {
    static let defaultValue: AppDesignMode = .neumorphic
}

extension EnvironmentValues {
    var appDesignMode: AppDesignMode {
        get { self[AppDesignModeKey.self] }
        set { self[AppDesignModeKey.self] = newValue }
    }
}

extension Color {
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    // Light: #E0E5EC / Dark: a neutral blue-gray equivalent.
    static let neumoBackground = adaptive(
        light: UIColor(red: 224 / 255, green: 229 / 255, blue: 236 / 255, alpha: 1),
        dark: UIColor(red: 36 / 255, green: 41 / 255, blue: 50 / 255, alpha: 1)
    )
    static let neumoSurfaceTop = adaptive(
        light: UIColor(red: 232 / 255, green: 237 / 255, blue: 243 / 255, alpha: 1),
        dark: UIColor(red: 45 / 255, green: 51 / 255, blue: 62 / 255, alpha: 1)
    )
    static let neumoSurface = neumoBackground
    static let neumoSurfaceBottom = adaptive(
        light: UIColor(red: 216 / 255, green: 222 / 255, blue: 231 / 255, alpha: 1),
        dark: UIColor(red: 31 / 255, green: 36 / 255, blue: 44 / 255, alpha: 1)
    )
    static let neumoHighlight = adaptive(
        light: .white,
        dark: UIColor(red: 62 / 255, green: 70 / 255, blue: 84 / 255, alpha: 1)
    )
    static let neumoText = adaptive(
        light: UIColor(red: 33 / 255, green: 45 / 255, blue: 66 / 255, alpha: 1),
        dark: UIColor(red: 232 / 255, green: 236 / 255, blue: 243 / 255, alpha: 1)
    )
    static let neumoMuted = adaptive(
        light: UIColor(red: 101 / 255, green: 113 / 255, blue: 132 / 255, alpha: 1),
        dark: UIColor(red: 164 / 255, green: 175 / 255, blue: 194 / 255, alpha: 1)
    )
    static let neumoAccent = Color(red: 0.24, green: 0.57, blue: 0.83)
    static let neumoAccentDeep = Color(red: 0.18, green: 0.44, blue: 0.69)
    static let neumoAccentSoft = Color(red: 0.76, green: 0.89, blue: 0.97)
    static let neumoGreen = Color(red: 0.24, green: 0.61, blue: 0.48)
    static let neumoWarning = Color(red: 0.84, green: 0.47, blue: 0.29)
    static let neumoShadow = adaptive(
        light: UIColor(red: 163 / 255, green: 177 / 255, blue: 198 / 255, alpha: 1),
        dark: UIColor(red: 16 / 255, green: 20 / 255, blue: 27 / 255, alpha: 1)
    )
    static let claySky = Color(red: 0.35, green: 0.74, blue: 0.96)
    static let claySkyDeep = Color(red: 0.20, green: 0.55, blue: 0.88)
    static let clayShadow = Color(red: 0.10, green: 0.42, blue: 0.76)
    static let clayYellow = Color(red: 1.0, green: 0.77, blue: 0.18)
    static let clayWarningText = Color(red: 0.76, green: 0.49, blue: 0.05)
    static let clayPurple = Color(red: 0.55, green: 0.38, blue: 0.91)
    static let clayMint = Color(red: 0.16, green: 0.78, blue: 0.72)
}

struct SoftWave: Shape {
    let verticalPosition: CGFloat
    let amplitude: CGFloat
    let frequency: Double
    let phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startX = rect.minX - rect.width * 0.08
        let width = rect.width * 1.16
        let baseY = rect.height * verticalPosition
        path.move(to: CGPoint(x: startX, y: baseY))

        for step in 0...120 {
            let progress = Double(step) / 120
            let x = startX + CGFloat(progress) * width
            let y = baseY + CGFloat(sin((progress * frequency + phase) * Double.pi * 2)) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

struct NeumorphicBackground: View {
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        Group {
            if designMode == .claymorphic {
                ClaymorphicBackground()
            } else {
                NeumorphicBackdrop()
            }
        }
    }
}

struct NeumorphicBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.neumoBackground

                Circle()
                    .fill(Color.neumoHighlight.opacity(0.16))
                    .frame(width: proxy.size.width * 0.95)
                    .blur(radius: 28)
                    .offset(x: -proxy.size.width * 0.42, y: -proxy.size.height * 0.43)

                Circle()
                    .fill(Color.neumoAccent.opacity(0.025))
                    .frame(width: proxy.size.width * 0.9)
                    .blur(radius: 36)
                    .offset(x: proxy.size.width * 0.43, y: proxy.size.height * 0.36)

                SoftWave(verticalPosition: 0.12, amplitude: 26, frequency: 1.05, phase: 0.12)
                    .stroke(Color.neumoHighlight.opacity(0.18), lineWidth: 2)
                    .blur(radius: 0.4)
                SoftWave(verticalPosition: 0.83, amplitude: 36, frequency: 1.28, phase: 0.56)
                    .stroke(Color.neumoAccent.opacity(0.025), lineWidth: 2)
                    .blur(radius: 0.6)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

struct ClaymorphicBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.62, green: 0.87, blue: 0.99), Color(red: 0.83, green: 0.96, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: proxy.size.width * 0.56)
                    .blur(radius: 18)
                    .offset(x: proxy.size.width * 0.40, y: -proxy.size.height * 0.35)

                Circle()
                    .fill(Color.claySkyDeep.opacity(0.24))
                    .frame(width: proxy.size.width * 0.52)
                    .blur(radius: 18)
                    .offset(x: -proxy.size.width * 0.44, y: proxy.size.height * 0.30)

                Circle()
                    .fill(Color.white.opacity(0.26))
                    .frame(width: 120, height: 120)
                    .blur(radius: 12)
                    .offset(x: proxy.size.width * 0.39, y: proxy.size.height * 0.24)

                SoftWave(verticalPosition: 0.10, amplitude: 38, frequency: 1.08, phase: 0.10)
                    .stroke(Color.white.opacity(0.34), lineWidth: 2)
                    .blur(radius: 0.6)
                SoftWave(verticalPosition: 0.88, amplitude: 48, frequency: 1.16, phase: 0.48)
                    .stroke(Color.white.opacity(0.24), lineWidth: 2)
                    .blur(radius: 0.8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
    }
}

enum NeumorphicMode: Equatable {
    /// 背景から押し出された凸面。
    case convex
    /// 背景へ彫り込まれた凹面。
    case concave
}

private struct NeumorphicInsetOverlay<S: Shape>: View {
    let shape: S
    let shadowRadius: CGFloat
    let offset: CGFloat

    var body: some View {
        ZStack {
            // 凹面では左上の内壁が暗く、右下の内壁が光を受ける。
            shape
                .stroke(Color.neumoShadow.opacity(0.72), lineWidth: max(4, offset * 2.4))
                .blur(radius: shadowRadius * 0.48)
                .offset(x: -offset * 0.58, y: -offset * 0.58)

            shape
                .stroke(Color.neumoHighlight.opacity(0.86), lineWidth: max(4, offset * 2.2))
                .blur(radius: shadowRadius * 0.42)
                .offset(x: offset * 0.58, y: offset * 0.58)
        }
        .mask(shape)
        .allowsHitTesting(false)
    }
}

struct NeumorphicSurface<S: Shape>: ViewModifier {
    let shape: S
    /// convexは凸、concaveは凹。
    var mode: NeumorphicMode = .convex
    /// 影のぼかし半径。
    var shadowRadius: CGFloat = 12
    /// 左上／右下へ移動する影の距離。
    var offset: CGFloat = 7
    /// ボタン押下時は一時的に凹面へ切り替える。
    var pressed: Bool = false
    @Environment(\.appDesignMode) private var designMode

    private var effectiveMode: NeumorphicMode {
        pressed ? .concave : mode
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if designMode == .claymorphic {
            content
                .background(
                    shape
                        .fill(Color.white.opacity(0.97))
                        .shadow(color: Color.white.opacity(0.8), radius: shadowRadius * 0.62, x: -offset, y: -offset)
                        .shadow(color: Color.clayShadow.opacity(pressed ? 0.14 : 0.28), radius: shadowRadius * 1.25, x: offset, y: offset * 1.25)
                )
                .overlay(shape.stroke(Color.white.opacity(0.72), lineWidth: 1))
        } else if effectiveMode == .concave {
            content
                .background(shape.fill(Color.neumoBackground))
                .overlay(
                    NeumorphicInsetOverlay(
                        shape: shape,
                        shadowRadius: shadowRadius,
                        offset: offset
                    )
                )
        } else {
            content
                .background(
                    shape
                        .fill(
                            LinearGradient(
                                colors: [.neumoSurfaceTop, .neumoSurface, .neumoSurfaceBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(
                            color: Color.neumoHighlight.opacity(0.94),
                            radius: shadowRadius,
                            x: -offset,
                            y: -offset
                        )
                        .shadow(
                            color: Color.neumoShadow.opacity(0.64),
                            radius: shadowRadius,
                            x: offset,
                            y: offset
                        )
                )
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                Color.neumoHighlight.opacity(0.74),
                                Color.clear,
                                Color.neumoShadow.opacity(0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                )
        }
    }
}

extension View {
    /// 既存画面向けの簡易指定。depthから影半径とオフセットを算出する。
    func neumorphicSurface<S: Shape>(in shape: S, depth: CGFloat = 12, pressed: Bool = false) -> some View {
        modifier(
            NeumorphicSurface(
                shape: shape,
                mode: .convex,
                shadowRadius: depth,
                offset: depth * 0.58,
                pressed: pressed
            )
        )
    }

    /// 凸凹、影半径、オフセットを個別に指定する再利用可能API。
    func neumorphicSurface<S: Shape>(
        in shape: S,
        mode: NeumorphicMode,
        shadowRadius: CGFloat = 12,
        offset: CGFloat = 7,
        pressed: Bool = false
    ) -> some View {
        modifier(
            NeumorphicSurface(
                shape: shape,
                mode: mode,
                shadowRadius: shadowRadius,
                offset: offset,
                pressed: pressed
            )
        )
    }

    func clayCard<S: Shape>(in shape: S, elevation: CGFloat = 18) -> some View {
        background(
            shape
                .fill(Color.white.opacity(0.97))
                .shadow(color: Color.white.opacity(0.75), radius: elevation * 0.45, x: -5, y: -5)
                .shadow(color: Color.clayShadow.opacity(0.27), radius: elevation, x: 8, y: 12)
        )
        .overlay(shape.stroke(Color.white.opacity(0.72), lineWidth: 1))
    }
}

/// 通常時は凸、押下時は凹へ切り替わるNeumorphismボタン。
struct NeumorphicButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 18
    var shadowRadius: CGFloat = 10
    var offset: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .neumorphicSurface(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                mode: configuration.isPressed ? .concave : .convex,
                shadowRadius: shadowRadius,
                offset: offset,
                pressed: configuration.isPressed
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

/// 凹んだトラックと凸のノブを組み合わせたToggleStyle。
struct NeumorphicToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(Color.neumoBackground)
                        .frame(width: 54, height: 30)
                        .neumorphicSurface(
                            in: Capsule(),
                            mode: .concave,
                            shadowRadius: 6,
                            offset: 3
                        )
                    Circle()
                        .fill(configuration.isOn ? Color.neumoAccent : Color.neumoSurface)
                        .frame(width: 24, height: 24)
                        .shadow(color: Color.neumoHighlight.opacity(0.8), radius: 3, x: -2, y: -2)
                        .shadow(color: Color.neumoShadow.opacity(0.55), radius: 4, x: 2, y: 2)
                        .padding(3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// 凹んだトラックと凸ノブを持つ、0...1以外の範囲にも対応したSlider。
struct NeumorphicSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var tint: Color = .neumoAccent

    private var progress: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let knobSize: CGFloat = 26
            let travel = max(0, proxy.size.width - knobSize)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.neumoBackground)
                    .frame(height: 10)
                    .neumorphicSurface(
                        in: Capsule(),
                        mode: .concave,
                        shadowRadius: 5,
                        offset: 3
                    )

                Capsule()
                    .fill(tint.opacity(0.7))
                    .frame(width: knobSize / 2 + travel * progress, height: 6)

                Circle()
                    .fill(Color.neumoSurface)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: Color.neumoHighlight.opacity(0.85), radius: 4, x: -3, y: -3)
                    .shadow(color: Color.neumoShadow.opacity(0.6), radius: 5, x: 3, y: 3)
                    .offset(x: travel * progress)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newProgress = min(max(gesture.location.x / max(proxy.size.width, 1), 0), 1)
                        value = range.lowerBound + (range.upperBound - range.lowerBound) * newProgress
                    }
            )
        }
        .frame(height: 34)
        .accessibilityValue(Text("\(Int(progress * 100))%"))
    }
}

struct SoftPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct IconBubble: View {
    let systemName: String
    var tint: Color = .neumoAccent
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .neumorphicSurface(
                in: Circle(),
                mode: .convex,
                shadowRadius: 8,
                offset: 5
            )
    }
}

struct SectionHeading: View {
    let eyebrow: String
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Color.neumoAccent)
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.neumoText)
            }
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.neumoMuted)
                }
                .buttonStyle(SoftPressButtonStyle())
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var notificationViewModel = NotificationViewModel()
    @Environment(\.scenePhase) private var scenePhase

    private var currentDesignMode: AppDesignMode {
        coordinator.designMode
    }

    private var scheduledBusIDs: Set<String> {
        Set(notificationViewModel.scheduledNotifications.map(\.busID))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                Group {
                    if currentDesignMode == .claymorphic {
                        claymorphicDashboard
                    } else {
                        neumorphicDashboard
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
            .background(NeumorphicBackground())
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(currentDesignMode == .claymorphic ? .light : nil)
            .onAppear {
                coordinator.send(.launch)
                viewModel.performSearch()
                viewModel.checkLocationAndSetRoute()
                notificationViewModel.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.checkLocationAndSetRoute()
                }
            }
            .onChange(of: viewModel.selectedRoute) { _, _ in
                viewModel.performSearch()
            }
            .sheet(isPresented: Binding(
                get: { coordinator.isTutorialPresented },
                set: { if !$0 { coordinator.send(.dismiss) } }
            )) {
                TutorialView()
                    .environment(\.appDesignMode, currentDesignMode)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: Binding(
                get: { coordinator.isSettingsPresented },
                set: { if !$0 { coordinator.send(.dismiss) } }
            )) {
                SettingsView(viewModel: settingsViewModel) { mode in
                    coordinator.send(.changeDesignMode(mode))
                }
                    .environment(\.appDesignMode, currentDesignMode)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: Binding(
                get: { coordinator.isNotificationsPresented },
                set: { if !$0 { coordinator.send(.dismiss) } }
            )) {
                NotificationManagementView(
                    viewModel: notificationViewModel,
                    liveActivityBusID: viewModel.trackedBusId,
                    onEndLiveActivity: viewModel.endLiveActivity
                )
                .environment(\.appDesignMode, currentDesignMode)
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: Binding(
                get: { coordinator.isNotificationOptionsPresented },
                set: { if !$0 { coordinator.send(.dismiss) } }
            )) {
                if let bus = coordinator.selectedBus {
                    NotificationOptionsView(
                        bus: bus,
                        routeName: viewModel.selectedRoute.rawValue,
                        scheduledNotification: notificationViewModel.notification(for: bus.id),
                        permissionStatus: notificationViewModel.permissionStatus,
                        liveActivityBusID: viewModel.trackedBusId,
                        onOpenNotificationSettings: notificationViewModel.openNotificationSettings,
                        onSchedule: { minutes in scheduleNotification(minutes: minutes) },
                        onStartLiveActivity: {
                            viewModel.startLiveActivity(for: bus)
                            coordinator.send(.dismiss)
                        },
                        onEndLiveActivity: {
                            viewModel.endLiveActivity()
                        }
                    )
                    .environment(\.appDesignMode, currentDesignMode)
                    .presentationDragIndicator(.visible)
                }
            }
            .alert("通知設定", isPresented: Binding(
                get: { coordinator.isNotificationResultPresented },
                set: { if !$0 { coordinator.send(.dismiss) } }
            )) {
                Button("OK") { coordinator.send(.dismiss) }
            } message: {
                Text(coordinator.notificationMessage ?? "")
            }
            .alert(
                "Live Activityエラー",
                isPresented: Binding(
                    get: { coordinator.isLiveActivityErrorPresented },
                    set: { if !$0 {
                        viewModel.liveActivityError = nil
                        coordinator.send(.clearError)
                    } }
                )
            ) {
                Button("設定を確認") {
                    viewModel.openAppSettings()
                    viewModel.liveActivityError = nil
                    coordinator.send(.clearError)
                }
                Button("OK") {
                    viewModel.liveActivityError = nil
                    coordinator.send(.clearError)
                }
            } message: {
                Text(coordinator.liveActivityErrorMessage ?? "Live Activityでエラーが発生しました。")
            }
            .onChange(of: viewModel.liveActivityError) { _, errorMessage in
                if let errorMessage {
                    coordinator.send(.liveActivityFailed(errorMessage))
                    viewModel.liveActivityError = nil
                }
            }
        }
        .environment(\.appDesignMode, currentDesignMode)
    }

    private var neumorphicDashboard: some View {
        VStack(spacing: 24) {
            appHeader

            if case let .serviceUnavailable(message) = viewModel.state {
                ServiceMessageCard(message: message)
            } else if case let .failed(message) = viewModel.state {
                ServiceMessageCard(message: message)
            } else if let nextBus = viewModel.searchResults.first {
                NextBusCard(
                    bus: nextBus,
                    routeName: viewModel.selectedRoute.rawValue,
                    countdown: viewModel.countdownMessages[nextBus.id],
                    isNotificationScheduled: scheduledBusIDs.contains(nextBus.id)
                ) {
                    selectBus(nextBus)
                }
            } else {
                EmptyBusCard()
            }

            RouteSelectorCard(
                selectedRoute: $viewModel.selectedRoute,
                locationAction: viewModel.checkLocationAndSetRoute
            )
            SearchPanel(viewModel: viewModel)

            if viewModel.holidayMessage == nil {
                upcomingSection
                timetableSection
            }

            serviceFooter
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 32)
    }

    private var claymorphicDashboard: some View {
        VStack(spacing: 20) {
            ClayHeaderBar(
                helpAction: { coordinator.send(.showTutorial) },
                settingsAction: { coordinator.send(.showSettings) },
                notificationAction: { coordinator.send(.showNotifications) },
                notificationCount: notificationViewModel.scheduledNotifications.count
            )

            if case let .serviceUnavailable(message) = viewModel.state {
                ClayMessageCard(message: message)
            } else if case let .failed(message) = viewModel.state {
                ClayMessageCard(message: message)
            } else if let nextBus = viewModel.searchResults.first {
                ClayNextBusHero(
                    bus: nextBus,
                    countdown: viewModel.countdownMessages[nextBus.id],
                    isNotificationScheduled: scheduledBusIDs.contains(nextBus.id)
                ) {
                    selectBus(nextBus)
                }
            } else {
                ClayMessageCard(message: "条件に合うバスがありません。時刻を変更して再検索してください。")
            }

            ClayRouteSearchCard(
                viewModel: viewModel,
                locationAction: viewModel.checkLocationAndSetRoute
            )

            if viewModel.holidayMessage == nil {
                ClayUpcomingCard(
                    buses: viewModel.searchResults,
                    countdowns: viewModel.countdownMessages,
                    scheduledBusIDs: scheduledBusIDs
                ) { bus in
                    selectBus(bus)
                }
                ClayTimetableCard(
                    buses: viewModel.currentFullTimetable,
                    recommendedIds: Set(viewModel.searchResults.map(\.id)),
                    scheduledBusIDs: scheduledBusIDs
                ) { bus in
                    selectBus(bus)
                }
            }

            serviceFooter
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 34)
    }

    private var serviceFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.neumoGreen)
                .frame(width: 7, height: 7)
            Text("平日のみ運行  •  時刻表は現地案内を優先します")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.neumoMuted)
        }
        .padding(.top, 2)
    }

    private func selectBus(_ bus: Bus) {
        coordinator.send(.selectBus(bus))
    }

    private var appHeader: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.neumoAccent.opacity(0.11))
                    .frame(width: 52, height: 52)
                Image(systemName: "bus.fill")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(Color.neumoAccent)
            }
            .shadow(color: Color.white.opacity(0.9), radius: 7, x: -4, y: -4)
            .shadow(color: Color.neumoShadow.opacity(0.08), radius: 7, x: 4, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text("コロンブスシティ")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.neumoText)
                Text("SHUTTLE SERVICE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(Color.neumoMuted)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    coordinator.send(.showNotifications)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: scheduledBusIDs.isEmpty ? "bell" : "bell.badge.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("通知")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Color.neumoAccent)
                    .frame(width: 44, height: 40)
                }
                .buttonStyle(SoftPressButtonStyle())
                .accessibilityLabel("設定した通知を確認")

                Button {
                    coordinator.send(.showSettings)
                } label: {
                    IconBubble(systemName: "gearshape.fill", tint: .neumoAccent, size: 40)
                }
                .buttonStyle(SoftPressButtonStyle())

                Button {
                    coordinator.send(.showTutorial)
                } label: {
                    IconBubble(systemName: "questionmark", tint: .neumoMuted, size: 40)
                }
                .buttonStyle(SoftPressButtonStyle())
            }
        }
    }

    private var upcomingSection: some View {
        VStack(spacing: 12) {
            SectionHeading(
                eyebrow: "UP NEXT",
                title: "候補のバス",
                actionTitle: "\(viewModel.searchResults.count)便表示",
                action: nil
            )

            ForEach(viewModel.searchResults) { bus in
                BusResultRow(
                    bus: bus,
                    viewModel: viewModel,
                    isNotificationScheduled: scheduledBusIDs.contains(bus.id)
                ) {
                    selectBus(bus)
                }
            }
        }
    }

    private var timetableSection: some View {
        VStack(spacing: 12) {
            SectionHeading(eyebrow: "TODAY", title: "本日の時刻表")

            VStack(spacing: 0) {
                HStack {
                    Text("出発")
                    Spacer()
                    Text("到着")
                    Text("")
                        .frame(width: 42)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.neumoMuted)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)

                ForEach(viewModel.currentFullTimetable) { bus in
                    BusTimetableRow(
                        bus: bus,
                        isRecommended: viewModel.searchResults.contains(where: { $0.id == bus.id }),
                        isNotificationScheduled: scheduledBusIDs.contains(bus.id)
                    ) {
                        selectBus(bus)
                    }
                }
            }
            .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 14)
        }
    }

    private func scheduleNotification(minutes: Int) {
        guard let bus = coordinator.selectedBus else { return }
        notificationViewModel.scheduleNotification(
            for: bus,
            routeName: viewModel.selectedRoute.rawValue,
            minutesBefore: minutes
        ) { result in
            switch result {
            case let .success(item):
                coordinator.send(.notificationScheduled(
                    "通知を設定しました。\n\n\(item.busDescription)\n\(item.notificationDescription)にお知らせします。\n\n※時刻表の予定です。遅延・運休は反映されません。"
                ))
            case let .failure(error):
                coordinator.send(.notificationScheduled(error.localizedDescription))
            }
        }
    }
}

struct BusNotificationActionButton: View {
    let isScheduled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                isScheduled ? "設定済み" : "通知",
                systemImage: isScheduled ? "bell.fill" : "bell"
            )
            .font(.caption2.weight(.bold))
            .foregroundStyle(isScheduled ? Color.neumoAccentDeep : Color.neumoAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isScheduled ? Color.neumoAccentSoft.opacity(0.8) : Color.neumoAccent.opacity(0.08))
            )
        }
        .buttonStyle(SoftPressButtonStyle())
        .accessibilityLabel(isScheduled ? "この便は通知設定済み" : "この便の通知を設定")
        .accessibilityHint("出発前に通知する方法を選びます")
    }
}

// MARK: - Claymorphism dashboard

struct ClayHeaderBar: View {
    let helpAction: () -> Void
    let settingsAction: () -> Void
    let notificationAction: () -> Void
    let notificationCount: Int

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.claySky, .claySkyDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                Image(systemName: "bus.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.clayShadow.opacity(0.32), radius: 10, x: 5, y: 7)

            VStack(alignment: .leading, spacing: 3) {
                Text("コロンブスシティ")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.neumoText)
                HStack(spacing: 5) {
                    Circle().fill(Color.clayMint).frame(width: 6, height: 6)
                    Text("SHUTTLE IS ACTIVE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color.neumoMuted)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: notificationAction) {
                    VStack(spacing: 2) {
                        Image(systemName: notificationCount == 0 ? "bell" : "bell.badge.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("通知")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Color.claySkyDeep)
                    .frame(width: 42, height: 38)
                    .background(Circle().fill(Color(red: 0.91, green: 0.96, blue: 0.99)))
                }
                .buttonStyle(SoftPressButtonStyle())
                .accessibilityLabel("設定した通知を確認（\(notificationCount)件）")

                Button(action: settingsAction) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.claySkyDeep)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color(red: 0.91, green: 0.96, blue: 0.99)))
                }
                .buttonStyle(SoftPressButtonStyle())

                Button(action: helpAction) {
                    Image(systemName: "questionmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.claySkyDeep)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color(red: 0.91, green: 0.96, blue: 0.99)))
                }
                .buttonStyle(SoftPressButtonStyle())
            }
        }
        .padding(15)
        .clayCard(in: RoundedRectangle(cornerRadius: 25, style: .continuous), elevation: 18)
    }
}

struct ClayNextBusHero: View {
    let bus: Bus
    let countdown: String?
    let isNotificationScheduled: Bool
    let notifyAction: () -> Void

    var body: some View {
        VStack(spacing: -28) {
            ZStack {
                RoundedRectangle(cornerRadius: 31, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.24, green: 0.67, blue: 0.96), Color(red: 0.16, green: 0.52, blue: 0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 118, height: 118)
                    .offset(x: 128, y: -67)
                Circle()
                    .fill(Color.claySky.opacity(0.5))
                    .frame(width: 78, height: 78)
                    .offset(x: -145, y: 72)
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 38, height: 38)
                    .offset(x: 116, y: 61)

                VStack(spacing: 13) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("NEXT SHUTTLE")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.6)
                                .foregroundStyle(.white.opacity(0.78))
                            Text("次のバス")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Text(countdown ?? "まもなく")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.claySkyDeep)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.92)))
                    }

                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 84, height: 84)
                                .shadow(color: Color.clayShadow.opacity(0.36), radius: 13, x: 7, y: 10)
                            Circle()
                                .fill(Color.clayYellow)
                                .frame(width: 22, height: 22)
                                .offset(x: 31, y: -30)
                            Image(systemName: "bus.fill")
                                .font(.system(size: 39, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.claySky, .claySkyDeep],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            Text(bus.originName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            HStack(spacing: 5) {
                                Circle().fill(.white).frame(width: 7, height: 7)
                                Capsule().fill(.white.opacity(0.5)).frame(width: 46, height: 3)
                                Image(systemName: "arrow.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                            Text(bus.destinationName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(21)
            }
            .frame(height: 228)
            .shadow(color: Color.clayShadow.opacity(0.34), radius: 22, x: 9, y: 14)

            VStack(spacing: 14) {
                HStack(alignment: .lastTextBaseline, spacing: 11) {
                    Text(bus.departure)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.neumoText)
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.claySkyDeep)
                    Text(bus.arrival)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.neumoMuted)
                    Spacer()
                    BusNotificationActionButton(
                        isScheduled: isNotificationScheduled,
                        action: notifyAction
                    )
                }

                Text(bus.stopSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.neumoMuted)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 43)
            .padding(.bottom, 18)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.white))
            .shadow(color: Color.clayShadow.opacity(0.25), radius: 20, x: 8, y: 13)
        }
    }
}

struct ClayMessageCard: View {
    let message: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.clayYellow.opacity(0.92))
                    .frame(width: 52, height: 52)
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("SERVICE INFORMATION")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Color.claySkyDeep)
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.neumoText)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .clayCard(in: RoundedRectangle(cornerRadius: 25, style: .continuous), elevation: 18)
    }
}

struct ClayRouteSearchCard: View {
    @ObservedObject var viewModel: BusTimetableViewModel
    let locationAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PLAN YOUR RIDE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Color.claySkyDeep)
                    Text("乗車プラン")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.neumoText)
                }
                Spacer()
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title3)
                    .foregroundStyle(Color.claySkyDeep)
            }

            Menu {
                ForEach(BusTimetableViewModel.Route.allCases, id: \.self) { route in
                    Button {
                        viewModel.selectedRoute = route
                    } label: {
                        Label(route.rawValue, systemImage: route == viewModel.selectedRoute ? "checkmark" : "arrow.right")
                    }
                }
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .foregroundStyle(Color.claySkyDeep)
                    Text(viewModel.selectedRoute.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.neumoText)
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.neumoMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.94, green: 0.97, blue: 0.99))
                )
            }
            .buttonStyle(SoftPressButtonStyle())

            HStack(spacing: 9) {
                ClaySearchTypeChip(
                    title: "出発時刻",
                    systemName: "arrow.up.right",
                    isSelected: viewModel.searchType == .departure
                ) {
                    viewModel.searchType = .departure
                }
                ClaySearchTypeChip(
                    title: "到着希望",
                    systemName: "flag.checkered",
                    isSelected: viewModel.searchType == .arrival
                ) {
                    viewModel.searchType = .arrival
                }
            }

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.clayPurple.opacity(0.13))
                        .frame(width: 48, height: 48)
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Color.clayPurple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.searchType == .departure ? "出発時刻" : "到着希望時刻")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.neumoMuted)
                    if viewModel.searchType == .departure {
                        DatePicker("", selection: $viewModel.departureTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    } else {
                        DatePicker("", selection: $viewModel.arrivalTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
                Spacer()
                Button {
                    viewModel.setSearchToCurrentTime()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.claySkyDeep)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.neumoAccentSoft.opacity(0.58)))
                }
                .buttonStyle(SoftPressButtonStyle())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.96, green: 0.98, blue: 0.995))
            )

            Button(action: locationAction) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("現在地から路線を選ぶ")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.claySkyDeep)
            }
            .buttonStyle(SoftPressButtonStyle())
            .padding(.horizontal, 2)

            Button {
                viewModel.performSearch()
            } label: {
                HStack(spacing: 0) {
                    Text("この条件で検索")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 18)
                    ZStack {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Color.clayYellow)
                            .frame(width: 58, height: 54)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.claySky, .claySkyDeep],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.clayShadow.opacity(0.32), radius: 13, x: 6, y: 9)
            }
            .buttonStyle(SoftPressButtonStyle())
        }
        .padding(19)
        .clayCard(in: RoundedRectangle(cornerRadius: 27, style: .continuous), elevation: 20)
    }
}

struct ClaySearchTypeChip: View {
    let title: String
    let systemName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                Text(title)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(isSelected ? Color.claySkyDeep : Color.neumoMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.neumoAccentSoft.opacity(0.75) : Color(red: 0.95, green: 0.97, blue: 0.99))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.claySky.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(SoftPressButtonStyle())
    }
}

struct ClayUpcomingCard: View {
    let buses: [Bus]
    let countdowns: [String: String]
    let scheduledBusIDs: Set<String>
    let action: (Bus) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("UPCOMING")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(Color.claySkyDeep)
                    Text("候補のバス")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.neumoText)
                }
                Spacer()
                Text("\(buses.count) RIDES")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.claySkyDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.neumoAccentSoft.opacity(0.65)))
            }
            .padding(18)

            if buses.isEmpty {
                Text("候補のバスがありません")
                    .font(.subheadline)
                    .foregroundStyle(Color.neumoMuted)
                    .padding(.bottom, 20)
            } else {
                ForEach(Array(buses.enumerated()), id: \.element.id) { index, bus in
                    ClayUpcomingRow(
                        bus: bus,
                        countdown: countdowns[bus.id],
                        tint: index.isMultiple(of: 2) ? .clayPurple : .clayMint,
                        isNotificationScheduled: scheduledBusIDs.contains(bus.id)
                    ) {
                        action(bus)
                    }
                    if bus.id != buses.last?.id {
                        Divider().padding(.leading, 74)
                    }
                }
            }
        }
        .clayCard(in: RoundedRectangle(cornerRadius: 27, style: .continuous), elevation: 20)
    }
}

struct ClayUpcomingRow: View {
    let bus: Bus
    let countdown: String?
    let tint: Color
    let isNotificationScheduled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 46, height: 46)
                Image(systemName: "bus.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(bus.departure)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.neumoText)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.claySkyDeep)
                    Text(bus.arrival)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.neumoMuted)
                }
                Text(bus.stopSummary)
                    .font(.caption2)
                    .foregroundStyle(Color.neumoMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 5) {
                if let countdown {
                    Text(countdown)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.claySkyDeep)
                }
                BusNotificationActionButton(
                    isScheduled: isNotificationScheduled,
                    action: action
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }
}

struct ClayTimetableCard: View {
    let buses: [Bus]
    let recommendedIds: Set<String>
    let scheduledBusIDs: Set<String>
    let action: (Bus) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TODAY'S SCHEDULE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.78))
                    Text("本日の時刻表")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                ZStack {
                    Circle().fill(Color.clayYellow).frame(width: 42, height: 42)
                    Text("\(buses.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(19)
            .background(
                LinearGradient(
                    colors: [.claySky, .claySkyDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            ForEach(buses) { bus in
                ClayTimetableRow(
                    bus: bus,
                    isRecommended: recommendedIds.contains(bus.id),
                    isNotificationScheduled: scheduledBusIDs.contains(bus.id)
                ) {
                    action(bus)
                }
                if bus.id != buses.last?.id {
                    Divider().padding(.leading, 18)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        .shadow(color: Color.clayShadow.opacity(0.28), radius: 22, x: 8, y: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
    }
}

struct ClayTimetableRow: View {
    let bus: Bus
    let isRecommended: Bool
    let isNotificationScheduled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isRecommended ? Color.clayYellow.opacity(0.23) : Color.neumoAccentSoft.opacity(0.38))
                    .frame(width: 35, height: 35)
                Image(systemName: isRecommended ? "sparkles" : "bus.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isRecommended ? Color.clayWarningText : Color.claySkyDeep)
            }
            Text(bus.departure)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.neumoText)
            Capsule()
                .fill(Color.claySky.opacity(0.28))
                .frame(height: 3)
            Image(systemName: "arrow.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.claySkyDeep)
            Text(bus.arrival)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.neumoMuted)
            BusNotificationActionButton(
                isScheduled: isNotificationScheduled,
                action: action
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct NextBusCard: View {
    let bus: Bus
    let routeName: String
    let countdown: String?
    let isNotificationScheduled: Bool
    let notifyAction: () -> Void
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("次のバス")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.neumoAccent)
                    Text("NEXT DEPARTURE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Color.neumoMuted)
                }
                Spacer()
                if let countdown {
                    Text(countdown)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.neumoAccentDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.neumoAccentSoft.opacity(0.65)))
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                TimePoint(time: bus.departure, label: bus.originName, isPrimary: true)

                VStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.neumoAccent)
                    Capsule()
                        .fill(Color.neumoAccent.opacity(0.25))
                        .frame(width: 48, height: 3)
                }
                .padding(.bottom, 20)

                TimePoint(time: bus.arrival, label: bus.destinationName, isPrimary: false)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.caption)
                    .foregroundStyle(Color.neumoMuted)
                Text(routeName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.neumoMuted)
                    .lineLimit(1)
                Spacer()
                BusNotificationActionButton(
                    isScheduled: isNotificationScheduled,
                    action: notifyAction
                )
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: designMode == .claymorphic
                            ? [Color.white, Color.white.opacity(0.9)]
                            : [Color.neumoSurfaceTop, Color.neumoSurface, Color.neumoSurfaceBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    (designMode == .claymorphic ? Color.white : Color.neumoHighlight).opacity(0.42),
                    lineWidth: 1
                )
        )
        .shadow(
            color: (designMode == .claymorphic ? Color.white : Color.neumoHighlight).opacity(designMode == .claymorphic ? 1.0 : 0.94),
            radius: designMode == .claymorphic ? 18 : 23,
            x: designMode == .claymorphic ? -9 : -12,
            y: designMode == .claymorphic ? -9 : -12
        )
        .shadow(
            color: (designMode == .claymorphic ? Color.clayShadow : Color.neumoShadow).opacity(designMode == .claymorphic ? 0.30 : 0.64),
            radius: designMode == .claymorphic ? 24 : 26,
            x: designMode == .claymorphic ? 10 : 12,
            y: designMode == .claymorphic ? 13 : 16
        )
    }
}

struct TimePoint: View {
    let time: String
    let label: String
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(time)
                .font(.system(size: isPrimary ? 40 : 31, weight: .bold, design: .rounded))
                .foregroundStyle(isPrimary ? Color.neumoText : Color.neumoMuted)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.neumoMuted)
                .lineLimit(1)
        }
    }
}

struct ServiceMessageCard: View {
    let message: String

    var body: some View {
        HStack(spacing: 14) {
            IconBubble(systemName: "calendar.badge.exclamationmark", tint: .neumoWarning, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("本日の運行")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.neumoText)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.neumoMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 12)
    }
}

struct EmptyBusCard: View {
    var body: some View {
        VStack(spacing: 10) {
            IconBubble(systemName: "bus", tint: .neumoMuted, size: 54)
            Text("条件に合うバスがありません")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.neumoText)
            Text("ルートや時刻を変更して再検索してください")
                .font(.caption)
                .foregroundStyle(Color.neumoMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 12)
    }
}

struct RouteSelectorCard: View {
    @Binding var selectedRoute: BusTimetableViewModel.Route
    let locationAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("路線を選択", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.neumoText)
                Spacer()
                Text("ROUTE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Color.neumoMuted)
            }

            Menu {
                ForEach(BusTimetableViewModel.Route.allCases, id: \.self) { route in
                    Button {
                        selectedRoute = route
                    } label: {
                        Label(route.rawValue, systemImage: route == selectedRoute ? "checkmark" : "arrow.right")
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Text(selectedRoute.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.neumoText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.neumoAccent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .neumorphicSurface(in: RoundedRectangle(cornerRadius: 17, style: .continuous), depth: 8)
            }
            .buttonStyle(SoftPressButtonStyle())

            Button(action: locationAction) {
                HStack(spacing: 7) {
                    Image(systemName: "location.fill")
                    Text("現在地から路線を選ぶ")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.neumoAccent)
            }
            .buttonStyle(SoftPressButtonStyle())
            .padding(.horizontal, 4)
        }
        .padding(18)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 12)
    }
}

struct SearchPanel: View {
    @ObservedObject var viewModel: BusTimetableViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeading(eyebrow: "SEARCH", title: "時刻を検索")

            HStack(spacing: 10) {
                SearchModeButton(
                    title: "出発時刻",
                    systemName: "arrow.up.right",
                    isSelected: viewModel.searchType == .departure
                ) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.searchType = .departure
                    }
                }
                SearchModeButton(
                    title: "到着希望",
                    systemName: "flag.checkered",
                    isSelected: viewModel.searchType == .arrival
                ) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.searchType = .arrival
                    }
                }
            }

            if viewModel.searchType == .departure {
                TimePickerRow(title: "出発時刻", date: $viewModel.departureTime) {
                    viewModel.setSearchToCurrentTime()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                TimePickerRow(title: "到着希望時刻", date: $viewModel.arrivalTime) {
                    viewModel.setSearchToCurrentTime()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            Button {
                withAnimation(.easeOut(duration: 0.22)) {
                    viewModel.performSearch()
                }
            } label: {
                HStack {
                    Text("この条件で検索")
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.neumoAccent, Color.neumoAccentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.neumoAccent.opacity(0.23), radius: 13, x: 5, y: 7)
            }
            .buttonStyle(SoftPressButtonStyle())
        }
        .padding(18)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), depth: 12)
    }
}

struct SearchModeButton: View {
    let title: String
    let systemName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemName)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.neumoAccentDeep : Color.neumoMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.neumoAccentSoft.opacity(0.42) : Color.clear)
            )
            .neumorphicSurface(
                in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                mode: isSelected ? .concave : .convex,
                shadowRadius: 6,
                offset: 3
            )
        }
        .buttonStyle(SoftPressButtonStyle())
    }
}

struct TimePickerRow: View {
    let title: String
    @Binding var date: Date
    let currentAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconBubble(systemName: "clock.fill", tint: .neumoAccent, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.neumoMuted)
                DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .tint(Color.neumoText)
            }
            Spacer(minLength: 0)
            Button(action: currentAction) {
                VStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                    Text("現時刻")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color.neumoAccent)
                .frame(width: 58, height: 52)
            }
            .buttonStyle(NeumorphicButtonStyle(cornerRadius: 14, shadowRadius: 6, offset: 3))
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 18, style: .continuous), depth: 8)
    }
}

struct BusResultRow: View {
    let bus: Bus
    @ObservedObject var viewModel: BusTimetableViewModel
    let isNotificationScheduled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text("おすすめ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.neumoAccentDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.neumoAccentSoft.opacity(0.78)))
                    if let note = bus.note {
                        Text(note)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.neumoMuted)
                            .lineLimit(1)
                    }
                }
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(bus.departure)
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.neumoText)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.neumoAccent)
                    Text(bus.arrival)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.neumoMuted)
                }
                Text(bus.stopSummary)
                    .font(.caption)
                    .foregroundStyle(Color.neumoMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                if let countdown = viewModel.countdownMessages[bus.id] {
                    Text(countdown)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(countdown == "出発済み" ? Color.neumoMuted : Color.neumoAccentDeep)
                        .multilineTextAlignment(.trailing)
                }
                BusNotificationActionButton(
                    isScheduled: isNotificationScheduled,
                    action: action
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 20, style: .continuous), depth: 9)
    }
}

struct BusTimetableRow: View {
    let bus: Bus
    let isRecommended: Bool
    let isNotificationScheduled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                if isRecommended {
                    Capsule()
                        .fill(Color.neumoAccent)
                        .frame(width: 4, height: 28)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(bus.departure)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.neumoText)
                    if let note = bus.note {
                        Text(note)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.neumoMuted)
                            .lineLimit(1)
                    }
                }
                .frame(width: 76, alignment: .leading)
            }

            HStack(spacing: 6) {
                Circle().fill(Color.neumoAccent.opacity(0.7)).frame(width: 5, height: 5)
                Rectangle().fill(Color.neumoAccent.opacity(0.18)).frame(height: 1)
                Image(systemName: "bus.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.neumoAccent)
                Rectangle().fill(Color.neumoAccent.opacity(0.18)).frame(height: 1)
                Circle().fill(Color.neumoAccent.opacity(0.7)).frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)

            Text(bus.arrival)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.neumoMuted)
                .frame(width: 52, alignment: .trailing)

            BusNotificationActionButton(
                isScheduled: isNotificationScheduled,
                action: action
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isRecommended
                ? Color.neumoAccent.opacity(0.055)
                : Color.clear
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
