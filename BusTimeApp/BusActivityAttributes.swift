import Foundation
import ActivityKit

public struct BusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 動的に変化するデータ（残り時間や出発状況）
        public var remainingMinutes: Int
        public var isDeparted: Bool
    }

    // 静的なデータ（対象便と出発日時）
    public var busID: String
    public var busDepartureTime: String
    public var busArrivalTime: String
    public var originName: String
    public var destinationName: String
    public var departureDate: Date
    public var routeName: String
}

/// Live Activityで表示する残り時間を、秒を含まない表記へ変換します。
/// 文言は端末の言語に合わせて切り替わります。
public enum BusRemainingTimeFormatter {
    public static func string(until departureDate: Date, now: Date) -> String {
        let remainingSeconds = departureDate.timeIntervalSince(now)

        guard remainingSeconds > 0 else {
            return L10n.Remaining.departed
        }

        guard remainingSeconds >= 60 else {
            return L10n.Remaining.lessThanMinute
        }

        let totalMinutes = Int(remainingSeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        guard hours > 0 else {
            return L10n.Remaining.minutes(minutes)
        }

        return minutes == 0
            ? L10n.Remaining.hours(hours)
            : L10n.Remaining.hoursMinutes(hours, minutes)
    }
}
