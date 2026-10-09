import SwiftUI

/// Connection and freshness stay visible while saved timetables remain usable.
struct TimetableSyncBanner: View {
    @Environment(\.sky) private var sky
    @ObservedObject var viewModel: HomeViewModel

    private var info: TimetableSyncInfo { viewModel.timetableSyncInfo }
    private var fallbackText: String { info.hasCache ? L10n.Sync.savedTimetable : L10n.Sync.bundledTimetable }

    var body: some View {
        if viewModel.hasTimetableAPI {
            HStack(alignment: .top, spacing: 12) {
              VStack(alignment: .leading, spacing: 8) {
                switch info.connection {
                case .offline:
                    Label(L10n.Sync.offline + " · " + fallbackText, systemImage: "wifi.slash")
                        .accessibilityIdentifier("timetable-offline-status")
                case .unavailable:
                    Label(L10n.Sync.failed + " · " + fallbackText, systemImage: "exclamationmark.triangle.fill")
                        .accessibilityIdentifier("timetable-sync-error")
                case .syncing:
                    Label(L10n.Sync.updating, systemImage: "arrow.triangle.2.circlepath")
                case .current, .cached:
                    if info.didUpdate {
                        Label(L10n.Sync.updated, systemImage: "checkmark.circle.fill")
                            .accessibilityIdentifier("timetable-update-notice")
                    }
                }

                if let date = info.verifiedAt {
                    Text(L10n.Sync.lastUpdated(date.formatted(date: .abbreviated, time: .shortened)))
                        .accessibilityIdentifier("timetable-last-updated")
                } else if info.connection == .cached || info.connection == .syncing {
                    Text(fallbackText)
                }

                if info.isStale(at: AppDate.now()) {
                    Label(L10n.Sync.stale, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(sky.warning)
                        .accessibilityIdentifier("timetable-stale-warning")
                }
              }
              Spacer(minLength: 0)
              Button {
                  Task { await viewModel.refreshTimetables() }
              } label: {
                  Image(systemName: "arrow.clockwise")
                      .frame(minWidth: 44, minHeight: 44)
              }
              .accessibilityLabel(L10n.Sync.refresh)
              .disabled(info.connection == .syncing)
            }
            .dynamicFont(size: 12, relativeTo: .caption, weight: .medium)
            .foregroundStyle(sky.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .skyCard(padding: 14)
        }
    }
}
