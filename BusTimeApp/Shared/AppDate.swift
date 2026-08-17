import Foundation

/// アプリ内の「現在時刻」を供給します。
///
/// 通常は端末の現在時刻を返します。DebugビルドのUIテストだけは起動引数
/// `-UITestNow <UNIX秒>` で固定でき、時刻に連動する背景や経路を再現可能にします。
enum AppDate {
    static func now() -> Date {
#if DEBUG
        let value = UserDefaults.standard.object(forKey: "UITestNow")
        let interval: TimeInterval? = switch value {
        case let number as NSNumber:
            number.doubleValue
        case let string as String:
            TimeInterval(string)
        default:
            nil
        }
        if let interval {
            return Date(timeIntervalSince1970: interval)
        }
#endif
        return Date()
    }
}
