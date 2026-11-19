import AppIntents
import Foundation

/// ショートカットで選べる経路です。
///
/// `BusRoute` の生の値は日本語の表示名なので、そのまま保存すると表示名を直したときに
/// 利用者が作ったショートカットが壊れます。そのため保存される値は変わらない識別子にして、
/// 表示名とは切り離しています。
@available(iOS 16.0, *)
enum BusRouteOption: String, CaseIterable, AppEnum {
  case mansionToStation
  case stationToMansion
  case mansionToYokado
  case stationToYokado
  case yokadoToMansion

  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(name: "shortcut.routeParameter")
  }

  static var caseDisplayRepresentations: [BusRouteOption: DisplayRepresentation] {
    [
      .mansionToStation: DisplayRepresentation(title: "shortcut.routeMansionToStation"),
      .stationToMansion: DisplayRepresentation(title: "shortcut.routeStationToMansion"),
      .mansionToYokado: DisplayRepresentation(title: "shortcut.routeMansionToYokado"),
      .stationToYokado: DisplayRepresentation(title: "shortcut.routeStationToYokado"),
      .yokadoToMansion: DisplayRepresentation(title: "shortcut.routeYokadoToMansion")
    ]
  }

  /// アプリ本体で使う経路です。
  var route: BusRoute {
    switch self {
    case .mansionToStation:
      return .mansionToStation
    case .stationToMansion:
      return .stationToMansion
    case .mansionToYokado:
      return .mansionToYokado
    case .stationToYokado:
      return .stationToYokado
    case .yokadoToMansion:
      return .yokadoToMansion
    }
  }

  init(route: BusRoute) {
    switch route {
    case .mansionToStation:
      self = .mansionToStation
    case .stationToMansion:
      self = .stationToMansion
    case .mansionToYokado:
      self = .mansionToYokado
    case .stationToYokado:
      self = .stationToYokado
    case .yokadoToMansion:
      self = .yokadoToMansion
    }
  }
}

/// ショートカットで選べる、出発の何分前に知らせるかです。
///
/// アプリの通知画面と同じ3つに限り、登録ミスを減らします。
@available(iOS 16.0, *)
enum BusAlertLeadTime: String, CaseIterable, AppEnum {
  case fiveMinutes
  case tenMinutes
  case fifteenMinutes

  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(name: "shortcut.leadTimeParameter")
  }

  static var caseDisplayRepresentations: [BusAlertLeadTime: DisplayRepresentation] {
    [
      .fiveMinutes: DisplayRepresentation(title: "shortcut.leadTimeFiveMinutes"),
      .tenMinutes: DisplayRepresentation(title: "shortcut.leadTimeTenMinutes"),
      .fifteenMinutes: DisplayRepresentation(title: "shortcut.leadTimeFifteenMinutes")
    ]
  }

  /// 出発の何分前に知らせるかです。
  var minutes: Int {
    switch self {
    case .fiveMinutes:
      return 5
    case .tenMinutes:
      return 10
    case .fifteenMinutes:
      return 15
    }
  }
}

/// ショートカットで経路が指定されなかったときの決め方です。
enum ShortcutRouteResolver {
  /// 経路の指定があればそれを、なければアプリと同じ判断で決めます。
  ///
  /// 自分で選んだ経路があればそれを、なければ時間帯と前回の行き先から決めます。
  @available(iOS 16.0, *)
  static func route(for option: BusRouteOption?, at now: Date) -> BusRoute {
    if let option {
      return option.route
    }
    return automaticRoute(at: now)
  }

  /// アプリと同じ判断で決めた経路です。
  static func automaticRoute(at now: Date) -> BusRoute {
    SharedAppData.manualRoute ?? BusSchedule.recommendedRoute(
      at: now,
      location: nil,
      preferredPartner: SharedAppData.preferredPartnerStop
    )
  }
}
