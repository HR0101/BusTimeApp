import SwiftUI

struct NotificationOptionsView: View {
  let bus: Bus
  let routeName: String
  let scheduledNotification: ScheduledBusNotification?
  let permissionStatus: BusNotificationPermission
  let liveActivityBusID: String?
  let isLiveActivityEnabled: Bool
  let isLiveActivityAvailable: Bool
  let onOpenNotificationSettings: () -> Void
  let onSchedule: (Int) -> Void
  let onStartLiveActivity: () -> Void
  let onEndLiveActivity: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.sky) private var sky

  /// 選べる通知タイミングです。
  private let reminderMinutes = [5, 10, 15]

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: SkyMetrics.sectionSpacing) {
          busSummary
          localNotificationSection
          liveActivitySection
        }
        .padding(.horizontal, SkyMetrics.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 30)
      }
      .background(SkyBackground())
      .navigationTitle("この便をお知らせ")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("閉じる") { dismiss() }
            .fontWeight(.bold)
            .foregroundStyle(sky.accent)
        }
      }
      .preferredColorScheme(sky.isNight ? .dark : .light)
    }
  }

  // MARK: - 対象の便

  private var busSummary: some View {
    VStack(alignment: .leading, spacing: 10) {
      SkySectionLabel(text: "対象のバス")

      HStack(alignment: .lastTextBaseline, spacing: 6) {
        Text(bus.departure)
          .dynamicFont(size: 30, relativeTo: .title, weight: .bold, design: .rounded)
          .monospacedDigit()
          .foregroundStyle(sky.ink)
        Text("発")
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .bold)
          .foregroundStyle(sky.inkSecondary)
      }

      Text(bus.stopSummary)
        .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
        .foregroundStyle(sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)

      if !bus.intermediateStops.isEmpty {
        SkyNoticeRow(
          message: "途中停車：\(bus.intermediateStops.map(\.name).joined(separator: "、"))",
          systemImage: "mappin.and.ellipse"
        )
      }

      Text(routeName)
        .dynamicFont(size: 11, relativeTo: .caption2, weight: .medium)
        .foregroundStyle(sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }

  // MARK: - 通常の通知

  private var localNotificationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: "通常の通知")

      if let scheduledNotification {
        Text("現在の設定：\(scheduledNotification.notificationDescription)")
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .bold)
          .foregroundStyle(sky.accent)
          .fixedSize(horizontal: false, vertical: true)
        Text("同じ便の通知は1件だけ設定できます。選び直すと通知時刻が変更されます。")
          .dynamicFont(size: 11, relativeTo: .caption2, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      ForEach(reminderMinutes, id: \.self) { minutes in
        reminderButton(minutes: minutes)
      }

      if permissionStatus == .denied {
        VStack(alignment: .leading, spacing: 6) {
          SkyNoticeRow(
            message: "通知が許可されていません。",
            systemImage: "exclamationmark.circle.fill",
            isWarning: true
          )
          Button("iPhoneの設定で通知を許可する", action: onOpenNotificationSettings)
            .dynamicFont(size: 13, relativeTo: .footnote, weight: .bold, design: .rounded)
            .foregroundStyle(sky.accent)
            .frame(minHeight: SkyMetrics.minimumTapSize, alignment: .leading)
        }
      }

      SkyNoticeRow(
        message: "この通知は時刻表の予定時刻を基準にしています。遅延や運休は自動では反映されません。"
      )
    }
  }

  private func reminderButton(minutes: Int) -> some View {
    let schedule = BusNotificationTimeCalculator.notificationDate(
      for: bus.departure,
      minutesBefore: minutes,
      from: Date()
    )

    return Button {
      onSchedule(minutes)
    } label: {
      DynamicTypeStack(spacing: 12) {
        Image(systemName: "bell.badge.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(sky.accent)
          .frame(width: 26)

        VStack(alignment: .leading, spacing: 3) {
          Text("\(minutes)分前に通知")
            .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
            .foregroundStyle(sky.ink)
          Text(
            schedule.map {
              "通知時刻：\(BusNotificationTimeCalculator.displayString($0.notificationDate))"
            } ?? "この便では設定できません"
          )
          .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(.caption.weight(.bold))
          .foregroundStyle(sky.inkSecondary)
      }
      .skyCard(radius: 16, padding: 14)
    }
    .buttonStyle(SkyPressStyle())
    .disabled(schedule == nil)
    .opacity(schedule == nil ? 0.48 : 1)
  }

  // MARK: - Live Activity

  private var liveActivitySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: "Live Activity")

      Text("ロック画面やDynamic Islandで、出発までの時間を確認できます。")
        .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
        .foregroundStyle(sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)

      liveActivityStatusText
      liveActivityControl
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }

  @ViewBuilder
  private var liveActivityStatusText: some View {
    if !isLiveActivityAvailable {
      SkyNoticeRow(
        message: "この端末では利用できないか、iPhoneの設定でLive Activityがオフになっています。",
        systemImage: "exclamationmark.circle.fill",
        isWarning: true
      )
    } else if !isLiveActivityEnabled {
      SkyNoticeRow(message: "アプリの設定で自動表示がオフです。必要なときは下のボタンから開始できます。")
    } else if let scheduledNotification {
      Text("設定済みの\(scheduledNotification.minutesBefore)分前通知も、そのまま届きます。")
        .dynamicFont(size: 12, relativeTo: .caption, weight: .bold)
        .foregroundStyle(sky.accent)
        .fixedSize(horizontal: false, vertical: true)
    } else {
      Text("通常の通知を設定すると、Live Activityも自動で開始します。下のボタンから始める場合は5分前通知も一緒に設定します。")
        .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
        .foregroundStyle(sky.accent)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private var liveActivityControl: some View {
    if liveActivityBusID == bus.id {
      Button(action: onEndLiveActivity) {
        Label("この便の表示を終了", systemImage: "stop.circle.fill")
          .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
          .foregroundStyle(sky.warning)
          .frame(maxWidth: .infinity, minHeight: 50)
          .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(sky.warning.opacity(0.5), lineWidth: SkyMetrics.borderWidth)
          )
      }
      .buttonStyle(SkyPressStyle())
    } else if liveActivityBusID == nil {
      Button(action: onStartLiveActivity) {
        Label(
          scheduledNotification == nil
            ? "5分前通知とLive Activityを開始"
            : "Live Activityを開始（通知は継続）",
          systemImage: "lock.rectangle.on.rectangle"
        )
        .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(sky.accent)
        )
      }
      .buttonStyle(SkyPressStyle())
      .disabled(!isLiveActivityAvailable)
      .opacity(isLiveActivityAvailable ? 1 : 0.48)
    } else {
      SkyNoticeRow(message: "別の便をLive Activityで表示中です。先に管理画面から終了してください。")
    }
  }
}
