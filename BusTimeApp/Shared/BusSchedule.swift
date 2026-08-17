import CoreLocation
import Foundation

/// 路線の停留所です。
enum BusStop: String, CaseIterable, Identifiable {
  case mansion = "コロンブスシティ"
  case station = "海浜幕張駅"
  case yokado = "ヨーカドー前"

  var id: Self { self }

  var systemName: String {
    switch self {
    case .mansion:
      return "building.2.fill"
    case .station:
      return "tram.fill"
    case .yokado:
      return "cart.fill"
    }
  }

  /// 停留所の位置です。現在地から最も近い停留所を選ぶために使います。
  var location: CLLocation {
    switch self {
    case .mansion:
      return CLLocation(latitude: 35.6589411, longitude: 140.0357708)
    case .station:
      return CLLocation(latitude: 35.6485608, longitude: 140.0416924)
    case .yokado:
      return CLLocation(latitude: 35.6569440, longitude: 140.0510100)
    }
  }
}

/// 出発地と目的地の組み合わせです。
enum BusRoute: String, CaseIterable {
  case mansionToStation = "コロンブスシティ → 海浜幕張駅"
  case stationToMansion = "海浜幕張駅 → コロンブスシティ"
  case mansionToYokado = "コロンブスシティ → ヨーカドー前"
  case stationToYokado = "海浜幕張駅 → ヨーカドー前"
  case yokadoToMansion = "ヨーカドー前 → コロンブスシティ"

  var origin: BusStop {
    switch self {
    case .mansionToStation, .mansionToYokado:
      return .mansion
    case .stationToMansion, .stationToYokado:
      return .station
    case .yokadoToMansion:
      return .yokado
    }
  }

  var destination: BusStop {
    switch self {
    case .mansionToStation:
      return .station
    case .stationToMansion, .yokadoToMansion:
      return .mansion
    case .mansionToYokado, .stationToYokado:
      return .yokado
    }
  }

  var guidance: String {
    switch self {
    case .stationToMansion:
      return L10n.Route.guidanceViaYokado
    case .mansionToYokado:
      return L10n.Route.guidanceToYokado
    default:
      return L10n.Route.guidanceDefault
    }
  }

  static func route(from origin: BusStop, to destination: BusStop) -> BusRoute? {
    allCases.first { $0.origin == origin && $0.destination == destination }
  }
}

/// 全経路の時刻表と、そこから次の便を探す処理です。
///
/// アプリ本体とウィジェットの両方から使うため、
/// 画面や通知に依存しない形でここにまとめています。
enum BusSchedule {
  /// 自宅にあたる停留所です。この停留所を起点に、行き先を決めます。
  static let homeStop: BusStop = .mansion
  /// 朝の向き（自宅から出る向き）として扱う時刻の上限です。
  static let outboundEndHour = 12
  /// 現在地から停留所を選ぶときに、離れていても選ぶ距離の上限です。
  static let maxAutoRouteDistance: CLLocationDistance = 1_500

  /// 全経路の時刻表です。
  static let timetables: [BusRoute: [Bus]] = makeTimetables()

  /// その経路の時刻表です。
  static func timetable(for route: BusRoute) -> [Bus] {
    timetables[route] ?? []
  }

  // MARK: - 次の便を探す

  /// これから出発する便を、早い順に返します。
  ///
  /// 運休日や午前4時の運行日境界は `BusNotificationTimeCalculator` が面倒を見るので、
  /// 便ごとに「次に実際に走る日時」を求めて並べ替えるだけで、
  /// 土日祝をまたいだ次の運行日の始発まで正しく拾えます。
  static func upcomingDepartures(
    on route: BusRoute,
    from now: Date,
    limit: Int,
    calendar: Calendar = .current
  ) -> [UpcomingBus] {
    timetable(for: route)
      .compactMap { bus -> UpcomingBus? in
        guard let date = BusNotificationTimeCalculator.nextDepartureDate(
          for: bus.departure,
          from: now,
          calendar: calendar
        ) else {
          return nil
        }
        return UpcomingBus(bus: bus, departureDate: date)
      }
      .sorted { $0.departureDate < $1.departureDate }
      .prefix(limit)
      .map { $0 }
  }

  /// これから出発する1本の便です。
  struct UpcomingBus: Identifiable, Equatable {
    let bus: Bus
    /// 実際に出発する日時です。日付をまたぐ便もこの値で正しく並びます。
    let departureDate: Date

    var id: String { "\(bus.id)-\(departureDate.timeIntervalSince1970)" }

    var departure: String { bus.departure }
    var arrival: String { bus.arrival }
    var note: String? { bus.note }

    static func == (lhs: UpcomingBus, rhs: UpcomingBus) -> Bool {
      lhs.id == rhs.id
    }
  }

  // MARK: - 経路を決める

  /// 現在地に最も近い停留所です。どの停留所からも離れていればnilを返します。
  static func nearestStop(to location: CLLocation) -> BusStop? {
    let nearest = BusStop.allCases
      .map { (distance: location.distance(from: $0.location), stop: $0) }
      .min { $0.distance < $1.distance }

    guard let nearest, nearest.distance <= maxAutoRouteDistance else { return nil }
    return nearest.stop
  }

  /// 現在地と時刻から経路を決めます。
  ///
  /// 位置が分かるときは、そこから出る便のある経路を選びます。
  /// 分からないときは、朝は自宅から出る向き、昼以降は自宅へ帰る向きとして、
  /// 行き先だけを前回の設定から引き継ぎます。
  /// 前回の経路をそのまま復元すると、朝と夕方で向きが逆になり半分の場面で外れるためです。
  static func recommendedRoute(
    at date: Date,
    location: CLLocation?,
    preferredPartner: BusStop,
    calendar: Calendar = .current
  ) -> BusRoute {
    if let location, let origin = nearestStop(to: location) {
      if let route = routeFrom(origin: origin, at: date, preferredPartner: preferredPartner) {
        return route
      }
    }
    return routeFromTimeOfDay(at: date, preferredPartner: preferredPartner, calendar: calendar)
  }

  /// その停留所から出る経路のうち、次の便が最も早いものです。
  private static func routeFrom(
    origin: BusStop,
    at date: Date,
    preferredPartner: BusStop
  ) -> BusRoute? {
    let candidates = BusRoute.allCases.filter { $0.origin == origin }
    guard !candidates.isEmpty else { return nil }

    // 前回と同じ行き先が使えるなら、それを優先します。
    if let preferred = candidates.first(where: { $0.destination == preferredPartner }),
       !upcomingDepartures(on: preferred, from: date, limit: 1).isEmpty {
      return preferred
    }

    return candidates
      .compactMap { route -> (route: BusRoute, date: Date)? in
        guard let next = upcomingDepartures(on: route, from: date, limit: 1).first else {
          return nil
        }
        return (route, next.departureDate)
      }
      .min { $0.date < $1.date }?
      .route
  }

  /// 時間帯から経路を決めます。
  private static func routeFromTimeOfDay(
    at date: Date,
    preferredPartner: BusStop,
    calendar: Calendar = .current
  ) -> BusRoute {
    let hour = calendar.component(.hour, from: date)
    let isOutbound = hour < outboundEndHour

    let preferred = isOutbound
      ? BusRoute.route(from: homeStop, to: preferredPartner)
      : BusRoute.route(from: preferredPartner, to: homeStop)

    return preferred ?? (isOutbound ? .mansionToStation : .stationToMansion)
  }

  // MARK: - 時刻表そのもの

  private static func makeTimetables() -> [BusRoute: [Bus]] {
    var timetables: [BusRoute: [Bus]] = [:]

    let columbusCity = "コロンブスシティ"
    let station = "海浜幕張駅"
    let yokado = "ヨーカドー前"
    let shoppingNote = L10n.BusNote.shopping
    let viaYokadoNote = L10n.BusNote.viaYokado
    let viaStationNote = L10n.BusNote.viaStation

    let shoppingRows = [
        (columbus: "9:30", station: "9:38", yokado: "9:46", columbusReturn: "9:53"),
        (columbus: "10:30", station: "10:38", yokado: "10:46", columbusReturn: "10:53"),
        (columbus: "11:30", station: "11:38", yokado: "11:46", columbusReturn: "11:53"),
        (columbus: "13:30", station: "13:38", yokado: "13:46", columbusReturn: "13:53"),
        (columbus: "14:30", station: "14:38", yokado: "14:46", columbusReturn: "14:53"),
        (columbus: "15:30", station: "15:38", yokado: "15:46", columbusReturn: "15:53"),
        (columbus: "16:30", station: "16:38", yokado: "16:46", columbusReturn: "16:53")
    ]

    func directBus(_ departure: String, _ arrival: String, from origin: String, to destination: String, note: String? = nil) -> Bus {
        Bus(departure: departure, arrival: arrival, originName: origin, destinationName: destination, note: note)
    }

    func shoppingBusToStation(_ row: (columbus: String, station: String, yokado: String, columbusReturn: String)) -> Bus {
        directBus(row.columbus, row.station, from: columbusCity, to: station, note: shoppingNote)
    }

    func shoppingBusStationToMansion(_ row: (columbus: String, station: String, yokado: String, columbusReturn: String)) -> Bus {
        Bus(stops: [
            BusStopTime(name: station, time: row.station),
            BusStopTime(name: yokado, time: row.yokado),
            BusStopTime(name: columbusCity, time: row.columbusReturn)
        ], note: viaYokadoNote)
    }

    timetables[.mansionToStation] = [
        directBus("6:03", "6:11", from: columbusCity, to: station),
        directBus("6:30", "6:38", from: columbusCity, to: station),
        directBus("6:40", "6:48", from: columbusCity, to: station),
        directBus("6:50", "6:58", from: columbusCity, to: station),
        directBus("7:00", "7:08", from: columbusCity, to: station),
        directBus("7:10", "7:18", from: columbusCity, to: station),
        directBus("7:20", "7:28", from: columbusCity, to: station),
        directBus("7:30", "7:38", from: columbusCity, to: station),
        directBus("7:40", "7:48", from: columbusCity, to: station),
        directBus("7:50", "7:58", from: columbusCity, to: station),
        directBus("8:00", "8:08", from: columbusCity, to: station),
        directBus("8:10", "8:18", from: columbusCity, to: station),
        directBus("8:20", "8:28", from: columbusCity, to: station),
        directBus("8:30", "8:38", from: columbusCity, to: station),
        directBus("8:40", "8:48", from: columbusCity, to: station),
        directBus("9:00", "9:08", from: columbusCity, to: station),
        shoppingBusToStation(shoppingRows[0]),
        directBus("10:00", "10:08", from: columbusCity, to: station),
        shoppingBusToStation(shoppingRows[1]),
        directBus("11:00", "11:08", from: columbusCity, to: station),
        shoppingBusToStation(shoppingRows[2]),
        directBus("13:00", "13:08", from: columbusCity, to: station),
        shoppingBusToStation(shoppingRows[3]),
        directBus("14:00", "14:08", from: columbusCity, to: station),
        shoppingBusToStation(shoppingRows[4]),
        directBus("15:00", "15:08", from: columbusCity, to: station),
        shoppingBusToStation(shoppingRows[5]),
        directBus("16:00", "16:08", from: columbusCity, to: station),
        shoppingBusToStation(shoppingRows[6]),
        directBus("17:04", "17:11", from: columbusCity, to: station),
        directBus("17:37", "17:44", from: columbusCity, to: station),
        directBus("18:02", "18:09", from: columbusCity, to: station),
        directBus("18:19", "18:26", from: columbusCity, to: station),
        directBus("18:37", "18:44", from: columbusCity, to: station),
        directBus("19:01", "19:08", from: columbusCity, to: station),
        directBus("19:20", "19:27", from: columbusCity, to: station),
        directBus("19:39", "19:46", from: columbusCity, to: station),
        directBus("19:59", "20:06", from: columbusCity, to: station),
        directBus("20:17", "20:24", from: columbusCity, to: station),
        directBus("20:51", "20:58", from: columbusCity, to: station),
        directBus("21:08", "21:15", from: columbusCity, to: station),
        directBus("21:55", "22:02", from: columbusCity, to: station),
        directBus("22:19", "22:26", from: columbusCity, to: station),
        directBus("22:37", "22:44", from: columbusCity, to: station),
        directBus("23:06", "23:13", from: columbusCity, to: station),
        directBus("23:38", "23:45", from: columbusCity, to: station),
        directBus("0:04", "0:11", from: columbusCity, to: station)
    ]

    timetables[.stationToMansion] = [
        directBus("6:11", "6:18", from: station, to: columbusCity),
        directBus("6:38", "6:45", from: station, to: columbusCity),
        directBus("6:48", "6:55", from: station, to: columbusCity),
        directBus("6:58", "7:05", from: station, to: columbusCity),
        directBus("7:08", "7:15", from: station, to: columbusCity),
        directBus("7:18", "7:25", from: station, to: columbusCity),
        directBus("7:28", "7:35", from: station, to: columbusCity),
        directBus("7:38", "7:45", from: station, to: columbusCity),
        directBus("7:48", "7:55", from: station, to: columbusCity),
        directBus("7:58", "8:05", from: station, to: columbusCity),
        directBus("8:08", "8:15", from: station, to: columbusCity),
        directBus("8:18", "8:25", from: station, to: columbusCity),
        directBus("8:28", "8:35", from: station, to: columbusCity),
        directBus("8:48", "8:55", from: station, to: columbusCity),
        shoppingBusStationToMansion(shoppingRows[0]),
        directBus("10:08", "10:16", from: station, to: columbusCity),
        shoppingBusStationToMansion(shoppingRows[1]),
        directBus("11:08", "11:16", from: station, to: columbusCity),
        shoppingBusStationToMansion(shoppingRows[2]),
        directBus("13:08", "13:16", from: station, to: columbusCity),
        shoppingBusStationToMansion(shoppingRows[3]),
        directBus("14:08", "14:16", from: station, to: columbusCity),
        shoppingBusStationToMansion(shoppingRows[4]),
        directBus("15:08", "15:16", from: station, to: columbusCity),
        shoppingBusStationToMansion(shoppingRows[5]),
        directBus("16:08", "16:16", from: station, to: columbusCity),
        shoppingBusStationToMansion(shoppingRows[6]),
        directBus("17:12", "17:19", from: station, to: columbusCity),
        directBus("17:46", "17:53", from: station, to: columbusCity),
        directBus("18:11", "18:18", from: station, to: columbusCity),
        directBus("18:28", "18:35", from: station, to: columbusCity),
        directBus("18:46", "18:53", from: station, to: columbusCity),
        directBus("19:10", "19:17", from: station, to: columbusCity),
        directBus("19:29", "19:36", from: station, to: columbusCity),
        directBus("19:48", "19:55", from: station, to: columbusCity),
        directBus("20:08", "20:15", from: station, to: columbusCity),
        directBus("20:26", "20:33", from: station, to: columbusCity),
        directBus("20:43", "20:50", from: station, to: columbusCity),
        directBus("21:00", "21:07", from: station, to: columbusCity),
        directBus("21:17", "21:24", from: station, to: columbusCity),
        directBus("21:39", "21:46", from: station, to: columbusCity),
        directBus("22:04", "22:11", from: station, to: columbusCity),
        directBus("22:28", "22:35", from: station, to: columbusCity),
        directBus("22:46", "22:53", from: station, to: columbusCity),
        directBus("23:15", "23:22", from: station, to: columbusCity),
        directBus("23:47", "23:54", from: station, to: columbusCity),
        directBus("0:13", "0:19", from: station, to: columbusCity)
    ]

    timetables[.mansionToYokado] = shoppingRows.map { row in
        Bus(stops: [
            BusStopTime(name: columbusCity, time: row.columbus),
            BusStopTime(name: station, time: row.station),
            BusStopTime(name: yokado, time: row.yokado)
        ], note: viaStationNote)
    }

    timetables[.stationToYokado] = shoppingRows.map { row in
        directBus(row.station, row.yokado, from: station, to: yokado, note: shoppingNote)
    }

    timetables[.yokadoToMansion] = shoppingRows.map { row in
        directBus(row.yokado, row.columbusReturn, from: yokado, to: columbusCity, note: shoppingNote)
    }

    return timetables
  }
}
