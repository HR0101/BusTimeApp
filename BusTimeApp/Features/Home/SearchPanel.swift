import SwiftUI

/// 行き先と時刻の指定をまとめた検索パネルです。
///
/// 経路の選択と時刻の指定は同じ「検索する」という目的の操作なので、
/// カードを分けずに1枚へまとめ、区切り線だけで役割を分けています。
struct SearchPanel: View {
  @Environment(\.sky) private var sky

  @ObservedObject var viewModel: HomeViewModel
  let locationAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      routeSection
      SkyDivider()
      timeSection
      searchButton
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }

  // MARK: - 行き先

  private var routeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: "どこからどこへ")

      DynamicTypeStack(verticalAlignment: .center, spacing: 8) {
        endpointControls
      }

      if let message = viewModel.routeAvailabilityMessage {
        SkyNoticeRow(
          message: message,
          systemImage: "exclamationmark.circle.fill",
          isWarning: true
        )
      } else {
        SkyNoticeRow(message: viewModel.selectedRoute.guidance)
      }

      Button(action: locationAction) {
        HStack(spacing: 6) {
          Image(systemName: "location.fill")
          Text("現在地を出発地にする")
          Spacer(minLength: 0)
          Image(systemName: "arrow.up.right")
        }
        .dynamicFont(size: 13, relativeTo: .footnote, weight: .bold, design: .rounded)
        .foregroundStyle(sky.accent)
        .frame(minHeight: SkyMetrics.minimumTapSize)
      }
      .buttonStyle(SkyPressStyle())
    }
  }

  @ViewBuilder
  private var endpointControls: some View {
    EndpointMenu(
      title: "出発地",
      selected: viewModel.selectedOrigin,
      options: viewModel.availableOrigins,
      action: viewModel.selectOrigin
    )

    Button(action: viewModel.swapEndpoints) {
      Image(systemName: "arrow.left.arrow.right")
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(viewModel.canSwapEndpoints ? sky.accent : sky.inkFaint)
        .frame(width: SkyMetrics.minimumTapSize, height: SkyMetrics.minimumTapSize)
    }
    .buttonStyle(SkyPressStyle())
    .disabled(!viewModel.canSwapEndpoints)
    .accessibilityLabel("出発地と目的地を入れ替える")

    EndpointMenu(
      title: "目的地",
      selected: viewModel.selectedDestination,
      options: viewModel.availableDestinations,
      action: viewModel.selectDestination
    )
  }

  // MARK: - 時刻

  private var timeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: "いつのバス")

      HStack(spacing: 8) {
        SkyChip(
          title: "出発から",
          isSelected: viewModel.searchType == .departure
        ) {
          withAnimation(.easeOut(duration: 0.2)) {
            viewModel.searchType = .departure
          }
        }
        SkyChip(
          title: "到着まで",
          isSelected: viewModel.searchType == .arrival
        ) {
          withAnimation(.easeOut(duration: 0.2)) {
            viewModel.searchType = .arrival
          }
        }
      }

      SkyNoticeRow(message: viewModel.searchType.explanation)

      timeSelection
    }
  }

  private var timeSelection: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        timePicker
        Spacer(minLength: 4)
        currentTimeButton
      }

      VStack(alignment: .leading, spacing: 10) {
        timePicker
        currentTimeButton
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
  }

  private var timePicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(viewModel.searchType.timeTitle)
        .dynamicFont(size: 11, relativeTo: .caption2, weight: .bold)
        .foregroundStyle(sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)

      DatePicker("", selection: $viewModel.searchTime, displayedComponents: .hourAndMinute)
        .labelsHidden()
        .tint(sky.accent)
        .fixedSize()
    }
  }

  private var currentTimeButton: some View {
    Button {
      viewModel.setSearchToCurrentTime()
    } label: {
      Label("現在時刻", systemImage: "clock.arrow.circlepath")
        .dynamicFont(size: 13, relativeTo: .footnote, weight: .bold, design: .rounded)
        .foregroundStyle(sky.ink)
        .padding(.horizontal, 14)
        .frame(minHeight: SkyMetrics.minimumTapSize)
        .background(
          Capsule().stroke(sky.ink.opacity(0.24), lineWidth: SkyMetrics.borderWidth)
        )
    }
    .buttonStyle(SkyPressStyle())
    .accessibilityHint("選択中の検索方法を変えずに現在時刻を入力します")
  }

  // MARK: - 検索

  private var searchButton: some View {
    Button {
      withAnimation(.easeOut(duration: 0.22)) {
        viewModel.performSearch()
      }
    } label: {
      HStack {
        Text("この条件で検索")
        Spacer()
        Image(systemName: "arrow.right")
      }
      .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
      .foregroundStyle(Color.white)
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity, minHeight: 52)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(sky.accent)
      )
    }
    .buttonStyle(SkyPressStyle())
  }
}

/// 出発地・目的地を選ぶメニューです。
struct EndpointMenu: View {
  @Environment(\.sky) private var sky

  let title: String
  let selected: HomeViewModel.Stop
  let options: [HomeViewModel.Stop]
  let action: (HomeViewModel.Stop) -> Void

  private var isSelectedStopAvailable: Bool {
    options.contains(selected)
  }

  var body: some View {
    Menu {
      ForEach(options) { stop in
        Button {
          action(stop)
        } label: {
          Label(
            stop.rawValue,
            systemImage: stop == selected ? "checkmark.circle.fill" : stop.systemName
          )
        }
      }
    } label: {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .dynamicFont(size: 10, relativeTo: .caption2, weight: .bold)
          .foregroundStyle(sky.inkSecondary)

        HStack(spacing: 5) {
          Text(isSelectedStopAvailable ? selected.rawValue : "本日の運行終了")
            .dynamicFont(size: 14, relativeTo: .subheadline, weight: .bold, design: .rounded)
            .foregroundStyle(sky.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          Spacer(minLength: 2)
          Image(systemName: "chevron.down")
            .font(.caption2.weight(.bold))
            .foregroundStyle(sky.inkSecondary)
        }
      }
      .frame(maxWidth: .infinity, minHeight: SkyMetrics.minimumTapSize, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(sky.ink.opacity(0.2), lineWidth: SkyMetrics.borderWidth)
      )
    }
    .disabled(options.isEmpty)
    .accessibilityLabel(
      isSelectedStopAvailable
        ? "\(title)、\(selected.rawValue)"
        : "\(title)、本日の運行終了"
    )
  }
}
