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

/// Live Activityで表示する残り時間を、秒を含まない日本語表記へ変換します。
public enum BusRemainingTimeFormatter {
    public static func string(until departureDate: Date, now: Date) -> String {
        let remainingSeconds = departureDate.timeIntervalSince(now)

        guard remainingSeconds > 0 else {
            return "出発済み"
        }

        guard remainingSeconds >= 60 else {
            return "1分未満"
        }

        let totalMinutes = Int(remainingSeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        guard hours > 0 else {
            return "\(minutes)分"
        }

        return minutes == 0
            ? "\(hours)時間"
            : "\(hours)時間\(minutes)分"
    }
}
