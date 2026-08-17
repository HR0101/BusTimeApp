import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.sky) private var sky
  @ObservedObject var viewModel: SettingsViewModel
  @ObservedObject var weatherViewModel: WeatherViewModel

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: SkyMetrics.sectionSpacing) {
          appearanceCard
          cardOpacityCard
          liveActivityCard
        }
        .padding(.horizontal, SkyMetrics.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 32)
      }
      .background(SkyBackground())
      .navigationTitle(L10n.Settings.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(L10n.Common.done) { dismiss() }
            .fontWeight(.bold)
            .foregroundStyle(sky.accentReadable)
        }
      }
      .onAppear {
        viewModel.refreshLiveActivityAvailability()
      }
    }
    // この画面自身のカードにも、選んでいる濃さをその場で反映します。
    .environment(\.skyCardOpacity, viewModel.cardOpacity)
  }

  /// 時刻に連動する配色について説明するカードです。設定項目ではなく案内です。
  private var appearanceCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: L10n.Settings.appearanceSection)

      Text(L10n.Settings.appearanceTitle)
        .dynamicFont(size: 18, relativeTo: .title3, weight: .bold, design: .rounded)
        .foregroundStyle(sky.ink)
        .fixedSize(horizontal: false, vertical: true)

      Text(L10n.Settings.appearanceDescription)
        .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
        .foregroundStyle(sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)

      Picker(
        L10n.Settings.appearanceMode,
        selection: Binding(
          get: { viewModel.appearancePreference },
          set: viewModel.setAppearancePreference
        )
      ) {
        ForEach(AppearancePreference.allCases) { preference in
          Text(preference.title).tag(preference)
        }
      }
      .pickerStyle(.menu)
      .tint(sky.accent)

      skyPreviewStrip

      SkyNoticeRow(
        message: weatherStatusMessage,
        systemImage: "cloud.rain"
      )

      Text(L10n.Settings.weatherNotice)
        .dynamicFont(size: 11, relativeTo: .caption2, weight: .medium)
        .foregroundStyle(sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }

  private var weatherStatusMessage: String {
    guard let lastUpdate = weatherViewModel.lastSuccessfulUpdate else {
      return weatherViewModel.hasFailedRecently
        ? L10n.Settings.weatherUnavailable
        : L10n.Settings.weatherNotice
    }

    let formatter = DateFormatter()
    formatter.calendar = AppCalendar.japan
    formatter.timeZone = AppCalendar.timeZone
    formatter.dateStyle = AppCalendar.japan.isDate(lastUpdate, inSameDayAs: AppDate.now())
      ? .none
      : .short
    formatter.timeStyle = .short
    let time = formatter.string(from: lastUpdate)
    return weatherViewModel.hasFailedRecently
      ? L10n.Settings.weatherCached(time)
      : L10n.Settings.weatherUpdated(time)
  }

  /// 1日の色の移り変わりを小さな帯で示します。
  private var skyPreviewStrip: some View {
    let previewHours: [(hour: Double, label: String)] = [
      (7, L10n.Settings.previewMorning),
      (12, L10n.Settings.previewNoon),
      (17.5, L10n.Settings.previewEvening),
      (22, L10n.Settings.previewNight)
    ]

    return HStack(spacing: 8) {
      ForEach(previewHours, id: \.hour) { item in
        VStack(spacing: 6) {
          SkyCanvas()
            .environment(\.sky, SkyPalette.at(hour: item.hour))
            .frame(height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

          Text(item.label)
            .dynamicFont(size: 11, relativeTo: .caption2, weight: .bold)
            .foregroundStyle(sky.inkSecondary)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(L10n.Settings.previewAccessibility)
  }

  /// カードの地の濃さを選ぶカードです。
  private var cardOpacityCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: L10n.Settings.cardOpacitySection)

      Text(L10n.Settings.cardOpacityDescription)
        .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
        .foregroundStyle(sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 12) {
        Text(L10n.Settings.cardOpacityLight)
          .dynamicFont(size: 11, relativeTo: .caption2, weight: .bold)
          .foregroundStyle(sky.inkSecondary)

        Slider(
          value: Binding(
            get: { viewModel.cardOpacity },
            set: viewModel.setCardOpacity
          ),
          in: SkyCardOpacity.minimum...SkyCardOpacity.maximum
        )
        .tint(sky.accent)
        .accessibilityLabel(L10n.Settings.cardOpacitySection)

        Text(L10n.Settings.cardOpacityDense)
          .dynamicFont(size: 11, relativeTo: .caption2, weight: .bold)
          .foregroundStyle(sky.inkSecondary)
      }

      SkyNoticeRow(message: L10n.Settings.cardOpacityNotice)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }

  private var liveActivityCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: L10n.Settings.notificationsSection)

      Toggle(
        isOn: Binding(
          get: { viewModel.prefersLiveActivity },
          set: viewModel.setLiveActivityEnabled
        )
      ) {
        VStack(alignment: .leading, spacing: 4) {
          Text(L10n.Settings.liveActivityToggle)
            .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
            .foregroundStyle(sky.ink)
          Text(L10n.Settings.liveActivityDescription)
            .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
            .foregroundStyle(sky.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .tint(sky.accent)
      .disabled(!viewModel.isLiveActivityAvailable)

      if viewModel.isLiveActivityAvailable {
        SkyNoticeRow(message: L10n.Settings.liveActivityAvailable)
      } else {
        SkyNoticeRow(
          message: L10n.Options.liveActivityUnavailable,
          systemImage: "exclamationmark.circle.fill",
          isWarning: true
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }
}
