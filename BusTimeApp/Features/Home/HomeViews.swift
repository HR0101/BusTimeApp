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
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(sky.accent)

      Text("コロンブスシティ")
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
        accessibilityLabel: "設定した通知を確認",
        isHighlighted: hasScheduledNotification,
        action: notificationAction
      )
      SkyIconButton(
        systemImage: "gearshape",
        accessibilityLabel: "設定を開く",
        action: settingsAction
      )
      SkyIconButton(
        systemImage: "questionmark",
        accessibilityLabel: "使い方を開く",
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
  let notifyAction: () -> Void

  /// 残り時間の数字の基準サイズです。
  private let countdownNumberSize: CGFloat = 76
  /// 残り時間の単位の基準サイズです。
  private let countdownUnitSize: CGFloat = 25
  /// 1時間を分に直した値です。
  private let minutesPerHour = 60

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      SkySectionLabel(text: "つぎのバス")

      countdown
        .accessibilityElement(children: .combine)
        .accessibilityLabel(countdownAccessibilityText)

      SkyDivider()

      VStack(alignment: .leading, spacing: 6) {
        timeRow
        Text("\(bus.originName) → \(bus.destinationName)")
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
    .skyCard(padding: 20)
  }

  // MARK: 残り時間の表示

  @ViewBuilder
  private var countdown: some View {
    switch remainingMinutes {
    case .none:
      countdownPhrase("計算中")
    case .some(HomeViewModel.departedMinutesValue):
      countdownPhrase("出発済み")
    case .some(HomeViewModel.imminentMinutesValue):
      countdownPhrase("まもなく出発")
    case let .some(minutes) where minutes < minutesPerHour:
      HStack(alignment: .lastTextBaseline, spacing: 4) {
        countdownPrefix
        countdownNumber(minutes)
        countdownUnit("分")
      }
    case let .some(minutes):
      HStack(alignment: .lastTextBaseline, spacing: 4) {
        countdownPrefix
        countdownNumber(minutes / minutesPerHour)
        countdownUnit("時間")
        if minutes % minutesPerHour > 0 {
          countdownNumber(minutes % minutesPerHour)
          countdownUnit("分")
        }
      }
    }
  }

  private var countdownPrefix: some View {
    Text("あと")
      .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
      .foregroundStyle(sky.inkSecondary)
  }

  private func countdownNumber(_ value: Int) -> some View {
    Text("\(value)")
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
    switch remainingMinutes {
    case .none:
      return "残り時間を計算中"
    case .some(HomeViewModel.departedMinutesValue):
      return "この便は出発済みです"
    case .some(HomeViewModel.imminentMinutesValue):
      return "まもなく出発します"
    case let .some(minutes) where minutes < minutesPerHour:
      return "あと\(minutes)分で出発します"
    case let .some(minutes):
      let hours = minutes / minutesPerHour
      let remainder = minutes % minutesPerHour
      return remainder == 0
        ? "あと\(hours)時間で出発します"
        : "あと\(hours)時間\(remainder)分で出発します"
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
      Text("発")
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
      Text("着")
        .dynamicFont(size: 12, relativeTo: .caption, weight: .bold)
        .foregroundStyle(sky.inkSecondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(bus.departure)発、\(bus.arrival)着")
  }

  @ViewBuilder
  private var notifyButton: some View {
    if isNotificationScheduled {
      SkySecondaryButton(
        title: "通知を設定済み",
        systemImage: "bell.fill",
        action: notifyAction
      )
      .accessibilityHint("通知の内容を変更できます")
    } else {
      SkyPrimaryButton(
        title: "この便を通知する",
        systemImage: "bell",
        action: notifyAction
      )
      .accessibilityHint("出発前に通知する方法を選びます")
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

        Image(systemName: isNotificationScheduled ? "bell.fill" : "bell")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(isNotificationScheduled ? sky.accent : sky.inkSecondary)
          .frame(width: SkyMetrics.minimumTapSize, height: SkyMetrics.minimumTapSize)
      }
      .skyCard(radius: 16, padding: 12)
    }
    .buttonStyle(SkyPressStyle())
    .accessibilityLabel(
      "\(bus.departure)発 \(bus.arrival)着\(isNotificationScheduled ? "、通知設定済み" : "")"
    )
    .accessibilityHint("出発前に通知する方法を選びます")
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
        .font(.system(size: 24, weight: .semibold))
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
