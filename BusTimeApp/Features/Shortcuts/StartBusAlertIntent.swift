import AppIntents
import Foundation

/// 指定した経路の次の便に通知を設定し、必要ならLive Activityも開始するショートカットです。
///
/// Live Activityはアプリが前面にいないと開始できません。また、通知の保存内容は
/// 画面のViewModelが持っているため、依頼をアプリへ渡して既存の処理で実行します。
/// そのため、このショートカットはアプリを開きます。
@available(iOS 16.0, *)
struct StartBusAlertIntent: AppIntent {
  static var title: LocalizedStringResource { "shortcut.startAlertTitle" }
  static var description: IntentDescription {
    IntentDescription(LocalizedStringResource("shortcut.startAlertDescription"))
  }

  static var openAppWhenRun: Bool { true }

  @Parameter(title: "shortcut.routeParameter", description: "shortcut.routeAutoDescription")
  var route: BusRouteOption?

  @Parameter(title: "shortcut.leadTimeParameter", default: .fiveMinutes)
  var leadTime: BusAlertLeadTime

  @Parameter(title: "shortcut.liveActivityParameter", default: true)
  var startsLiveActivity: Bool

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let targetRoute = ShortcutRouteResolver.route(for: route, at: AppDate.now())
    let outcome = await ShortcutRequestCenter.shared.submit(
      .startBusAlert(
        route: targetRoute,
        minutesBefore: leadTime.minutes,
        startsLiveActivity: startsLiveActivity
      )
    )
    let message = try outcome.requireSuccessMessage()
    return .result(dialog: IntentDialog(stringLiteral: message))
  }
}

/// 通知を設定する対象の便を選びます。
///
/// アプリの画面と同じく、運休日や別の運行日の便には通知を設定しません。
/// 「次の便」であっても、通知の時刻がすでに過ぎている便は飛ばし、
/// 通知が間に合う最初の便を選びます。
enum ShortcutBusSelector {
  enum Failure: Error, Equatable {
    /// 今日は運休日です。
    case noService
    /// 今日これから通知を設定できる便がありません。
    case noBusAvailable

    /// 利用者へ伝える理由です。
    var message: String {
      switch self {
      case .noService:
        return L10n.Notify.unavailableSuspended
      case .noBusAvailable:
        return L10n.Shortcut.noBusToAlert
      }
    }
  }

  static func select(
    on route: BusRoute,
    minutesBefore: Int,
    now: Date,
    calendar: Calendar = AppCalendar.japan
  ) -> Result<Bus, Failure> {
    guard
      let serviceDayStart = BusNotificationTimeCalculator.serviceDayStart(
        for: now,
        calendar: calendar
      ), BusServiceCalendar.isServiceDay(serviceDayStart, calendar: calendar)
    else {
      return .failure(.noService)
    }

    let candidates = BusSchedule.timetable(for: route).compactMap { bus in
      notificationCandidate(
        for: bus,
        minutesBefore: minutesBefore,
        now: now,
        calendar: calendar
      )
    }

    guard let earliest = candidates.min(by: { $0.departureDate < $1.departureDate }) else {
      return .failure(.noBusAvailable)
    }
    return .success(earliest.bus)
  }

  private static func notificationCandidate(
    for bus: Bus,
    minutesBefore: Int,
    now: Date,
    calendar: Calendar
  ) -> (bus: Bus, departureDate: Date)? {
    guard
      let dates = BusNotificationTimeCalculator.notificationDate(
        for: bus.departure,
        minutesBefore: minutesBefore,
        from: now,
        calendar: calendar
      )
    else {
      return nil
    }

    // 今日の便が出尽くすと、次の運行日の便へ繰り越されます。
    // 画面では他の運行日の通知を扱わないため、ここでも対象にしません。
    guard
      BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
        for: bus.departure,
        from: now,
        calendar: calendar
      ) == dates.departureDate
    else {
      return nil
    }
    return (bus, dates.departureDate)
  }
}
