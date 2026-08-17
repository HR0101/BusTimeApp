import SwiftUI

/// ホーム画面で経路と運行日・時刻を扱う部品をまとめたファイルです。
///
/// 並びは ルート → 運行日 → 時刻 → 結果 の順です。
/// ルートは起動時に自動で決まる「状態」なので上に置き、
/// 人が触る条件をその下にまとめ、どちらも結果より上に置いています。
/// いずれの操作も触った時点で結果へ反映されるため、実行ボタンは置いていません。

// MARK: - 経路の帯

/// 現在の経路を示し、その場で変更できる帯です。
struct RouteHeaderCard: View {
  @Environment(\.sky) private var sky
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  @ObservedObject var viewModel: HomeViewModel
  let locationAction: () -> Void

  /// 停留所名の基準サイズです。画面の主役の次に目立つ大きさにします。
  private let stopNameSize: CGFloat = 17

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      routeRow
        // 停留所名が変わるときはアニメーションを付けません。
        // 動かすと、古い名前と新しい名前が重なったまま枠の幅や矢印の位置も動くため、
        // 切り替えた直後の一瞬だけ文字が欠けたり重なったりして見えます。
        .animation(nil, value: viewModel.selectedOrigin)
        .animation(nil, value: viewModel.selectedDestination)

      decisionRow

      if let message = viewModel.routeAvailabilityMessage {
        SkyNoticeRow(
          message: message,
          systemImage: "exclamationmark.circle.fill",
          isWarning: true
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard(padding: 16)
  }

  /// 出発地と目的地を並べる行です。
  ///
  /// 幅を測って並びを切り替えると、停留所名が変わった直後の一瞬だけ
  /// 前の幅のまま描かれて文字が見切れます。そのため測り直しには頼らず、
  /// 文字サイズだけで縦横を決め、収まらない分は文字を縮めて合わせます。
  @ViewBuilder
  private var routeRow: some View {
    if dynamicTypeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          originMenu
          Spacer(minLength: 0)
          swapButton
        }

        HStack(spacing: 6) {
          Image(systemName: "arrow.turn.down.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(sky.inkSecondary)
          destinationMenu
        }
      }
    } else {
      // 出発地と目的地の枠は、名前によらず同じ幅で固定されています。
      // そのため矢印も入れ替えボタンも常に同じ位置に置かれます。
      HStack(spacing: 4) {
        originMenu
        arrowIcon
        destinationMenu
        Spacer(minLength: 0)
        swapButton
      }
    }
  }

  private var arrowIcon: some View {
    Image(systemName: "arrow.right")
      .dynamicFont(size: 13, relativeTo: .headline, weight: .bold)
      .foregroundStyle(sky.inkSecondary)
      .accessibilityHidden(true)
  }

  private var originMenu: some View {
    endpointMenu(
      title: L10n.Route.originLabel,
      selected: viewModel.selectedOrigin,
      options: viewModel.availableOrigins,
      action: viewModel.selectOrigin
    )
  }

  private var destinationMenu: some View {
    endpointMenu(
      title: L10n.Route.destinationLabel,
      selected: viewModel.selectedDestination,
      options: viewModel.availableDestinations,
      action: viewModel.selectDestination
    )
  }

  /// 停留所を選ぶメニューです。名前をそのまま見出しとして扱い、
  /// 押せることは下向きの山形で示します。
  private func endpointMenu(
    title: String,
    selected: HomeViewModel.Stop,
    options: [HomeViewModel.Stop],
    action: @escaping (HomeViewModel.Stop) -> Void
  ) -> some View {
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
      HStack(spacing: 3) {
        ZStack(alignment: .leading) {
          // 最も長い停留所名を見えない下敷きとして重ね、枠の幅を固定します。
          // 選んでいる名前の長さで幅が決まると、入れ替えたときに
          // 矢印やボタンだけでなく文字の位置まで動いてしまいます。
          ForEach(HomeViewModel.Stop.allCases) { stop in
            stopNameText(stop.rawValue)
              .hidden()
          }

          stopNameText(selected.rawValue)
        }
        .accessibilityHidden(true)

        Image(systemName: "chevron.down")
          .font(.caption2.weight(.bold))
          .foregroundStyle(sky.inkSecondary)
      }
      .frame(minHeight: SkyMetrics.minimumTapSize)
    }
    .disabled(options.isEmpty)
    .accessibilityLabel(L10n.Route.stopAccessibility(title, selected.rawValue))
    .accessibilityHint(L10n.Route.menuHint)
  }

  /// 停留所名を表す文字です。幅を測る下敷きと実際の表示で同じ体裁を使います。
  private func stopNameText(_ name: String) -> some View {
    Text(name)
      .dynamicFont(
        size: stopNameSize,
        relativeTo: .headline,
        weight: .bold,
        design: .rounded
      )
      .foregroundStyle(sky.ink)
      .lineLimit(1)
      .minimumScaleFactor(0.6)
  }

  private var swapButton: some View {
    Button {
      // 向きが入れ替わったことが一瞬で終わるので、手応えを添えます。
      SkyHaptics.tap()
      viewModel.swapEndpoints()
    } label: {
      Image(systemName: "arrow.left.arrow.right")
        .dynamicFont(size: 14, relativeTo: .body, weight: .bold)
        .foregroundStyle(viewModel.canSwapEndpoints ? sky.accent : sky.inkFaint)
        .scaledTapTarget()
    }
    .buttonStyle(SkyPressStyle())
    .disabled(!viewModel.canSwapEndpoints)
    .accessibilityLabel(L10n.Route.swapLabel)
    .accessibilityHint(
      viewModel.canSwapEndpoints
        ? L10n.Route.swapHintAvailable
        : L10n.Route.swapHintUnavailable
    )
  }

  /// 経路がどう決まったかを示す行です。自動で決まっていないときだけ、
  /// 現在地へ合わせ直す操作を添えます。
  private var decisionRow: some View {
    DynamicTypeStack(verticalAlignment: .center, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: viewModel.routeDecision.systemName)
          .font(.caption2.weight(.bold))
          .foregroundStyle(sky.inkSecondary)

        Text(viewModel.routeDecision.explanation)
          .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if viewModel.routeDecision != .automatic {
        locationButton
      }
    }
  }

  private var locationButton: some View {
    Button {
      SkyHaptics.tap()
      locationAction()
    } label: {
      Label(L10n.Route.useCurrentLocation, systemImage: "location.fill")
        .dynamicFont(size: 12, relativeTo: .caption, weight: .bold, design: .rounded)
        .foregroundStyle(sky.accent)
        .padding(.horizontal, 12)
        .frame(minHeight: SkyMetrics.minimumTapSize)
        .background(
          Capsule().stroke(sky.accent.opacity(0.4), lineWidth: SkyMetrics.borderWidth)
        )
    }
    .buttonStyle(SkyPressStyle())
  }
}

// MARK: - いつのバスか

/// 運行日と時刻を選ぶカードです。
///
/// 経路は自動で決まる「状態」なので上に置き、人が触る条件はここへまとめます。
/// 並びは依存の順、つまり運行日を決めてから時刻を決める順にしています。
/// 結果より上に置くことで、変えた場所と変わる場所が同じ視界に入ります。
struct ServiceDayTimeCard: View {
  @Environment(\.sky) private var sky
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  @ObservedObject var viewModel: HomeViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: L10n.When.title)

      serviceDayChips
      searchTypeChips
      timeSelection
      resultSummary
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard(padding: 16)
  }

  /// 運行日の選択です。平日ダイヤが1本しかないため、
  /// 日付そのものではなく運行日の単位で選びます。
  private var serviceDayChips: some View {
    HStack(spacing: 8) {
      ForEach(HomeViewModel.ServiceDay.allCases) { day in
        SkyChip(
          title: day.displayName,
          isSelected: viewModel.serviceDay == day
        ) {
          withAnimation(.easeOut(duration: 0.2)) {
            viewModel.serviceDay = day
          }
        }
      }
    }
  }

  private var searchTypeChips: some View {
    HStack(spacing: 8) {
      SkyChip(
        title: HomeViewModel.SearchType.departure.shortTitle,
        isSelected: viewModel.searchType == .departure
      ) {
        withAnimation(.easeOut(duration: 0.2)) {
          viewModel.searchType = .departure
        }
      }
      SkyChip(
        title: HomeViewModel.SearchType.arrival.shortTitle,
        isSelected: viewModel.searchType == .arrival
      ) {
        withAnimation(.easeOut(duration: 0.2)) {
          viewModel.searchType = .arrival
        }
      }
    }
  }

  @ViewBuilder
  private var timeSelection: some View {
    // 現在時刻へ戻す操作は、今日の便を見ているときだけ意味を持ちます。
    if !viewModel.isViewingToday {
      timePicker
    } else if dynamicTypeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 10) {
        timePicker
        currentTimeButton
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    } else {
      HStack(spacing: 12) {
        timePicker
        Spacer(minLength: 4)
        currentTimeButton
      }
    }
  }

  private var timePicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(viewModel.searchType.timeTitle)
        .dynamicFont(size: 11, relativeTo: .caption2, weight: .bold)
        .foregroundStyle(sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)

      // ラベル文字列は渡したうえで隠します。見た目は上の見出しが担い、
      // VoiceOverには何の時刻なのかが伝わるようにするためです。
      DatePicker(
        viewModel.searchType.timeTitle,
        selection: $viewModel.searchTime,
        displayedComponents: .hourAndMinute
      )
      .labelsHidden()
      .tint(sky.accent)
      .fixedSize()
    }
  }

  private var currentTimeButton: some View {
    Button {
      viewModel.setSearchToCurrentTime()
    } label: {
      Label(L10n.When.currentTime, systemImage: "clock.arrow.circlepath")
        .dynamicFont(size: 13, relativeTo: .footnote, weight: .bold, design: .rounded)
        .foregroundStyle(sky.ink)
        .padding(.horizontal, 14)
        .frame(minHeight: SkyMetrics.minimumTapSize)
        .background(
          Capsule().stroke(sky.ink.opacity(0.24), lineWidth: SkyMetrics.borderWidth)
        )
    }
    .buttonStyle(SkyPressStyle())
    .accessibilityHint(L10n.When.currentTimeHint)
  }

  /// 何件見つかったかを、条件を変えた手元に出します。
  /// 結果カードはこのすぐ下にありますが、条件を変えた瞬間の手応えを
  /// 同じ場所で返すための行です。
  private var resultSummary: some View {
    Text(viewModel.searchResultDescription)
      .dynamicFont(size: 12, relativeTo: .caption, weight: .bold, design: .rounded)
      .foregroundStyle(viewModel.searchResults.isEmpty ? sky.warning : sky.positive)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
