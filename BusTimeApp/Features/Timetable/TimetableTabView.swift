import SwiftUI

/// 時刻表の列幅です。見出しと各行で数字の位置を揃えるために共有します。
private enum TimetableColumn {
  /// 検索条件に合う便を示す縦棒の幅です。
  static let marker: CGFloat = 3
  /// 出発時刻の列幅です。
  static let departure: CGFloat = 62
  /// 到着時刻の列幅です。
  static let arrival: CGFloat = 54
  /// 列同士の間隔です。
  static let spacing: CGFloat = 10
  /// 行の左右の余白です。
  static let horizontalPadding: CGFloat = 16
}

/// 選択中の経路の全便を一覧するタブです。
///
/// 駅の発車標のように、出発時刻を等幅の数字で縦に並べ、
/// 検索結果に含まれる便だけを縦棒で示します。
struct TimetableTabView: View {
  @Environment(\.sky) private var sky
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  @ObservedObject var viewModel: HomeViewModel
  let scheduledBusIDs: Set<String>
  let onSelectBus: (Bus) -> Void

  private var horizontalPadding: CGFloat {
    dynamicTypeSize.isAccessibilitySize
      ? SkyMetrics.compactScreenPadding
      : SkyMetrics.screenPadding
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: SkyMetrics.sectionSpacing) {
        header

        if let holidayMessage = viewModel.holidayMessage {
          NoticeCard(
            title: "本日の運行",
            message: holidayMessage,
            systemImage: "calendar.badge.exclamationmark",
            isWarning: true
          )
        } else if viewModel.currentFullTimetable.isEmpty {
          NoticeCard(
            title: "時刻表がありません",
            message: "ホームタブで出発地と目的地を選び直してください",
            systemImage: "bus",
            isWarning: false
          )
        } else {
          timetableList
        }
      }
      .padding(.horizontal, horizontalPadding)
      .padding(.top, 10)
      .padding(.bottom, 28)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      SkySectionLabel(text: "時刻表")

      DynamicTypeStack(verticalAlignment: .firstTextBaseline, spacing: 10) {
        Text(viewModel.selectedRoute.rawValue)
          .dynamicFont(size: 19, relativeTo: .title3, weight: .bold, design: .rounded)
          .foregroundStyle(sky.ink)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text("\(viewModel.currentFullTimetable.count)便")
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .bold, design: .rounded)
          .monospacedDigit()
          .foregroundStyle(sky.accent)
      }

      SkyNoticeRow(
        message: "経路を変えるときは、ホームタブで出発地と目的地を選んでください",
        systemImage: "arrow.left.arrow.right"
      )
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }

  private var timetableList: some View {
    VStack(spacing: 0) {
      // 文字を大きくすると行が縦積みになるため、そのときは列見出しを出しません。
      if !dynamicTypeSize.isAccessibilitySize {
        columnHeader
        SkyDivider()
      }

      ForEach(Array(viewModel.currentFullTimetable.enumerated()), id: \.element.id) { index, bus in
        TimetableRow(
          bus: bus,
          isRecommended: viewModel.searchResults.contains { $0.id == bus.id },
          isNotificationScheduled: scheduledBusIDs.contains(bus.id),
          action: { onSelectBus(bus) }
        )

        if index < viewModel.currentFullTimetable.count - 1 {
          SkyDivider()
        }
      }
    }
    .skyCard(padding: 0)
  }

  /// 各行と同じ列幅で見出しを並べ、時刻の桁が縦に揃って見えるようにします。
  private var columnHeader: some View {
    HStack(spacing: TimetableColumn.spacing) {
      Color.clear
        .frame(width: TimetableColumn.marker, height: 1)
      Text("出発")
        .frame(width: TimetableColumn.departure, alignment: .leading)
      Text("到着")
        .frame(width: TimetableColumn.arrival, alignment: .leading)
      Spacer(minLength: 0)
      Text("通知")
        .frame(width: SkyMetrics.minimumTapSize)
    }
    .dynamicFont(size: 11, relativeTo: .caption2, weight: .bold)
    .foregroundStyle(sky.inkSecondary)
    .padding(.horizontal, TimetableColumn.horizontalPadding)
    .padding(.vertical, 12)
    .accessibilityHidden(true)
  }
}

/// 時刻表の1便を表す行です。
struct TimetableRow: View {
  @Environment(\.sky) private var sky
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let bus: Bus
  /// 現在の検索条件に合致している便かどうかです。
  let isRecommended: Bool
  let isNotificationScheduled: Bool
  let action: () -> Void

  /// 縦棒の高さです。
  private let markerHeight: CGFloat = 22

  var body: some View {
    Button(action: action) {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          stackedLayout
        } else {
          rowLayout
        }
      }
      .padding(.horizontal, TimetableColumn.horizontalPadding)
      .padding(.vertical, 11)
      .background(isRecommended ? sky.accentSoft : Color.clear)
    }
    .buttonStyle(SkyPressStyle())
    .accessibilityLabel(accessibilityText)
    .accessibilityHint("出発前に通知する方法を選びます")
  }

  private var rowLayout: some View {
    HStack(spacing: TimetableColumn.spacing) {
      marker

      Text(bus.departure)
        .dynamicFont(size: 18, relativeTo: .body, weight: .bold, design: .rounded)
        .monospacedDigit()
        .foregroundStyle(sky.ink)
        .frame(width: TimetableColumn.departure, alignment: .leading)

      Text(bus.arrival)
        .dynamicFont(size: 15, relativeTo: .subheadline, weight: .medium, design: .rounded)
        .monospacedDigit()
        .foregroundStyle(sky.inkSecondary)
        .frame(width: TimetableColumn.arrival, alignment: .leading)

      if let note = bus.note {
        Text(note)
          .dynamicFont(size: 10, relativeTo: .caption2, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }

      Spacer(minLength: 0)

      notificationIcon
    }
  }

  private var stackedLayout: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .lastTextBaseline, spacing: 8) {
        marker
        Text(bus.departure)
          .font(.headline.weight(.bold))
          .monospacedDigit()
          .foregroundStyle(sky.ink)
        Image(systemName: "arrow.right")
          .font(.caption2.weight(.bold))
          .foregroundStyle(sky.inkFaint)
        Text(bus.arrival)
          .font(.subheadline.weight(.semibold))
          .monospacedDigit()
          .foregroundStyle(sky.inkSecondary)
      }

      if let note = bus.note {
        Text(note)
          .font(.caption2)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      notificationIcon
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  @ViewBuilder
  private var marker: some View {
    if isRecommended {
      Capsule()
        .fill(sky.accent)
        .frame(width: TimetableColumn.marker, height: markerHeight)
        .accessibilityHidden(true)
    } else {
      Color.clear
        .frame(width: TimetableColumn.marker, height: markerHeight)
        .accessibilityHidden(true)
    }
  }

  private var notificationIcon: some View {
    Image(systemName: isNotificationScheduled ? "bell.fill" : "bell")
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(isNotificationScheduled ? sky.accent : sky.inkSecondary)
      .frame(width: SkyMetrics.minimumTapSize, height: SkyMetrics.minimumTapSize)
  }

  private var accessibilityText: String {
    var text = "\(bus.departure)発、\(bus.arrival)着"
    if let note = bus.note {
      text += "、\(note)"
    }
    if isRecommended {
      text += "、検索条件に合う便"
    }
    if isNotificationScheduled {
      text += "、通知設定済み"
    }
    return text
  }
}
