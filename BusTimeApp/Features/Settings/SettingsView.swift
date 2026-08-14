import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.sky) private var sky
  @ObservedObject var viewModel: SettingsViewModel

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: SkyMetrics.sectionSpacing) {
          appearanceCard
          liveActivityCard
        }
        .padding(.horizontal, SkyMetrics.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 32)
      }
      .background(SkyBackground())
      .navigationTitle("設定")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("完了") { dismiss() }
            .fontWeight(.bold)
            .foregroundStyle(sky.accent)
        }
      }
      .preferredColorScheme(sky.isNight ? .dark : .light)
      .onAppear {
        viewModel.refreshLiveActivityAvailability()
      }
    }
  }

  /// 時刻に連動する配色について説明するカードです。設定項目ではなく案内です。
  private var appearanceCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: "画面の色")

      Text("時刻に合わせて変わります")
        .dynamicFont(size: 18, relativeTo: .title3, weight: .bold, design: .rounded)
        .foregroundStyle(sky.ink)
        .fixedSize(horizontal: false, vertical: true)

      Text("朝は明るい空、夕方は夕焼け、夜は星空へと背景がゆっくり変化します。太陽と月の位置も現在時刻に合わせて動きます。")
        .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
        .foregroundStyle(sky.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)

      skyPreviewStrip

      SkyNoticeRow(
        message: "海浜幕張駅の周辺で雨が降っているときは、背景にも雨が降ります。天気の情報は Open-Meteo から取得しています。",
        systemImage: "cloud.rain"
      )
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }

  /// 1日の色の移り変わりを小さな帯で示します。
  private var skyPreviewStrip: some View {
    let previewHours: [(hour: Double, label: String)] = [
      (7, "朝"),
      (12, "昼"),
      (17.5, "夕"),
      (22, "夜")
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
    .accessibilityLabel("朝、昼、夕方、夜の背景の見本")
  }

  private var liveActivityCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SkySectionLabel(text: "バスのお知らせ")

      Toggle(
        isOn: Binding(
          get: { viewModel.prefersLiveActivity },
          set: viewModel.setLiveActivityEnabled
        )
      ) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Live Activityを使う")
            .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
            .foregroundStyle(sky.ink)
          Text("通常の通知と一緒に、ロック画面やDynamic Islandへ残り時間を表示します。")
            .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
            .foregroundStyle(sky.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .tint(sky.accent)
      .disabled(!viewModel.isLiveActivityAvailable)

      if viewModel.isLiveActivityAvailable {
        SkyNoticeRow(message: "対応端末では最初からオンです。ここでいつでも変更できます。")
      } else {
        SkyNoticeRow(
          message: "この端末では利用できないか、iPhoneの設定でLive Activityがオフになっています。",
          systemImage: "exclamationmark.circle.fill",
          isWarning: true
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }
}
