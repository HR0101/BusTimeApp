import ActivityKit
import WidgetKit
import SwiftUI

struct BusTimeWidgetLiveActivity: Widget {
    /// 残り時間は通常の情報色です。表示場所で警告の意味を変えません。
    private let countdownColor = Color(red: 0.15, green: 0.50, blue: 0.75)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusActivityAttributes.self) { context in
            HStack(alignment: .center) {
                // 左側: ルート情報と時刻
                VStack(alignment: .leading, spacing: 6) {
                    Text(context.attributes.routeName)
                        .font(.caption.bold())
                        .foregroundColor(Color.gray)
                        .lineLimit(1)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(context.attributes.busDepartureTime)
                            .font(.title2.bold())
                            .foregroundColor(Color(red: 0.20, green: 0.25, blue: 0.30)) // columbusText
                        
                        Image(systemName: "arrow.right")
                            .font(.subheadline.bold())
                            .foregroundColor(Color.gray)
                        
                        Text(context.attributes.busArrivalTime)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(Color.gray)
                    }
                }
                
                Spacer(minLength: 10)
                
                // 右側: 出発までの時間を、秒を含まない時間・分表記で表示
                VStack(alignment: .trailing, spacing: 0) {
                    if context.showsDeparted {
                        Text(L10n.Remaining.departed)
                            .font(.headline.bold())
                            .foregroundColor(Color.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    } else {
                        Text(L10n.Widget.untilDeparture)
                            .font(.caption2.bold())
                            .foregroundColor(Color.gray)
                        
                        RemainingDepartureTimeText(
                            departureDate: context.attributes.departureDate
                        )
                            .font(.headline.bold())
                            .foregroundColor(countdownColor)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .activityBackgroundTint(Color.white.opacity(0.8))
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.busDepartureTime, systemImage: "bus.fill")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.showsDeparted {
                        RemainingDepartureTimeText(
                            departureDate: context.attributes.departureDate
                        )
                            .font(.title2.bold())
                            .foregroundColor(countdownColor)
                    } else {
                        Text(L10n.Widget.departedShort)
                            .foregroundColor(.gray)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.routeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Image(systemName: "bus.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                if !context.showsDeparted {
                    RemainingDepartureTimeText(
                        departureDate: context.attributes.departureDate
                    )
                        .foregroundColor(countdownColor)
                        .bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text(verbatim: "--")
                }
            } minimal: {
                Image(systemName: "bus.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}

private extension ActivityViewContext where Attributes == BusActivityAttributes {
    /// 残り時間の代わりに「出発済み」を出すかどうかです。
    var showsDeparted: Bool {
        let hasPassedStaleDate: Bool
        if #available(iOS 16.2, *) {
            hasPassedStaleDate = isStale
        } else {
            hasPassedStaleDate = false
        }
        return attributes.showsDeparted(state: state, isStale: hasPassedStaleDate, now: .now)
    }
}

/// 出発までの残り時間です。
///
/// Live Activityは一度描いた内容を保存して表示するため、`TimelineView`では描き直されません。
/// アプリが停止していても減っていくよう、システムが時刻に合わせて数え進める表示を使います。
private struct RemainingDepartureTimeText: View {
    let departureDate: Date

    /// 数え始める時刻です。描いた時点から出発時刻までを数えます。
    private var countdownStart: Date {
        min(.now, departureDate)
    }

    var body: some View {
        if #available(iOS 18.0, *) {
            // 秒は出さず、時間・分の単位で減っていく表示にします。
            Text(
                .currentDate,
                format: .timer(
                    countingDownIn: countdownStart..<departureDate,
                    showsHours: true,
                    maxFieldCount: 2,
                    maxPrecision: .seconds(60)
                )
            )
        } else {
            // iOS 18より前には分単位で数え進める表示がないため、秒を含むタイマーで代替します。
            // 止まったままの表示より、減っていく表示を優先します。
            Text(
                timerInterval: countdownStart...departureDate,
                countsDown: true,
                showsHours: true
            )
            .monospacedDigit()
        }
    }
}
