import SwiftUI

struct NotificationManagementView: View {
  @ObservedObject var viewModel: NotificationViewModel
  let liveActivityBusID: String?
  let onEndLiveActivity: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.sky) private var sky

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: SkyMetrics.sectionSpacing) {
          permissionCard
          liveActivityCard
          localNotifications
        }
        .padding(.horizontal, SkyMetrics.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 30)
      }
      .background(SkyBackground())
      .navigationTitle("設定した通知")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("閉じる") { dismiss() }
            .fontWeight(.bold)
            .foregroundStyle(sky.accent)
        }
      }
      .preferredColorScheme(sky.isNight ? .dark : .light)
    }
  }

  private var isAuthorized: Bool {
    viewModel.permissionStatus == .authorized
  }

  private var permissionCard: some View {
    DynamicTypeStack(verticalAlignment: .top, spacing: 12) {
      Image(systemName: isAuthorized ? "checkmark.circle.fill" : "bell.slash.fill")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(isAuthorized ? sky.positive : sky.warning)

      VStack(alignment: .leading, spacing: 6) {
        Text(viewModel.permissionStatus.title)
          .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
          .foregroundStyle(sky.ink)
          .fixedSize(horizontal: false, vertical: true)

        Text("通常の通知を受け取るには、iPhoneの通知許可が必要です。")
          .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)

        if viewModel.permissionStatus == .denied {
          Button("通知の設定を開く", action: viewModel.openNotificationSettings)
            .dynamicFont(size: 13, relativeTo: .footnote, weight: .bold, design: .rounded)
            .foregroundStyle(sky.accent)
            .frame(minHeight: SkyMetrics.minimumTapSize, alignment: .leading)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }

  private var liveActivityCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      SkySectionLabel(text: "Live Activity")

      if liveActivityBusID != nil {
        Text("ロック画面にバスの出発時間を表示しています。")
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)

        Button("Live Activityを終了", action: onEndLiveActivity)
          .dynamicFont(size: 14, relativeTo: .subheadline, weight: .bold, design: .rounded)
          .foregroundStyle(sky.warning)
          .frame(minHeight: SkyMetrics.minimumTapSize, alignment: .leading)
      } else {
        Text("表示中のLive Activityはありません。便を選ぶと開始できます。")
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .skyCard()
  }

  private var localNotifications: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        SkySectionLabel(text: "通常の通知")
        Spacer()
        if !viewModel.scheduledNotifications.isEmpty {
          Button("すべて解除") {
            viewModel.cancelAllNotifications()
          }
          .dynamicFont(size: 12, relativeTo: .caption, weight: .bold, design: .rounded)
          .foregroundStyle(sky.warning)
        }
      }

      if viewModel.scheduledNotifications.isEmpty {
        Text("設定されている通知はありません。")
          .dynamicFont(size: 14, relativeTo: .subheadline, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .padding(.vertical, 10)
      } else {
        ForEach(viewModel.scheduledNotifications) { item in
          notificationRow(for: item)
        }
      }
    }
  }

  private func notificationRow(for item: ScheduledBusNotification) -> some View {
    DynamicTypeStack(verticalAlignment: .top, spacing: 12) {
      Image(systemName: "bell.badge.fill")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(sky.accent)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.busDescription)
          .dynamicFont(size: 14, relativeTo: .subheadline, weight: .bold, design: .rounded)
          .foregroundStyle(sky.ink)
          .fixedSize(horizontal: false, vertical: true)
        Text("通知：\(item.notificationDescription)")
          .dynamicFont(size: 12, relativeTo: .caption, weight: .bold)
          .foregroundStyle(sky.accent)
          .fixedSize(horizontal: false, vertical: true)
        Text(item.routeName)
          .dynamicFont(size: 11, relativeTo: .caption2, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Button {
        viewModel.cancelNotification(for: item)
      } label: {
        Image(systemName: "trash")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(sky.warning)
          .frame(width: SkyMetrics.minimumTapSize, height: SkyMetrics.minimumTapSize)
      }
      .buttonStyle(SkyPressStyle())
      .accessibilityLabel("この通知を解除")
    }
    .skyCard(radius: 16, padding: 14)
  }
}
