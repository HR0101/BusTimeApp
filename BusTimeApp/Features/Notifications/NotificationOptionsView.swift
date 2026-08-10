import SwiftUI

struct NotificationOptionsView: View {
    let bus: Bus
    let routeName: String
    let scheduledNotification: ScheduledBusNotification?
    let permissionStatus: BusNotificationPermission
    let liveActivityBusID: String?
    let onOpenNotificationSettings: () -> Void
    let onSchedule: (Int) -> Void
    let onStartLiveActivity: () -> Void
    let onEndLiveActivity: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDesignMode) private var designMode

    private let reminderMinutes = [5, 10, 15]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    busSummary
                    explanation
                    localNotificationSection
                    liveActivitySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .background(NeumorphicBackground())
            .navigationTitle("この便をお知らせ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(Color.neumoAccentDeep)
                }
            }
            .preferredColorScheme(designMode == .claymorphic ? .light : nil)
        }
    }

    private var busSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("対象のバス", systemImage: "bus.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.neumoAccent)
            Text("\(bus.originName) \(bus.departure)発 → \(bus.destinationName)")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.neumoText)
            Text(routeName)
                .font(.caption)
                .foregroundStyle(Color.neumoMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .neumorphicSurface(in: RoundedRectangle(cornerRadius: 22, style: .continuous), depth: 10)
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("お知らせ方法を選んでください")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.neumoText)
            Text("通常の通知は指定した時刻に1回だけ届きます。Live Activityはロック画面やDynamic Islandに出発までの時間を表示します。")
                .font(.subheadline)
                .foregroundStyle(Color.neumoMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var localNotificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("通常の通知", systemImage: "bell.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.neumoText)

            if let scheduledNotification {
                Text("現在の設定：\(scheduledNotification.notificationDescription)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.neumoAccentDeep)
                Text("同じ便の通知は1件だけ設定できます。選び直すと通知時刻が変更されます。")
                    .font(.caption2)
                    .foregroundStyle(Color.neumoMuted)
            }

            ForEach(reminderMinutes, id: \.self) { minutes in
                let schedule = BusNotificationTimeCalculator.notificationDate(
                    for: bus.departure,
                    minutesBefore: minutes,
                    from: Date()
                )
                Button {
                    onSchedule(minutes)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.title3)
                            .foregroundStyle(Color.neumoAccent)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(minutes)分前に通知")
                                .font(.subheadline.weight(.bold))
                            Text(schedule.map { "通知時刻：\(BusNotificationTimeCalculator.displayString($0.notificationDate))" } ?? "この便では設定できません")
                                .font(.caption)
                                .foregroundStyle(Color.neumoMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.neumoMuted)
                    }
                    .foregroundStyle(Color.neumoText)
                    .padding(15)
                    .background(Color.white.opacity(0.76))
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(SoftPressButtonStyle())
                .disabled(schedule == nil)
                .opacity(schedule == nil ? 0.48 : 1)
            }

            if permissionStatus == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Text("通知が許可されていません。")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.neumoWarning)
                    Button("iPhoneの設定で通知を許可する", action: onOpenNotificationSettings)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.neumoAccentDeep)
                }
            }
        }
    }

    private var liveActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Live Activity", systemImage: "lock.rectangle.on.rectangle")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.neumoText)
            Text("ロック画面やDynamic Islandで、出発までの時間を確認できます。")
                .font(.caption)
                .foregroundStyle(Color.neumoMuted)

            if liveActivityBusID == bus.id {
                Button(action: onEndLiveActivity) {
                    Label("この便の表示を終了", systemImage: "stop.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color.neumoWarning)
                        .background(Color.neumoWarning.opacity(0.11))
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(SoftPressButtonStyle())
            } else {
                Button(action: onStartLiveActivity) {
                    Label(
                        liveActivityBusID == nil ? "Live Activityを開始" : "現在の表示を終了して開始",
                        systemImage: "lock.rectangle.on.rectangle"
                    )
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [Color.neumoAccent, Color.neumoAccentDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(SoftPressButtonStyle())
            }
        }
        .padding(16)
        .background(Color.neumoAccent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
