import SwiftUI

// MARK: - タブ

/// 画面下部のタブです。
enum MainTab: Hashable {
  case home
  case timetable

  var title: String {
    switch self {
    case .home:
      return L10n.Tab.home
    case .timetable:
      return L10n.Timetable.title
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
      return L10n.Tab.homeAccessibility
    case .timetable:
      return L10n.Tab.timetableAccessibility
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
  @StateObject private var weatherViewModel = WeatherViewModel()
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
        .task {
          await weatherViewModel.refresh()
        }
        .onChange(of: scenePhase) { newPhase in
          if newPhase == .active {
            skyClock.refresh()
            viewModel.refreshForAppActivation()
            viewModel.checkLocationAndSetOrigin()
            settingsViewModel.refreshLiveActivityAvailability()
            Task { await weatherViewModel.refreshIfNeeded() }
          }
        }
        // 経路・検索方法・時刻のいずれを変えても、その場で結果へ反映します。
        // 実行ボタンを置かないぶん、変更が即座に画面へ出ることを保証します。
        .onChange(of: viewModel.selectedRoute) { _ in
          viewModel.performSearch()
        }
        .onChange(of: viewModel.serviceDay) { _ in
          viewModel.performSearch()
        }
        .onChange(of: viewModel.searchType) { _ in
          viewModel.performSearch()
        }
        .onChange(of: viewModel.searchTime) { _ in
          viewModel.performSearch()
        }
        .sheet(isPresented: Binding(
          get: { coordinator.isTutorialPresented },
          set: { if !$0 { coordinator.send(.dismiss) } }
        )) {
          TutorialView()
            .environment(\.sky, palette)
            .environment(\.skyWeather, weatherViewModel.weather)
            .environment(\.skyCardOpacity, settingsViewModel.cardOpacity)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
          get: { coordinator.isSettingsPresented },
          set: { if !$0 { coordinator.send(.dismiss) } }
        )) {
          SettingsView(viewModel: settingsViewModel)
            .environment(\.sky, palette)
            .environment(\.skyWeather, weatherViewModel.weather)
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
          .environment(\.skyWeather, weatherViewModel.weather)
          .environment(\.skyCardOpacity, settingsViewModel.cardOpacity)
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
            .environment(\.skyWeather, weatherViewModel.weather)
            .environment(\.skyCardOpacity, settingsViewModel.cardOpacity)
            .presentationDragIndicator(.visible)
          }
        }
        .alert(L10n.Notify.resultTitle, isPresented: Binding(
          get: { coordinator.isNotificationResultPresented },
          set: { if !$0 { coordinator.send(.dismiss) } }
        )) {
          Button(L10n.Common.ok) { coordinator.send(.dismiss) }
        } message: {
          Text(coordinator.notificationMessage ?? "")
        }
        .alert(
          L10n.LiveActivity.errorTitle,
          isPresented: Binding(
            get: { coordinator.isLiveActivityErrorPresented },
            set: { if !$0 {
              viewModel.liveActivityError = nil
              coordinator.send(.clearError)
            } }
          )
        ) {
          Button(L10n.LiveActivity.openSettings) {
            viewModel.openAppSettings()
            viewModel.liveActivityError = nil
            coordinator.send(.clearError)
          }
          Button(L10n.Common.ok) {
            viewModel.liveActivityError = nil
            coordinator.send(.clearError)
          }
        } message: {
          Text(coordinator.liveActivityErrorMessage ?? L10n.LiveActivity.genericError)
        }
        .onChange(of: viewModel.liveActivityError) { errorMessage in
          if let errorMessage {
            coordinator.send(.liveActivityFailed(errorMessage))
            viewModel.liveActivityError = nil
          }
        }
    }
    .environment(\.sky, palette)
    .environment(\.skyWeather, weatherViewModel.weather)
    .environment(\.skyCardOpacity, settingsViewModel.cardOpacity)
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

        RouteHeaderCard(
          viewModel: viewModel,
          locationAction: viewModel.useCurrentLocationForRoute
        )

        ServiceDayTimeCard(viewModel: viewModel)

        serviceDayNotice
        departuresSection

        serviceFooter
      }
      .padding(.horizontal, horizontalPadding)
      .padding(.top, 10)
      .padding(.bottom, 28)
    }
  }

  /// 便の情報をまとめたカードです。
  ///
  /// 次の便とそれに続く便は同じ「いつ乗れるか」の話なので、
  /// カードを分けずに1枚へ収め、区切り線だけで役割を分けています。
  @ViewBuilder
  private var departuresSection: some View {
    if case let .failed(message) = viewModel.state {
      NoticeCard(
        title: L10n.Result.failedTitle,
        message: message,
        systemImage: "exclamationmark.triangle.fill",
        isWarning: true
      )
    } else if let nextBus = viewModel.searchResults.first {
      VStack(alignment: .leading, spacing: 16) {
        NextDepartureHero(
          bus: nextBus,
          remainingMinutes: viewModel.remainingMinutes[nextBus.id],
          isNotificationScheduled: scheduledBusIDs.contains(nextBus.id),
          sectionTitle: viewModel.resultSectionTitle,
          isRealtime: viewModel.isRealtimeContext,
          notificationUnavailableReason: viewModel.notificationUnavailableReason,
          notifyAction: { selectBus(nextBus) }
        )

        followingDepartures
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .skyCard(padding: 20)
    } else {
      NoticeCard(
        title: L10n.Result.emptyTitle,
        message: L10n.Result.emptyMessage,
        systemImage: "bus",
        isWarning: false
      )
    }
  }

  /// 次の便に続く候補です。検索結果が1件だけのときは表示しません。
  @ViewBuilder
  private var followingDepartures: some View {
    let followingBuses = Array(viewModel.searchResults.dropFirst())

    if !followingBuses.isEmpty {
      SkyDivider()

      VStack(alignment: .leading, spacing: 10) {
        SkySectionLabel(text: viewModel.followingSectionTitle)

        ForEach(followingBuses) { bus in
          UpcomingDepartureRow(
            bus: bus,
            countdown: viewModel.countdownMessages[bus.id],
            isNotificationScheduled: scheduledBusIDs.contains(bus.id),
            canSchedule: viewModel.notificationUnavailableReason == nil,
            action: { selectBus(bus) }
          )
        }
      }
    }
  }

  /// 運休日でも時刻は調べられるようにしたうえで、運休であることは必ず伝えます。
  @ViewBuilder
  private var serviceDayNotice: some View {
    if let message = viewModel.serviceDayNotice {
      NoticeCard(
        title: L10n.Result.serviceNoticeTitle,
        message: message,
        systemImage: "calendar.badge.exclamationmark",
        isWarning: true
      )
    }
  }

  private var serviceFooter: some View {
    DynamicTypeStack(verticalAlignment: .center, spacing: 8) {
      Circle()
        .fill(palette.positive)
        .frame(width: 6, height: 6)
      Text(L10n.Result.footer)
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
          L10n.Notify.scheduledMessage(
            item.busDescription,
            item.notificationDescription,
            liveActivityMessage
          )
        ))
      case let .failure(error):
        coordinator.send(.notificationScheduled(error.localizedDescription))
      }
    }
  }

  private func startLiveActivityIfNeeded(for bus: Bus, shouldStart: Bool) -> String {
    guard shouldStart else { return "" }

    if viewModel.trackedBusId == bus.id {
      return L10n.Notify.alsoLiveActivity
    }

    guard viewModel.trackedBusId == nil else {
      return L10n.Notify.onlyNormalNotification
    }

    viewModel.startLiveActivity(for: bus)
    if viewModel.trackedBusId == bus.id {
      return L10n.Notify.liveActivityStarted
    }

    // 通常通知は登録済みなので、Live Activityの失敗も同じ完了画面で伝えます。
    viewModel.liveActivityError = nil
    return L10n.Notify.liveActivityFailed
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
