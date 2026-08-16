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
      .navigationTitle(L10n.Manage.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(L10n.Common.close) { dismiss() }
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
        .dynamicFont(size: 20, relativeTo: .title3, weight: .semibold)
        .foregroundStyle(isAuthorized ? sky.positive : sky.warning)

      VStack(alignment: .leading, spacing: 6) {
        Text(viewModel.permissionStatus.title)
          .dynamicFont(size: 15, relativeTo: .subheadline, weight: .bold, design: .rounded)
          .foregroundStyle(sky.ink)
          .fixedSize(horizontal: false, vertical: true)

        Text(L10n.Manage.permissionMessage)
          .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)

        if viewModel.permissionStatus == .denied {
          Button(L10n.Manage.openNotificationSettings, action: viewModel.openNotificationSettings)
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
        Text(L10n.Manage.liveActivityShowing)
          .dynamicFont(size: 13, relativeTo: .footnote, weight: .medium)
          .foregroundStyle(sky.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)

        Button(L10n.Manage.endLiveActivity, action: onEndLiveActivity)
          .dynamicFont(size: 14, relativeTo: .subheadline, weight: .bold, design: .rounded)
          .foregroundStyle(sky.warning)
          .frame(minHeight: SkyMetrics.minimumTapSize, alignment: .leading)
      } else {
        Text(L10n.Manage.noLiveActivity)
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
        SkySectionLabel(text: L10n.Options.standardSection)
        Spacer()
        if !viewModel.scheduledNotifications.isEmpty {
          Button(L10n.Manage.clearAll) {
            viewModel.cancelAllNotifications()
          }
          .dynamicFont(size: 12, relativeTo: .caption, weight: .bold, design: .rounded)
          .foregroundStyle(sky.warning)
        }
      }

      if viewModel.scheduledNotifications.isEmpty {
        Text(L10n.Manage.empty)
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
        .dynamicFont(size: 14, relativeTo: .body, weight: .semibold)
        .foregroundStyle(sky.accent)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.busDescription)
          .dynamicFont(size: 14, relativeTo: .subheadline, weight: .bold, design: .rounded)
          .foregroundStyle(sky.ink)
          .fixedSize(horizontal: false, vertical: true)
        Text(L10n.Manage.notificationRow(item.notificationDescription))
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
          .dynamicFont(size: 14, relativeTo: .body, weight: .semibold)
          .foregroundStyle(sky.warning)
          .scaledTapTarget()
      }
      .buttonStyle(SkyPressStyle())
      .accessibilityLabel(L10n.Manage.cancelOne)
    }
    .skyCard(radius: 16, padding: 14)
  }
}
