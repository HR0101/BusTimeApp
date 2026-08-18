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
      .navigationTitle(L10n.Options.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(L10n.Common.close) { dismiss() }
            .fontWeight(.bold)
            .foregroundStyle(sky.accentReadable)
        }
      }
    }
  }

  // MARK: - 対象の便

  private var busSummary: some View {
    VStack(alignment: .leading, spacing: 10) {
      SkySectionLabel(text: L10n.Options.targetSection)

      HStack(alignment: .lastTextBaseline, spacing: 6) {
        Text(bus.departure)
          .dynamicFont(size: 30, relativeTo: .title, weight: .bold, design: .rounded)
          .monospacedDigit()
          .foregroundStyle(sky.ink)
        Text(L10n.Result.departureSuffix)
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .bold)
          .foregroundStyle(sky.inkSecondary)
      }

      Text(bus.stopSummary)
        .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
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
      SkySectionLabel(text: L10n.Options.standardSection)

      if let scheduledNotification {
        Text(L10n.Options.currentSetting(scheduledNotification.notificationDescription))
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .bold)
          .foregroundStyle(sky.accentReadable)
          .fixedSize(horizontal: false, vertical: true)
        Text(L10n.Options.onlyOnePerBus)
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
            message: L10n.Options.notPermitted,
            systemImage: "exclamationmark.circle.fill",
            isWarning: true
          )
          Button(L10n.Options.allowInSettings, action: onOpenNotificationSettings)
            .dynamicFont(size: 13, relativeTo: .footnote, weight: .bold, design: .rounded)
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
      from: AppDate.now()
    )

    return Button {
      onSchedule(minutes)
    } label: {
      DynamicTypeStack(spacing: 12) {
        Image(systemName: "bell.badge.fill")
          .dynamicFont(size: 16, relativeTo: .body, weight: .semibold)
          .foregroundStyle(sky.accentReadable)

        VStack(alignment: .leading, spacing: 3) {
          Text(L10n.Options.minutesBefore(minutes))
            .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
            .foregroundStyle(sky.ink)
          Text(
            schedule.map {
              L10n.Options.notificationTime(
              BusNotificationTimeCalculator.displayString($0.notificationDate)
            )
            } ?? L10n.Options.notAvailable
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

      Text(L10n.Options.liveActivityDescription)
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
        message: L10n.Options.liveActivityUnavailable,
        systemImage: "exclamationmark.circle.fill",
        isWarning: true
      )
    } else if !isLiveActivityEnabled {
      SkyNoticeRow(message: L10n.Options.autoStartOff)
    } else if let scheduledNotification {
      Text(L10n.Options.existingAlertKept(scheduledNotification.minutesBefore))
        .dynamicFont(size: 12, relativeTo: .caption, weight: .bold)
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
        Label(L10n.Options.endThisDisplay, systemImage: "stop.circle.fill")
          .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
          .foregroundStyle(sky.ink)
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
            ? L10n.Options.startWithAlert
            : L10n.Options.startKeepingAlert,
          systemImage: "lock.rectangle.on.rectangle"
        )
        .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
        .foregroundStyle(sky.accentInk)
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
      SkyNoticeRow(message: L10n.Options.otherBusShowing)
    }
  }
}
