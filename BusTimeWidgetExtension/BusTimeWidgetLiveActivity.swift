import ActivityKit
import WidgetKit
import SwiftUI

struct BusTimeWidgetLiveActivity: Widget {
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
                
                // 標準タイマーはアプリが停止中でもシステム側で表示を更新します。
                VStack(alignment: .trailing, spacing: 0) {
                    if context.state.isDeparted {
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
                            departureDate: context.attributes.departureDate,
                            isUrgent: context.isDepartureUrgent
                        )
                            .font(.headline.bold())
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
                    if !context.state.isDeparted {
                        RemainingDepartureTimeText(
                            departureDate: context.attributes.departureDate,
                            isUrgent: context.isDepartureUrgent
                        )
                            .font(.title2.bold())
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
                if !context.state.isDeparted {
                    RemainingDepartureTimeText(
                        departureDate: context.attributes.departureDate,
                        isUrgent: context.isDepartureUrgent
                    )
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
    var isDepartureUrgent: Bool {
        if #available(iOS 16.2, *), isStale {
            return true
        }
        return Date.now >= attributes.urgencyDate
    }
}

private struct RemainingDepartureTimeText: View {
    let departureDate: Date
    let isUrgent: Bool

    var body: some View {
        // TimelineViewはLive Activityの定期再描画を保証しません。
        // 終端で0に止まる標準タイマーを使い、出発後のカウントアップを防ぎます。
        Text(
            timerInterval: min(Date.now, departureDate)...departureDate,
            countsDown: true,
            showsHours: true
        )
        .monospacedDigit()
        .foregroundColor(isUrgent ? .red : Color(red: 0.15, green: 0.50, blue: 0.75))
    }
}
