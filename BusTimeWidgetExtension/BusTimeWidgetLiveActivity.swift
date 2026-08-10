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
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.20, green: 0.25, blue: 0.30)) // columbusText
                        
                        Image(systemName: "arrow.right")
                            .font(.subheadline.bold())
                            .foregroundColor(Color.gray)
                        
                        Text(context.attributes.busArrivalTime)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.gray)
                    }
                }
                
                Spacer(minLength: 10)
                
                // 右側: カウントダウン表示（大きく）
                VStack(alignment: .trailing, spacing: 0) {
                    if context.state.isDeparted {
                        Text("出発済み")
                            .font(.headline.bold())
                            .foregroundColor(Color.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    } else {
                        Text("出発まで")
                            .font(.caption2.bold())
                            .foregroundColor(Color.gray)
                        
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(context.attributes.departureDate, style: .timer)
                                .font(.headline.bold())
                                .foregroundColor(Color(red: 0.15, green: 0.50, blue: 0.75))
                        }
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
                        Text(context.attributes.departureDate, style: .timer)
                            .font(.title2.bold())
                            .foregroundColor(.red)
                    } else {
                        Text("出発済")
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
                    Text(context.attributes.departureDate, style: .timer)
                        .foregroundColor(.red)
                        .bold()
                } else {
                    Text("--")
                }
            } minimal: {
                Image(systemName: "bus.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}
