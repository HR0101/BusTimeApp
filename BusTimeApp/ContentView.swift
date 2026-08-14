import SwiftUI

// MARK: - タブ

/// 画面下部のタブです。
enum MainTab: Hashable {
  case home
  case timetable

  var title: String {
    switch self {
    case .home:
      return "ホーム"
    case .timetable:
      return "時刻表"
    }
  }

  var systemName: String {
    switch self {
    case .home:
      return "house.fill"
    case .timetable:
      return "clock.fill"
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .home:
      return "ホームタブ"
    case .timetable:
      return "時刻表タブ"
    }
  }
}

/// iOS 26より前の環境で使う、自前のタブバーです。
private struct SkyTabBar: View {
  @Binding var selection: MainTab
  @Environment(\.sky) private var sky

  var body: some View {
    HStack(spacing: 4) {
      tabButton(.home)
      tabButton(.timetable)
    }
    .padding(5)
    .background(Capsule().fill(sky.surface))
    .overlay(Capsule().stroke(sky.surfaceBorder, lineWidth: SkyMetrics.borderWidth))
    .padding(.horizontal, SkyMetrics.screenPadding)
    .padding(.top, 6)
  }

  private func tabButton(_ tab: MainTab) -> some View {
    let isSelected = selection == tab

    return Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        selection = tab
      }
    } label: {
      Label(tab.title, systemImage: tab.systemName)
        .dynamicFont(size: 14, relativeTo: .subheadline, weight: .bold, design: .rounded)
        .foregroundStyle(isSelected ? Color.white : sky.inkSecondary)
        .frame(maxWidth: .infinity, minHeight: SkyMetrics.minimumTapSize)
        .background(Capsule().fill(isSelected ? sky.accent : Color.clear))
    }
    .buttonStyle(SkyPressStyle())
    .accessibilityLabel(tab.accessibilityLabel)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - メイン画面

struct ContentView: View {
  @StateObject private var viewModel = HomeViewModel()
  @StateObject private var coordinator = AppCoordinator()
  @StateObject private var settingsViewModel = SettingsViewModel()
  @StateObject private var notificationViewModel = NotificationViewModel()
  @StateObject private var skyClock = SkyClock()
  @State private var selectedTab: MainTab = .home
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// 空の色が切り替わるときのアニメーション時間です。
  private let paletteAnimationDuration: Double = 0.9

  private var palette: SkyPalette {
    skyClock.palette
  }

  private var scheduledBusIDs: Set<String> {
    Set(notificationViewModel.scheduledNotifications.map(\.busID))
  }

  private var horizontalPadding: CGFloat {
    dynamicTypeSize.isAccessibilitySize
      ? SkyMetrics.compactScreenPadding
      : SkyMetrics.screenPadding
  }

  var body: some View {
    NavigationStack {
      mainTabContent
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
          coordinator.send(.launch)
          viewModel.refreshRouteAvailability()
          viewModel.performSearch()
          viewModel.checkLocationAndSetOrigin()
          notificationViewModel.refresh()
        }
        .onChange(of: scenePhase) { newPhase in
          if newPhase == .active {
            skyClock.refresh()
            viewModel.refreshForAppActivation()
            viewModel.checkLocationAndSetOrigin()
            settingsViewModel.refreshLiveActivityAvailability()
          }
        }
        .onChange(of: viewModel.selectedRoute) { _ in
          viewModel.performSearch()
        }
        .sheet(isPresented: Binding(
          get: { coordinator.isTutorialPresented },
          set: { if !$0 { coordinator.send(.dismiss) } }
        )) {
          TutorialView()
            .environment(\.sky, palette)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
          get: { coordinator.isSettingsPresented },
          set: { if !$0 { coordinator.send(.dismiss) } }
        )) {
          SettingsView(viewModel: settingsViewModel)
            .environment(\.sky, palette)
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
          .environment(\.sky, palette)
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
              isLiveActivityEnabled: settingsViewModel.shouldUseLiveActivity,
              isLiveActivityAvailable: settingsViewModel.isLiveActivityAvailable,
              onOpenNotificationSettings: notificationViewModel.openNotificationSettings,
              onSchedule: { minutes in scheduleNotification(minutes: minutes) },
              onStartLiveActivity: {
                if notificationViewModel.notification(for: bus.id) == nil {
                  scheduleNotification(minutes: 5, startLiveActivity: true)
                } else {
                  viewModel.startLiveActivity(for: bus)
                  coordinator.send(.dismiss)
                }
              },
              onEndLiveActivity: {
                viewModel.endLiveActivity()
              }
            )
            .environment(\.sky, palette)
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
        .onChange(of: viewModel.liveActivityError) { errorMessage in
          if let errorMessage {
            coordinator.send(.liveActivityFailed(errorMessage))
            viewModel.liveActivityError = nil
          }
        }
    }
    .environment(\.sky, palette)
    .animation(.easeInOut(duration: paletteAnimationDuration), value: palette)
    .preferredColorScheme(palette.isNight ? .dark : .light)
  }

  // MARK: - タブの構成

  @ViewBuilder
  private var mainTabContent: some View {
#if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      liquidGlassTabContent
    } else {
      legacyTabContent
    }
#else
    legacyTabContent
#endif
  }

  private var legacyTabContent: some View {
    VStack(spacing: 0) {
      TabView(selection: $selectedTab) {
        homeTab
          .tag(MainTab.home)

        timetableTab
          .tag(MainTab.timetable)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .animation(.easeInOut(duration: 0.2), value: selectedTab)

      SkyTabBar(selection: $selectedTab)
    }
    .background(SkyBackground())
  }

#if compiler(>=6.2)
  @available(iOS 26.0, *)
  private var liquidGlassTabContent: some View {
    // iOS 26のタブは各タブを独自の面に載せるため、TabView全体ではなく
    // タブごとに背景を敷きます。
    TabView(selection: $selectedTab) {
      homeTab
        .background(SkyBackground())
        .tabItem {
          Label(MainTab.home.title, systemImage: MainTab.home.systemName)
            .accessibilityLabel(MainTab.home.accessibilityLabel)
        }
        .tag(MainTab.home)

      timetableTab
        .background(SkyBackground())
        .tabItem {
          Label(MainTab.timetable.title, systemImage: MainTab.timetable.systemName)
            .accessibilityLabel(MainTab.timetable.accessibilityLabel)
        }
        .tag(MainTab.timetable)
    }
    .tabViewStyle(.tabBarOnly)
    .tint(palette.accent)
    .animation(.easeInOut(duration: 0.2), value: selectedTab)
  }
#endif

  private var timetableTab: some View {
    TimetableTabView(
      viewModel: viewModel,
      scheduledBusIDs: scheduledBusIDs,
      onSelectBus: selectBus
    )
  }

  // MARK: - ホーム

  private var homeTab: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: SkyMetrics.sectionSpacing) {
        HomeHeaderBar(
          hasScheduledNotification: !scheduledBusIDs.isEmpty,
          notificationAction: { coordinator.send(.showNotifications) },
          settingsAction: { coordinator.send(.showSettings) },
          helpAction: { coordinator.send(.showTutorial) }
        )

        heroSection
        upcomingSection

        SearchPanel(
          viewModel: viewModel,
          locationAction: viewModel.checkLocationAndSetOrigin
        )

        serviceFooter
      }
      .padding(.horizontal, horizontalPadding)
      .padding(.top, 10)
      .padding(.bottom, 28)
    }
  }

  /// 画面の主役です。次に乗れる便の残り時間を大きく表示します。
  @ViewBuilder
  private var heroSection: some View {
    if case let .serviceUnavailable(message) = viewModel.state {
      NoticeCard(
        title: "本日の運行",
        message: message,
        systemImage: "calendar.badge.exclamationmark",
        isWarning: true
      )
    } else if case let .failed(message) = viewModel.state {
      NoticeCard(
        title: "読み込みできませんでした",
        message: message,
        systemImage: "exclamationmark.triangle.fill",
        isWarning: true
      )
    } else if let nextBus = viewModel.searchResults.first {
      NextDepartureHero(
        bus: nextBus,
        remainingMinutes: viewModel.remainingMinutes[nextBus.id],
        isNotificationScheduled: scheduledBusIDs.contains(nextBus.id),
        notifyAction: { selectBus(nextBus) }
      )
    } else {
      NoticeCard(
        title: "条件に合うバスがありません",
        message: "行き先または時刻を変えて検索してください",
        systemImage: "bus",
        isWarning: false
      )
    }
  }

  /// 次の便に続く候補です。検索結果が1件だけのときは表示しません。
  @ViewBuilder
  private var upcomingSection: some View {
    let followingBuses = Array(viewModel.searchResults.dropFirst())

    if viewModel.holidayMessage == nil, !followingBuses.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        SkySectionLabel(text: "このあとの便")

        ForEach(followingBuses) { bus in
          UpcomingDepartureRow(
            bus: bus,
            countdown: viewModel.countdownMessages[bus.id],
            isNotificationScheduled: scheduledBusIDs.contains(bus.id),
            action: { selectBus(bus) }
          )
        }
      }
    }
  }

  private var serviceFooter: some View {
    DynamicTypeStack(verticalAlignment: .center, spacing: 8) {
      Circle()
        .fill(palette.positive)
        .frame(width: 6, height: 6)
      Text("平日のみ運行・時刻表は現地の案内を優先してください")
        .dynamicFont(size: 11, relativeTo: .caption2, weight: .medium)
        .foregroundStyle(palette.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.top, 2)
  }

  // MARK: - 通知の操作

  private func selectBus(_ bus: Bus) {
    coordinator.send(.selectBus(bus))
  }

  private func scheduleNotification(
    minutes: Int,
    startLiveActivity: Bool? = nil
  ) {
    guard let bus = coordinator.selectedBus else { return }
    notificationViewModel.scheduleNotification(
      for: bus,
      routeName: viewModel.selectedRoute.rawValue,
      minutesBefore: minutes
    ) { result in
      switch result {
      case let .success(item):
        let shouldStartLiveActivity = startLiveActivity
          ?? settingsViewModel.shouldUseLiveActivity
        let liveActivityMessage = startLiveActivityIfNeeded(
          for: bus,
          shouldStart: shouldStartLiveActivity
        )
        coordinator.send(.notificationScheduled(
          "通知を設定しました。\n\n\(item.busDescription)\n\(item.notificationDescription)にお知らせします。\(liveActivityMessage)\n\n※時刻表の予定です。遅延・運休は反映されません。"
        ))
      case let .failure(error):
        coordinator.send(.notificationScheduled(error.localizedDescription))
      }
    }
  }

  private func startLiveActivityIfNeeded(for bus: Bus, shouldStart: Bool) -> String {
    guard shouldStart else { return "" }

    if viewModel.trackedBusId == bus.id {
      return "\nLive Activityも表示中です。"
    }

    guard viewModel.trackedBusId == nil else {
      return "\n別の便をLive Activityで表示中のため、通常通知だけを設定しました。"
    }

    viewModel.startLiveActivity(for: bus)
    if viewModel.trackedBusId == bus.id {
      return "\nLive Activityも開始しました。"
    }

    // 通常通知は登録済みなので、Live Activityの失敗も同じ完了画面で伝えます。
    viewModel.liveActivityError = nil
    return "\n通常通知は設定されましたが、Live Activityは開始できませんでした。"
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
