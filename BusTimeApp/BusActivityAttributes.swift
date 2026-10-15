import Foundation
import ActivityKit

public struct BusActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
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

    /// Live Activityで「出発済み」と表示するかどうかです。
    ///
    /// アプリが停止しているあいだは「出発済み」への更新を送れません。
    /// そのため、出発時刻を過ぎて内容が古くなったことも出発済みとして扱います。
    /// - Parameters:
    ///   - state: アプリから最後に届いた表示内容です。
    ///   - isStale: 内容の期限（出発時刻）をシステムが過ぎたと判断したかどうかです。
    ///   - now: 表示を作る時刻です。
    public func showsDeparted(state: ContentState, isStale: Bool, now: Date) -> Bool {
        state.isDeparted || isStale || departureDate <= now
    }
}

@available(iOS 16.2, *)
extension BusActivityAttributes {
    /// Live Activityへ渡す表示内容を作ります。
    ///
    /// 開始時も更新時も、出発時刻を「内容が古くなる時刻」として渡します。
    /// 期限を外すと、アプリが停止したまま出発時刻を過ぎたときに
    /// システムが描き直さず、出発前の表示が残り続けるためです。
    public func content(remainingMinutes: Int, isDeparted: Bool) -> ActivityContent<ContentState> {
        ActivityContent(
            state: ContentState(remainingMinutes: remainingMinutes, isDeparted: isDeparted),
            staleDate: departureDate
        )
    }
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
