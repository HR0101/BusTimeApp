import SwiftUI

/// 同じ時台の便をまとめた単位です。
private struct TimetableHour: Identifiable {
  /// 0〜23の時です。深夜便もそのままの値で持ちます。
  let hour: Int
  /// その時台の便を、分の早い順に並べたものです。
  let buses: [Bus]

  var id: Int { hour }

  /// 運行日の並び順です。
  /// 午前4時より前の便は前日の続きなので、一覧では最後に置きます。
  var serviceOrder: Int {
    hour < BusNotificationTimeCalculator.serviceDayBoundaryHour ? hour + 24 : hour
  }
}

/// 選択中の経路の全便を時刻表として一覧するタブです。
///
/// 駅の時刻表と同じく、時を行、分をその中のマスとして並べます。
/// マスをタップすると、その便の通知を設定できます。
struct TimetableTabView: View {
  @Environment(\.sky) private var sky
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  @ObservedObject var viewModel: HomeViewModel
  let scheduledBusIDs: Set<String>
  let onSelectBus: (Bus) -> Void

  /// 分のマス1つの高さです。指で押せる大きさを確保します。
  /// 横幅は画面いっぱいに広げるため、列数から割り出します。
  private let cellSize: CGFloat = 44
  /// 時のラベルの幅です。2桁の時が折り返さない幅を確保します。
  private let hourLabelWidth: CGFloat = 24
  /// 時のラベルと分のマスのあいだの間隔です。
  private let hourLabelSpacing: CGFloat = 6
  /// マス同士の間隔です。
  private let cellSpacing: CGFloat = 2
  /// 行の左右の余白です。
  private let rowPadding: CGFloat = 6
  /// マスの角丸半径です。
  private let cellRadius: CGFloat = 10

  /// 画面左右の余白です。マスの幅を稼ぐため、他の画面より狭くしています。
  private var horizontalPadding: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? SkyMetrics.compactScreenPadding : 14
  }

  /// 1行に並べる分のマスの数です。
  /// 最も便の多い時台が6便なので、折り返しが起きないよう6列に固定します。
  private var columnCount: Int {
    dynamicTypeSize.isAccessibilitySize ? 4 : 6
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: SkyMetrics.sectionSpacing) {
        header

        // 運休日でも時刻表そのものは見たい情報なので、案内を出したうえで表示します。
        if let holidayMessage = viewModel.holidayMessage {
          NoticeCard(
            title: "本日の運行",
            message: holidayMessage,
            systemImage: "calendar.badge.exclamationmark",
            isWarning: true
          )
        }

        if viewModel.currentFullTimetable.isEmpty {
          NoticeCard(
            title: "時刻表がありません",
            message: "ホームタブで出発地と目的地を選び直してください",
            systemImage: "bus",
            isWarning: false
          )
        } else {
          // 通知をまだ使っていない間だけ、操作の仕方を大きく案内します。
          if scheduledBusIDs.isEmpty {
            notificationHint
          }

          timetableGrid
          legend
        }
      }
      .padding(.horizontal, horizontalPadding)
      .padding(.top, 10)
      .padding(.bottom, 28)
    }
  }

  // MARK: - 見出し

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

  /// 通知を一度も設定していない人へ、操作の仕方を伝える案内です。
  /// 1件でも設定されていれば表示しません。
  private var notificationHint: some View {
    DynamicTypeStack(verticalAlignment: .top, spacing: 12) {
      Image(systemName: "bell.badge")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(sky.accent)

      VStack(alignment: .leading, spacing: 5) {
        Text("時刻をタップすると通知できます")
          .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
          .foregroundStyle(sky.ink)
          .fixedSize(horizontal: false, vertical: true)

        Text("選んだ便が出発する前にお知らせします。設定した時刻は色が変わります。")
          .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
    .accessibilityElement(children: .combine)
  }

  // MARK: - 時刻表

  private var timetableGrid: some View {
    VStack(spacing: 0) {
      ForEach(Array(hourGroups.enumerated()), id: \.element.id) { index, group in
        hourRow(group)

        if index < hourGroups.count - 1 {
          SkyDivider()
        }
      }
    }
    .skyCard(padding: 0, isOpaque: true)
  }

  /// 1つの時台を、時のラベルと分のマスで表します。
  private func hourRow(_ group: TimetableHour) -> some View {
    let isCurrentHour = group.hour == currentHour

    return HStack(alignment: .top, spacing: hourLabelSpacing) {
      Text("\(group.hour)")
        .dynamicFont(size: 17, relativeTo: .body, weight: .bold, design: .rounded)
        .monospacedDigit()
        .foregroundStyle(isCurrentHour ? sky.accent : sky.inkSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: hourLabelWidth, alignment: .trailing)
        .frame(minHeight: cellSize)

      LazyVGrid(
        columns: Array(
          repeating: GridItem(.flexible(), spacing: cellSpacing),
          count: columnCount
        ),
        alignment: .leading,
        spacing: cellSpacing
      ) {
        ForEach(group.buses) { bus in
          minuteCell(bus)
        }
      }
      // 残りの幅をすべて使い、マスを画面いっぱいに広げます。
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, rowPadding)
    .padding(.vertical, 5)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(isCurrentHour ? sky.accentSoft : Color.clear)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(group.hour)時台")
  }

  /// 1便を表す分のマスです。押すとその便の通知を設定できます。
  private func minuteCell(_ bus: Bus) -> some View {
    let isScheduled = scheduledBusIDs.contains(bus.id)
    let isRecommended = viewModel.searchResults.contains { $0.id == bus.id }
    let hasDeparted = hasDeparted(bus)

    return Button {
      onSelectBus(bus)
    } label: {
      VStack(spacing: 0) {
        Text(minuteText(for: bus))
          .dynamicFont(size: 16, relativeTo: .body, weight: .bold, design: .rounded)
          .monospacedDigit()
          .foregroundStyle(isScheduled ? Color.white : sky.ink)

        // 備考のある便には印だけを添え、内容はタップ後に見せます。
        Circle()
          .fill(isScheduled ? Color.white : sky.inkSecondary)
          .frame(width: 3, height: 3)
          .opacity(bus.note == nil ? 0 : 1)
          .padding(.top, 2)
      }
      .frame(maxWidth: .infinity)
      .frame(minHeight: cellSize)
      .background(
        RoundedRectangle(cornerRadius: cellRadius, style: .continuous)
          .fill(isScheduled ? sky.accent : Color.clear)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cellRadius, style: .continuous)
          .stroke(
            isRecommended && !isScheduled ? sky.accent : sky.ink.opacity(0.26),
            lineWidth: isRecommended && !isScheduled ? 2 : SkyMetrics.borderWidth
          )
      )
      // 出発済みの便は淡くしますが、翌日の同じ便に通知できるので押せるままにします。
      .opacity(hasDeparted ? 0.45 : 1)
    }
    .buttonStyle(SkyPressStyle())
    .accessibilityLabel(accessibilityLabel(for: bus, isScheduled: isScheduled))
    .accessibilityHint("出発前に通知する方法を選びます")
  }

  private var legend: some View {
    VStack(alignment: .leading, spacing: 6) {
      SkyNoticeRow(
        message: "色のついた時刻は通知を設定済みです",
        systemImage: "bell.fill"
      )
      SkyNoticeRow(
        message: "点の付いた便はお買い物便や経由便です",
        systemImage: "smallcircle.filled.circle"
      )
    }
  }

  // MARK: - 時刻の組み立て

  /// 時台ごとにまとめ、運行日の順に並べます。
  private var hourGroups: [TimetableHour] {
    let grouped = Dictionary(grouping: viewModel.currentFullTimetable) { bus in
      Self.timeComponents(from: bus.departure)?.hour ?? 0
    }

    return grouped
      .map { hour, buses in
        TimetableHour(
          hour: hour,
          buses: buses.sorted { lhs, rhs in
            (Self.timeComponents(from: lhs.departure)?.minute ?? 0)
              < (Self.timeComponents(from: rhs.departure)?.minute ?? 0)
          }
        )
      }
      .sorted { $0.serviceOrder < $1.serviceOrder }
  }

  /// いま何時台かです。該当する行を強調するために使います。
  private var currentHour: Int {
    Calendar.current.component(.hour, from: viewModel.availabilityReferenceDate)
  }

  /// その便がすでに出発したかどうかです。
  private func hasDeparted(_ bus: Bus) -> Bool {
    guard let departure = BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
      for: bus.departure,
      from: viewModel.availabilityReferenceDate
    ) else {
      return false
    }
    return departure <= viewModel.availabilityReferenceDate
  }

  private func minuteText(for bus: Bus) -> String {
    guard let minute = Self.timeComponents(from: bus.departure)?.minute else {
      return bus.departure
    }
    return String(format: "%02d", minute)
  }

  private func accessibilityLabel(for bus: Bus, isScheduled: Bool) -> String {
    var text = "\(bus.departure)発、\(bus.arrival)着"

    if let note = bus.note {
      text += "、\(note)"
    }
    if isScheduled {
      text += "、通知設定済み"
    }
    if hasDeparted(bus) {
      text += "、出発済み"
    }
    return text
  }

  /// "7:10" のような表記から時と分を取り出します。
  private static func timeComponents(from value: String) -> (hour: Int, minute: Int)? {
    let parts = value.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2 else { return nil }
    return (parts[0], parts[1])
  }
}
