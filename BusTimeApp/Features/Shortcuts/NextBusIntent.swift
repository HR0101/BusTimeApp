import AppIntents
import Foundation

/// 「次のバスは？」に答えるショートカットです。
///
/// アプリを開いて画面を見るまでもない場面のために、声だけで答えられるようにします。
/// 経路を指定しなければ、アプリと同じ判断で決めます。自分で選んだ経路があればそれを、
/// なければ時間帯と前回の行き先から決めます。
///
/// 出発日時を値として返すので、ショートカットの後続のアクションへ渡せます。
@available(iOS 16.0, *)
struct NextBusIntent: AppIntent {
  static var title: LocalizedStringResource { "shortcut.nextBusTitle" }
  static var description: IntentDescription {
    IntentDescription(LocalizedStringResource("shortcut.nextBusDescription"))
  }

  /// 答えるだけなのでアプリは開きません。
  static var openAppWhenRun: Bool { false }

  @Parameter(title: "shortcut.routeParameter", description: "shortcut.routeAutoDescription")
  var route: BusRouteOption?

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Date> {
    guard let answer = NextBusAnswer.answer(for: route?.route, at: Date()) else {
      throw ShortcutActionError.failed(L10n.Shortcut.noService)
    }
    return .result(value: answer.departureDate, dialog: IntentDialog(stringLiteral: answer.text))
  }
}

/// ショートカットが読み上げる文を組み立てます。
///
/// 声で聞く人には画面がないので、経路・出発・到着・残り時間を1文にまとめます。
enum NextBusAnswer {
  /// 答えの文と、次の便の出発日時です。
  struct Answer: Equatable {
    let text: String
    let departureDate: Date
  }

  /// 指定した経路の次の便について答えます。経路を指定しなければアプリと同じ判断で決めます。
  /// どの経路にも次の便がなければnilを返します。
  static func answer(for route: BusRoute?, at now: Date) -> Answer? {
    let route = route ?? ShortcutRouteResolver.automaticRoute(at: now)

    guard let next = BusSchedule.upcomingDepartures(
      on: route,
      from: now,
      limit: 1
    ).first else {
      return nil
    }

    let text = L10n.Shortcut.answer(
      route.rawValue,
      next.departure,
      next.arrival,
      BusRemainingTimeFormatter.string(until: next.departureDate, now: now)
    )
    return Answer(text: text, departureDate: next.departureDate)
  }

  /// 経路を指定せずに答える文です。
  static func text(at now: Date) -> String {
    answer(for: nil, at: now)?.text ?? L10n.Shortcut.noService
  }
}

/// 端末に登録するショートカットの一覧です。
///
/// ここに載せたものが、アプリを入れた時点で「ショートカット」アプリと
/// Siriから使えるようになります。
@available(iOS 16.0, *)
struct BusTimeAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: NextBusIntent(),
      phrases: [
        "\(.applicationName)で次のバス",
        "Next bus in \(.applicationName)",
        "\(.applicationName)の次のバス"
      ],
      shortTitle: "shortcut.nextBusTitle",
      systemImageName: "bus.fill"
    )

    AppShortcut(
      intent: OpenRouteIntent(),
      phrases: [
        "\(.applicationName)で経路を開く",
        "Open a route in \(.applicationName)"
      ],
      shortTitle: "shortcut.openRouteTitle",
      systemImageName: "map.fill"
    )

    AppShortcut(
      intent: StartBusAlertIntent(),
      phrases: [
        "\(.applicationName)で次のバスの通知を設定",
        "Set a bus alert in \(.applicationName)"
      ],
      shortTitle: "shortcut.startAlertTitle",
      systemImageName: "bell.badge.fill"
    )
  }
}
