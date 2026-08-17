import SwiftUI

// MARK: - ヘッダー

/// ホーム画面上部の、アプリ名と各種操作をまとめた行です。
struct HomeHeaderBar: View {
  @Environment(\.sky) private var sky

  let hasScheduledNotification: Bool
  let notificationAction: () -> Void
  let settingsAction: () -> Void
  let helpAction: () -> Void

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        brand
        Spacer(minLength: 8)
        actions
      }

      VStack(alignment: .leading, spacing: 12) {
        brand
        actions
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
  }

  private var brand: some View {
    DynamicTypeStack(spacing: 10) {
      Image(systemName: "bus.fill")
        .dynamicFont(size: 17, relativeTo: .headline, weight: .bold)
        .foregroundStyle(sky.accent)

      Text(L10n.Home.brandName)
        .dynamicFont(size: 16, relativeTo: .headline, weight: .bold, design: .rounded)
        .foregroundStyle(sky.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private var actions: some View {
    HStack(spacing: 8) {
      SkyIconButton(
        systemImage: hasScheduledNotification ? "bell.badge.fill" : "bell",
        accessibilityLabel: L10n.Home.notificationsButton,
        isHighlighted: hasScheduledNotification,
        action: notificationAction
      )
      SkyIconButton(
        systemImage: "gearshape",
        accessibilityLabel: L10n.Home.settingsButton,
        action: settingsAction
      )
      SkyIconButton(
        systemImage: "questionmark",
        accessibilityLabel: L10n.Home.tutorialButton,
        action: helpAction
      )
    }
  }
}

// MARK: - 次のバス

/// 次に乗れる便を、残り時間を主役にして表示するカードです。
struct NextDepartureHero: View {
  @Environment(\.sky) private var sky

  let bus: Bus
  /// 残り時間です。`HomeViewModel` の規約に従い、-1は出発済み、0はまもなく出発を表します。
  let remainingMinutes: Int?
  let isNotificationScheduled: Bool
  /// このカードの見出しです。見ている運行日によって変わります。
  let sectionTitle: String
  /// 今まさに乗れる便を見ているかどうかです。
  /// そうでないときは残り時間の代わりに発車時刻を主役にします。
  let isRealtime: Bool
  /// 通知を設定できない理由です。設定できるときはnilです。
  let notificationUnavailableReason: String?
  let notifyAction: () -> Void

  /// 残り時間の数字の基準サイズです。
  private let countdownNumberSize: CGFloat = 76
  /// 残り時間の単位の基準サイズです。
  private let countdownUnitSize: CGFloat = 25
  /// 1時間を分に直した値です。
  private let minutesPerHour = 60

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      SkySectionLabel(text: sectionTitle)

      countdown
        .accessibilityElement(children: .combine)
        .accessibilityLabel(countdownAccessibilityText)

      SkyDivider()

      VStack(alignment: .leading, spacing: 6) {
        timeRow
        // 停留所名は固有名詞なので、そのまま並べます。
        Text(verbatim: "\(bus.originName) → \(bus.destinationName)")
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)

        if let note = bus.note {
          Text(note)
            .dynamicFont(size: 11, relativeTo: .caption2, weight: .bold, design: .rounded)
            .foregroundStyle(sky.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(sky.accentSoft))
            .padding(.top, 2)
        }
      }

      notifyButton
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: 残り時間の表示

  @ViewBuilder
  private var countdown: some View {
    if !isRealtime {
      // 先の日や運休日は残り時間に意味がないため、発車時刻そのものを主役にします。
      HStack(alignment: .lastTextBaseline, spacing: 4) {
        countdownText(bus.departure)
        countdownUnit(L10n.Result.departureSuffix)
      }
    } else {
      remainingTimeCountdown
    }
  }

  @ViewBuilder
  private var remainingTimeCountdown: some View {
    switch remainingMinutes {
    case .none:
      countdownPhrase(L10n.Result.calculating)
    case .some(HomeViewModel.departedMinutesValue):
      countdownPhrase(L10n.Countdown.departed)
    case .some(HomeViewModel.imminentMinutesValue):
      countdownPhrase(L10n.Countdown.leavingSoon)
    case let .some(minutes) where minutes < minutesPerHour:
      HStack(alignment: .lastTextBaseline, spacing: 4) {
        countdownPrefix
        countdownNumber(minutes)
        countdownUnit(L10n.Result.unitMinute)
      }
    case let .some(minutes):
      HStack(alignment: .lastTextBaseline, spacing: 4) {
        countdownPrefix
        countdownNumber(minutes / minutesPerHour)
        countdownUnit(L10n.Result.unitHour)
        if minutes % minutesPerHour > 0 {
          countdownNumber(minutes % minutesPerHour)
          countdownUnit(L10n.Result.unitMinute)
        }
      }
    }
  }

  private var countdownPrefix: some View {
    Text(L10n.Result.remainingPrefix)
      .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
      .foregroundStyle(sky.inkSecondary)
  }

  private func countdownNumber(_ value: Int) -> some View {
    countdownText("\(value)")
  }

  /// 残り時間の数字や発車時刻を、同じ大きさで表します。
  private func countdownText(_ text: String) -> some View {
    // 数字や時刻そのものなので、翻訳の対象にはしません。
    Text(verbatim: text)
      .dynamicFont(
        size: countdownNumberSize,
        relativeTo: .largeTitle,
        weight: .bold,
        design: .rounded
      )
      .monospacedDigit()
      .foregroundStyle(sky.ink)
      .lineLimit(1)
      .minimumScaleFactor(0.5)
  }

  private func countdownUnit(_ text: String) -> some View {
    Text(text)
      .dynamicFont(
        size: countdownUnitSize,
        relativeTo: .title2,
        weight: .bold,
        design: .rounded
      )
      .foregroundStyle(sky.ink)
  }

  /// 数字を伴わない状態を、大きすぎない文字で表します。
  private func countdownPhrase(_ text: String) -> some View {
    Text(text)
      .dynamicFont(size: 34, relativeTo: .largeTitle, weight: .bold, design: .rounded)
      .foregroundStyle(sky.ink)
      .lineLimit(1)
      .minimumScaleFactor(0.6)
  }

  private var countdownAccessibilityText: String {
    if !isRealtime {
      return L10n.Result.a11yScheduledDeparture(sectionTitle, bus.departure)
    }

    switch remainingMinutes {
    case .none:
      return L10n.Result.a11yCalculating
    case .some(HomeViewModel.departedMinutesValue):
      return L10n.Result.a11yDeparted
    case .some(HomeViewModel.imminentMinutesValue):
      return L10n.Result.a11yLeavingSoon
    case let .some(minutes) where minutes < minutesPerHour:
      return L10n.Result.a11yMinutes(minutes)
    case let .some(minutes):
      let hours = minutes / minutesPerHour
      let remainder = minutes % minutesPerHour
      return remainder == 0
        ? L10n.Result.a11yHours(hours)
        : L10n.Result.a11yHoursMinutes(hours, remainder)
    }
  }

  // MARK: 時刻と操作

  private var timeRow: some View {
    DynamicTypeStack(verticalAlignment: .lastTextBaseline, spacing: 8) {
      Text(bus.departure)
        .dynamicFont(size: 27, relativeTo: .title, weight: .bold, design: .rounded)
        .monospacedDigit()
        .foregroundStyle(sky.ink)
        .minimumScaleFactor(0.7)
      Text(L10n.Result.departureSuffix)
        .dynamicFont(size: 12, relativeTo: .caption, weight: .bold)
        .foregroundStyle(sky.inkSecondary)

      Image(systemName: "arrow.right")
        .font(.caption.weight(.bold))
        .foregroundStyle(sky.inkFaint)

      Text(bus.arrival)
        .dynamicFont(size: 21, relativeTo: .title3, weight: .bold, design: .rounded)
        .monospacedDigit()
        .foregroundStyle(sky.inkSecondary)
        .minimumScaleFactor(0.7)
      Text(L10n.Result.arrivalSuffix)
        .dynamicFont(size: 12, relativeTo: .caption, weight: .bold)
        .foregroundStyle(sky.inkSecondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(L10n.Result.a11yTimeRow(bus.departure, bus.arrival))
  }

  @ViewBuilder
  private var notifyButton: some View {
    if let notificationUnavailableReason {
      // 走らない日や先の日に通知を入れると、意図しない日に鳴ってしまいます。
      SkyNoticeRow(message: notificationUnavailableReason)
    } else if isNotificationScheduled {
      SkySecondaryButton(
        title: L10n.Result.notifyScheduled,
        systemImage: "bell.fill",
        action: notifyAction
      )
      .accessibilityHint(L10n.Result.notifyScheduledHint)
    } else {
      SkyPrimaryButton(
        title: L10n.Result.notify,
        systemImage: "bell",
        action: notifyAction
      )
      .accessibilityHint(L10n.Result.notifyHint)
    }
  }
}

// MARK: - 続く便

/// 次の便に続く候補を1行で表す行です。
struct UpcomingDepartureRow: View {
  @Environment(\.sky) private var sky

  let bus: Bus
  let countdown: String?
  let isNotificationScheduled: Bool
  /// この便に通知を設定できるかどうかです。設定できないときは行を押せなくします。
  let canSchedule: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      DynamicTypeStack(verticalAlignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(bus.departure)
              .dynamicFont(size: 20, relativeTo: .title3, weight: .bold, design: .rounded)
              .monospacedDigit()
              .foregroundStyle(sky.ink)
            Image(systemName: "arrow.right")
              .font(.caption2.weight(.bold))
              .foregroundStyle(sky.inkFaint)
            Text(bus.arrival)
              .dynamicFont(size: 16, relativeTo: .body, weight: .semibold, design: .rounded)
              .monospacedDigit()
              .foregroundStyle(sky.inkSecondary)
          }

          if let note = bus.note {
            Text(note)
              .dynamicFont(size: 11, relativeTo: .caption2, weight: .medium)
              .foregroundStyle(sky.inkSecondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if let countdown {
          Text(countdown)
            .dynamicFont(size: 12, relativeTo: .caption, weight: .bold, design: .rounded)
            .foregroundStyle(sky.inkSecondary)
        }

        if canSchedule {
          Image(systemName: isNotificationScheduled ? "bell.fill" : "bell")
            .dynamicFont(size: 14, relativeTo: .body, weight: .semibold)
            .foregroundStyle(isNotificationScheduled ? sky.accent : sky.inkSecondary)
            .scaledTapTarget()
        }
      }
      .padding(.vertical, 2)
    }
    .buttonStyle(SkyPressStyle())
    .disabled(!canSchedule)
    .accessibilityLabel(
      L10n.Result.rowLabel(bus.departure, bus.arrival)
        + (isNotificationScheduled ? L10n.Result.rowLabelScheduled : "")
    )
    .accessibilityHint(
      canSchedule
        ? L10n.Result.notifyHint
        : L10n.Result.rowHintCannotNotify
    )
  }
}

// MARK: - お知らせ

/// 運休や検索結果なしなど、便を表示できない場合のカードです。
struct NoticeCard: View {
  @Environment(\.sky) private var sky

  let title: String
  let message: String
  let systemImage: String
  let isWarning: Bool

  var body: some View {
    DynamicTypeStack(verticalAlignment: .top, spacing: 14) {
      Image(systemName: systemImage)
        .dynamicFont(size: 24, relativeTo: .title3, weight: .semibold)
        .foregroundStyle(isWarning ? sky.warning : sky.inkSecondary)

      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .dynamicFont(size: 17, relativeTo: .headline, weight: .bold, design: .rounded)
          .foregroundStyle(sky.ink)
          .fixedSize(horizontal: false, vertical: true)
        Text(message)
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard(padding: 20)
    .accessibilityElement(children: .combine)
  }
}
