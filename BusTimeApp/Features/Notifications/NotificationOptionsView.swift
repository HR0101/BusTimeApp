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
  /// 通知タイミングの行の角丸半径です。
  private let rowRadius: CGFloat = 16
  /// 通知タイミングの行の内側の余白です。
  private let rowPadding: CGFloat = 16
  /// 押せない部品の中身の濃さです。
  private let disabledContentOpacity: Double = 0.48
  /// 大きなボタンの高さです。
  private let largeButtonHeight: CGFloat = 48

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
        .padding(.bottom, 32)
      }
      .background(SkyBackground())
      .navigationTitle(L10n.Options.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(L10n.Common.close) { dismiss() }
            .fontWeight(.semibold)
            .foregroundStyle(sky.accentReadable)
        }
      }
    }
  }

  // MARK: - 対象の便

  private var busSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      SkySectionLabel(text: L10n.Options.targetSection)

      HStack(alignment: .lastTextBaseline, spacing: 4) {
        Text(bus.departure)
          .dynamicFont(size: 32, relativeTo: .title, weight: .semibold, design: .rounded)
          .monospacedDigit()
          .foregroundStyle(sky.ink)
        Text(L10n.Result.departureSuffix)
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
      }

      Text(bus.stopSummary)
        .dynamicFont(size: 13, relativeTo: .footnote, weight: .regular)
        .foregroundStyle(sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)

      if !bus.intermediateStops.isEmpty {
        SkyNoticeRow(
          message: L10n.Options.intermediateStops(
            bus.intermediateStops.map(\.name).joined(separator: "、")
          ),
          systemImage: "mappin.and.ellipse"
        )
      }

      // 便の停留所の並びと選んでいる経路が同じなら、同じ文を2回並べません。
      // 経由便のように両者が違うときだけ、どの経路の便かを添えます。
      if routeName != bus.stopSummary {
        Text(routeName)
          .dynamicFont(size: 12, relativeTo: .caption, weight: .regular)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }

  // MARK: - 通常の通知

  private var localNotificationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: L10n.Options.standardSection)

      if let scheduledNotification {
        Text(L10n.Options.currentSetting(scheduledNotification.notificationDescription))
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
          .foregroundStyle(sky.accentReadable)
          .fixedSize(horizontal: false, vertical: true)
        Text(L10n.Options.onlyOnePerBus)
          .dynamicFont(size: 12, relativeTo: .caption, weight: .regular)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      ForEach(reminderMinutes, id: \.self) { minutes in
        reminderButton(minutes: minutes)
      }

      if permissionStatus == .denied {
        VStack(alignment: .leading, spacing: 4) {
          SkyNoticeRow(
            message: L10n.Options.notPermitted,
            systemImage: "exclamationmark.circle.fill",
            isWarning: true
          )
          Button(L10n.Options.allowInSettings, action: onOpenNotificationSettings)
            .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium, design: .rounded)
            .foregroundStyle(sky.accentReadable)
            .frame(minHeight: SkyMetrics.minimumTapSize, alignment: .leading)
        }
      }

      SkyNoticeRow(
        message: L10n.Options.timetableCaveat
      )
    }
  }

  private func reminderButton(minutes: Int) -> some View {
    let schedule = BusNotificationTimeCalculator.notificationDate(
      for: bus.departure,
      minutesBefore: minutes,
      from: AppDate.now(),
      serviceDate: bus.scheduledServiceDate
    )

    return Button {
      onSchedule(minutes)
    } label: {
      DynamicTypeStack(spacing: 12) {
        Image(systemName: "bell")
          .dynamicFont(size: 16, relativeTo: .body, weight: .medium)
          .foregroundStyle(sky.inkSecondary)

        VStack(alignment: .leading, spacing: 4) {
          Text(L10n.Options.minutesBefore(minutes))
            .dynamicFont(size: 15, relativeTo: .subheadline, weight: .semibold, design: .rounded)
            .foregroundStyle(sky.ink)
          Text(
            schedule.map {
              L10n.Options.notificationTime(
              BusNotificationTimeCalculator.displayString($0.notificationDate)
            )
            } ?? L10n.Options.notAvailable
          )
          .dynamicFont(size: 12, relativeTo: .caption, weight: .regular)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(.caption.weight(.medium))
          .foregroundStyle(sky.inkSecondary)
      }
      // 設定できない行は中身だけを淡くし、カードの地は残します。
      // 行ごと淡くすると地まで透けて、うしろの風景が文字に重なるためです。
      .opacity(schedule == nil ? disabledContentOpacity : 1)
      .skyCard(radius: rowRadius, padding: rowPadding)
    }
    .buttonStyle(SkyPressStyle())
    .disabled(schedule == nil)
  }

  // MARK: - Live Activity

  private var liveActivitySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: "Live Activity")

      Text(L10n.Options.liveActivityDescription)
        .dynamicFont(size: 13, relativeTo: .footnote, weight: .regular)
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
        message: L10n.Options.liveActivityUnavailable,
        systemImage: "exclamationmark.circle.fill",
        isWarning: true
      )
    } else if !isLiveActivityEnabled {
      SkyNoticeRow(message: L10n.Options.autoStartOff)
    } else if let scheduledNotification {
      Text(L10n.Options.existingAlertKept(scheduledNotification.minutesBefore))
        .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
        .foregroundStyle(sky.accentReadable)
        .fixedSize(horizontal: false, vertical: true)
    } else {
      Text(L10n.Options.autoStartDescription)
        .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
        .foregroundStyle(sky.accentReadable)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private var liveActivityControl: some View {
    if liveActivityBusID == bus.id {
      Button(action: onEndLiveActivity) {
        Label(L10n.Options.endThisDisplay, systemImage: "stop.circle")
          .dynamicFont(size: 15, relativeTo: .subheadline, weight: .semibold, design: .rounded)
          .foregroundStyle(sky.ink)
          .frame(maxWidth: .infinity, minHeight: largeButtonHeight)
          .background(
            RoundedRectangle(cornerRadius: SkyMetrics.innerRadius, style: .continuous)
              .stroke(sky.warning.opacity(0.5), lineWidth: SkyMetrics.borderWidth)
          )
      }
      .buttonStyle(SkyPressStyle())
    } else if liveActivityBusID == nil {
      Button(action: onStartLiveActivity) {
        Label(
          scheduledNotification == nil
            ? L10n.Options.startWithAlert
            : L10n.Options.startKeepingAlert,
          systemImage: "lock.rectangle.on.rectangle"
        )
        .dynamicFont(size: 15, relativeTo: .subheadline, weight: .semibold, design: .rounded)
        .foregroundStyle(sky.accentInk)
        .frame(maxWidth: .infinity, minHeight: largeButtonHeight)
        .background(
          RoundedRectangle(cornerRadius: SkyMetrics.innerRadius, style: .continuous)
            .fill(sky.accent)
        )
      }
      .buttonStyle(SkyPressStyle())
      .disabled(!isLiveActivityAvailable)
      .opacity(isLiveActivityAvailable ? 1 : disabledContentOpacity)
    } else {
      SkyNoticeRow(message: L10n.Options.otherBusShowing)
    }
  }
}
