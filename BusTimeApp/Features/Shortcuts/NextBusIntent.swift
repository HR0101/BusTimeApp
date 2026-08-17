import AppIntents
import Foundation

/// 「次のバスは？」に答えるショートカットです。
///
/// アプリを開いて画面を見るまでもない場面のために、声だけで答えられるようにします。
/// 経路の決め方はアプリと同じで、自分で選んだ経路があればそれを、
/// なければ時間帯と前回の行き先から決めます。
@available(iOS 16.0, *)
struct NextBusIntent: AppIntent {
  static var title: LocalizedStringResource { "shortcut.nextBusTitle" }
  static var description: IntentDescription {
    IntentDescription(LocalizedStringResource("shortcut.nextBusDescription"))
  }

  /// 答えるだけなのでアプリは開きません。
  static var openAppWhenRun: Bool { false }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(dialog: IntentDialog(stringLiteral: NextBusAnswer.text(at: Date())))
  }
}

/// ショートカットが読み上げる文を組み立てます。
///
/// 声で聞く人には画面がないので、経路・出発・到着・残り時間を1文にまとめます。
enum NextBusAnswer {
  static func text(at now: Date) -> String {
    let route = SharedAppData.manualRoute ?? BusSchedule.recommendedRoute(
      at: now,
      location: nil,
      preferredPartner: SharedAppData.preferredPartnerStop
    )

    guard let next = BusSchedule.upcomingDepartures(
      on: route,
      from: now,
      limit: 1
    ).first else {
      return L10n.Shortcut.noService
    }

    return L10n.Shortcut.answer(
      route.rawValue,
      next.departure,
      next.arrival,
      BusRemainingTimeFormatter.string(until: next.departureDate, now: now)
    )
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
  }
}
