import SwiftUI
import WidgetKit

/// ウィジェットの見た目です。置ける場所に合わせて中身を出し分けます。
struct NextBusWidgetView: View {
  @Environment(\.widgetFamily) private var family

  let entry: NextBusEntry

  var body: some View {
    switch family {
    case .accessoryRectangular:
      LockScreenView(entry: entry)
    case .systemSmall:
      SmallView(entry: entry)
    default:
      MediumView(entry: entry)
    }
  }
}

// MARK: - 中サイズ

/// 次の便とその次の便を1行ずつ並べます。
private struct MediumView: View {
  let entry: NextBusEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      RouteHeader(route: entry.route, isFromLocation: entry.isFromLocation)

      Spacer(minLength: 0)

      if let next = entry.next {
        DepartureRow(
          label: L10n.Widget.nextLabel,
          departure: next,
          isPrimary: true,
          now: entry.date
        )
      } else {
        Text(L10n.Widget.noService)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      if let following = entry.following {
        DepartureRow(
          label: L10n.Widget.followingLabel,
          departure: following,
          isPrimary: false,
          now: entry.date
        )
      }

      Spacer(minLength: 0)
    }
  }
}

/// 1本の便を「次 6:03 → 6:11 出発まで◯分」の形で並べます。
private struct DepartureRow: View {
  let label: String
  let departure: BusSchedule.UpcomingBus
  /// 次の便かどうかです。次の便だけ大きく、残り時間も添えます。
  let isPrimary: Bool
  /// この表示が表している時刻です。残り時間はここから数えます。
  let now: Date

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(width: 36, alignment: .leading)

      Text(departure.departure)
        .font(isPrimary ? .title2.bold() : .body.weight(.medium))
        .monospacedDigit()

      Image(systemName: "arrow.right")
        .font(.caption2)
        .foregroundStyle(.secondary)

      Text(departure.arrival)
        .font(isPrimary ? .body.weight(.medium) : .caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)

      Spacer(minLength: 4)

      if isPrimary {
        RemainingTimeText(departureDate: departure.departureDate, now: now)
          .font(.caption.bold())
          .foregroundStyle(.tint)
      }
    }
  }
}

// MARK: - 小サイズ

/// 場所が狭いので、次の便を大きく出し、その次は1行だけ添えます。
private struct SmallView: View {
  let entry: NextBusEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      RouteHeader(route: entry.route, isFromLocation: entry.isFromLocation)

      if let next = entry.next {
        Text(next.departure)
          .font(.system(size: 34, weight: .bold, design: .rounded))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.6)

        RemainingTimeText(departureDate: next.departureDate, now: entry.date)
          .font(.caption2.bold())
          .foregroundStyle(.tint)
      } else {
        Text(L10n.Widget.noService)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)

      if let following = entry.following {
        Divider()
        HStack(spacing: 4) {
          Text(L10n.Widget.followingLabel)
            .foregroundStyle(.secondary)
          Text(following.departure)
            .monospacedDigit()
        }
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      }
    }
  }
}

// MARK: - ロック画面

/// ロック画面は色を使えないので、文字の並びだけで伝えます。
private struct LockScreenView: View {
  let entry: NextBusEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(entry.route.rawValue)
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.6)

      if let next = entry.next {
        HStack(spacing: 4) {
          Text(next.departure)
            .font(.headline)
            .monospacedDigit()
          RemainingTimeText(departureDate: next.departureDate, now: entry.date)
            .font(.caption2)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)

        if let following = entry.following {
          HStack(spacing: 4) {
            Text(L10n.Widget.followingLabel)
            Text(following.departure)
              .monospacedDigit()
          }
          .font(.caption2)
          .lineLimit(1)
        }
      } else {
        Text(L10n.Widget.noService)
          .font(.caption2)
      }
    }
  }
}

// MARK: - 共通の部品

/// 出発までの時間です。アプリと同じく、秒は出さず時間と分で示します。
private struct RemainingTimeText: View {
  let departureDate: Date
  let now: Date

  var body: some View {
    Text(BusRemainingTimeFormatter.string(until: departureDate, now: now))
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(0.7)
  }
}

/// どの経路を出しているかと、それがどう決まったかを示します。
private struct RouteHeader: View {
  let route: BusRoute
  let isFromLocation: Bool

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: isFromLocation ? "location.fill" : "bus.fill")
        .font(.caption2)
        .foregroundStyle(.tint)

      Text(route.rawValue)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
  }
}
