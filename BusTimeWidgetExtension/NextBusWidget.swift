import CoreLocation
import SwiftUI
import WidgetKit

/// ホーム画面に置く「次のバス」ウィジェットです。
///
/// アプリを開かなくても、次の便とその次の便が分かるようにします。
/// どの経路を出すかは現在地から決め、位置情報が使えないときは
/// 時間帯と前回の行き先から決めます。
struct NextBusWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: SharedAppData.widgetKind, provider: NextBusProvider()) { entry in
      NextBusWidgetView(entry: entry)
        .widgetContainerBackground()
    }
    .configurationDisplayName(L10n.Widget.displayName)
    .description(L10n.Widget.description)
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
  }
}

private extension View {
  /// ウィジェットの地を敷きます。
  ///
  /// iOS 17からは、ウィジェット自身が地を宣言する形に変わりました。
  /// 16でも動かす必要があるので、使える場合だけ敷きます。
  @ViewBuilder
  func widgetContainerBackground() -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(.fill.tertiary, for: .widget)
    } else {
      self
    }
  }
}

// MARK: - 表示する内容

/// ウィジェットが1回の表示で使うデータです。
struct NextBusEntry: TimelineEntry {
  let date: Date
  let route: BusRoute
  /// 現在地から経路が決まったかどうかです。決め方を小さく添えるために持ちます。
  let isFromLocation: Bool
  /// これから出発する便です。早い順に入ります。
  let departures: [BusSchedule.UpcomingBus]

  var next: BusSchedule.UpcomingBus? { departures.first }
  var following: BusSchedule.UpcomingBus? {
    departures.count > 1 ? departures[1] : nil
  }

  /// 見本として出す内容です。ウィジェットを選ぶ画面で使われます。
  static func placeholder(at date: Date = Date()) -> NextBusEntry {
    let route = BusRoute.mansionToStation
    return NextBusEntry(
      date: date,
      route: route,
      isFromLocation: false,
      departures: BusSchedule.upcomingDepartures(on: route, from: date, limit: 2)
    )
  }
}

// MARK: - 表示を組み立てる

struct NextBusProvider: TimelineProvider {
  /// 次の便が出たあと、どれだけ先の便まで並べておくかです。
  /// 多めに作っておくと、システムが作り直しに来られなくても表示が古くなりません。
  private static let plannedDepartureCount = 6
  /// 1分ごとの表示を、何分先まで用意しておくかです。
  /// システムが作り直しに来られなくても、この時間は残り時間が正しく進みます。
  private static let plannedMinuteCount = 120

  private let locationProvider = WidgetLocationProvider()

  func placeholder(in context: Context) -> NextBusEntry {
    NextBusEntry.placeholder()
  }

  func getSnapshot(in context: Context, completion: @escaping (NextBusEntry) -> Void) {
    Task {
      completion(await makeEntry(at: Date()).entry)
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<NextBusEntry>) -> Void) {
    Task {
      let now = Date()
      let (entry, departures) = await makeEntry(at: now)

      // 出発までの時間は分単位で出すので、1分ごとの表示をまとめて用意します。
      // 便が出発した時点で「次」と「その次」が繰り上がるのも、この並びで表せます。
      var entries: [NextBusEntry] = []
      let calendar = Calendar.current
      let firstMinute = calendar.date(
        bySetting: .second,
        value: 0,
        of: now
      ) ?? now

      for step in 0..<Self.plannedMinuteCount {
        guard let date = calendar.date(
          byAdding: .minute,
          value: step,
          to: firstMinute
        ) else { break }

        // その時点でまだ出発していない便だけを残します。
        let remaining = departures.filter { $0.departureDate > date }
        guard !remaining.isEmpty else { break }

        entries.append(
          NextBusEntry(
            date: step == 0 ? now : date,
            route: entry.route,
            isFromLocation: entry.isFromLocation,
            departures: Array(remaining.prefix(2))
          )
        )
      }

      if entries.isEmpty {
        entries = [entry]
      }

      // 用意した分を出しきったら、そこで作り直してもらいます。
      let reloadDate = entries.last?.date ?? now.addingTimeInterval(60 * 60)
      completion(Timeline(entries: entries, policy: .after(reloadDate)))
    }
  }

  /// 現在地と設定から、表示する内容を1つ作ります。
  private func makeEntry(
    at date: Date
  ) async -> (entry: NextBusEntry, departures: [BusSchedule.UpcomingBus]) {
    let location = await locationProvider.currentLocation()

    // 自分で選んだ経路があるときは、アプリと食い違わないようそれを使います。
    let manualRoute = SharedAppData.manualRoute
    let route = manualRoute ?? BusSchedule.recommendedRoute(
      at: date,
      location: location,
      preferredPartner: SharedAppData.preferredPartnerStop
    )

    let departures = BusSchedule.upcomingDepartures(
      on: route,
      from: date,
      limit: Self.plannedDepartureCount
    )

    let entry = NextBusEntry(
      date: date,
      route: route,
      isFromLocation: manualRoute == nil && location != nil,
      departures: Array(departures.prefix(2))
    )
    return (entry, departures)
  }
}

// MARK: - 現在地

/// ウィジェットから現在地を1回だけ取りに行くための入れ物です。
///
/// ウィジェットは自分で位置情報の許可を求められません。
/// アプリが許可を得ている場合にだけ使えるので、使えるかどうかを先に確かめます。
private final class WidgetLocationProvider: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var continuation: CheckedContinuation<CLLocation?, Never>?

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  /// 現在地です。取れないときはnilを返します。
  func currentLocation() async -> CLLocation? {
    guard manager.isAuthorizedForWidgetUpdates else { return nil }

    // 直前に測った位置が残っていれば、待たずにそれを使います。
    if let cached = manager.location {
      return cached
    }

    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      manager.requestLocation()
    }
  }

  /// 結果を1回だけ返します。位置の取得は成功と失敗の両方が届くことがあるためです。
  private func finish(with location: CLLocation?) {
    continuation?.resume(returning: location)
    continuation = nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    finish(with: locations.last)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finish(with: nil)
  }
}
