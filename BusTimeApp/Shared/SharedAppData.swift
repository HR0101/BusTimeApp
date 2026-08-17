import Foundation
import WidgetKit

/// アプリとウィジェットのあいだで共有する設定です。
///
/// ウィジェットは別のプロセスなので、アプリの `UserDefaults.standard` は見えません。
/// App Groupの保存領域を経由することで、アプリで選んだ行き先や経路を
/// ウィジェットからも同じように読めるようにします。
enum SharedAppData {
  /// App Groupの識別子です。アプリとウィジェットの両方に同じ値を設定します。
  static let appGroupIdentifier = "group.com.hara.BusTimeApp"

  /// ウィジェットの識別子です。表示を更新したいときにこの名前で指定します。
  static let widgetKind = "NextBusWidget"

  private enum Key {
    /// 前回使った行き先です。駅かヨーカドーのどちらかを入れます。
    static let preferredPartnerStop = "preferredPartnerStop"
    /// 利用者が自分で選んだ経路です。選んでいなければ空にします。
    static let manualRoute = "manualRoute"
  }

  /// 共有の保存領域です。
  ///
  /// App Groupが有効でない場合は、共有領域を作れずnilが返ります。
  /// そのときは通常の保存領域へ書き、アプリ単体としては壊れないようにします。
  static let defaults: UserDefaults = {
    UserDefaults(suiteName: appGroupIdentifier) ?? .standard
  }()

  // MARK: - 前回使った行き先

  /// 前回使った行き先です。まだ選んだことがなければ駅を返します。
  static var preferredPartnerStop: BusStop {
    get {
      guard let rawValue = defaults.string(forKey: Key.preferredPartnerStop),
            let stop = BusStop(rawValue: rawValue),
            stop != BusSchedule.homeStop else {
        return .station
      }
      return stop
    }
    set {
      guard newValue != BusSchedule.homeStop else { return }
      defaults.set(newValue.rawValue, forKey: Key.preferredPartnerStop)
      reloadWidgets()
    }
  }

  // MARK: - 手動で選んだ経路

  /// 利用者が自分で選んだ経路です。選んでいなければnilです。
  ///
  /// ウィジェットは位置情報から経路を決めますが、
  /// 自分で選んだ経路があるときは、アプリと食い違わないようそちらを優先します。
  static var manualRoute: BusRoute? {
    get {
      guard let rawValue = defaults.string(forKey: Key.manualRoute) else { return nil }
      return BusRoute(rawValue: rawValue)
    }
    set {
      if let newValue {
        defaults.set(newValue.rawValue, forKey: Key.manualRoute)
      } else {
        defaults.removeObject(forKey: Key.manualRoute)
      }
      reloadWidgets()
    }
  }

  /// ウィジェットの表示を作り直させます。
  static func reloadWidgets() {
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
  }
}
