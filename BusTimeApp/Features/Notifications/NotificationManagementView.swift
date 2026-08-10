import SwiftUI

struct NotificationManagementView: View {
    @ObservedObject var viewModel: NotificationViewModel
    let liveActivityBusID: String?
    let onEndLiveActivity: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDesignMode) private var designMode

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    permissionCard
                    liveActivityCard
                    localNotifications
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .background(NeumorphicBackground())
            .navigationTitle("設定した通知")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(Color.neumoAccentDeep)
                }
            }
            .preferredColorScheme(designMode == .claymorphic ? .light : nil)
        }
    }

    private var permissionCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: viewModel.permissionStatus == .authorized ? "checkmark.circle.fill" : "bell.slash.fill")
                .font(.title2)
                .foregroundStyle(viewModel.permissionStatus == .authorized ? Color.neumoGreen : Color.neumoWarning)
            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.permissionStatus.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.neumoText)
                Text("通常の通知を受け取るには、iPhoneの通知許可が必要です。")
                    .font(.caption)
                    .foregroundStyle(Color.neumoMuted)
                if viewModel.permissionStatus == .denied {
                    Button("通知の設定を開く", action: viewModel.openNotificationSettings)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.neumoAccentDeep)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var liveActivityCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Live Activity", systemImage: "lock.rectangle.on.rectangle")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.neumoText)
            if liveActivityBusID != nil {
                Text("現在、ロック画面にバスの出発時間を表示しています。")
                    .font(.caption)
                    .foregroundStyle(Color.neumoMuted)
                Button("Live Activityを終了", action: onEndLiveActivity)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.neumoWarning)
            } else {
                Text("表示中のLive Activityはありません。便を選ぶと開始できます。")
                    .font(.caption)
                    .foregroundStyle(Color.neumoMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.neumoAccent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var localNotifications: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("通常の通知", systemImage: "bell.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.neumoText)
                Spacer()
                if !viewModel.scheduledNotifications.isEmpty {
                    Button("すべて解除") {
                        viewModel.cancelAllNotifications()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.neumoWarning)
                }
            }

            if viewModel.scheduledNotifications.isEmpty {
                Text("設定されている通知はありません。")
                    .font(.subheadline)
                    .foregroundStyle(Color.neumoMuted)
                    .padding(.vertical, 12)
            } else {
                ForEach(viewModel.scheduledNotifications) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(Color.neumoAccent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.busDescription)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.neumoText)
                            Text("通知：\(item.notificationDescription)")
                                .font(.caption)
                                .foregroundStyle(Color.neumoAccentDeep)
                            Text(item.routeName)
                                .font(.caption2)
                                .foregroundStyle(Color.neumoMuted)
                        }
                        Spacer(minLength: 4)
                        Button {
                            viewModel.cancelNotification(for: item)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.neumoWarning)
                                .padding(8)
                        }
                        .accessibilityLabel("この通知を解除")
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.76))
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
            }
        }
    }
}
