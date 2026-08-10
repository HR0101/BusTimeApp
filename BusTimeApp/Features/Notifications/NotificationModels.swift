import Foundation

enum BusNotificationPermission: Equatable {
    case notDetermined
    case authorized
    case denied

    var title: String {
        switch self {
        case .notDetermined:
            return "まだ確認していません"
        case .authorized:
            return "通知は許可されています"
        case .denied:
            return "通知が許可されていません"
        }
    }

    var isAuthorized: Bool {
        self == .authorized
    }
}

enum BusNotificationSchedulingError: LocalizedError, Equatable {
    case permissionDenied
    case invalidDeparture
    case tooLate
    case registrationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "通知が許可されていません。iPhoneの設定で「BusTime」の通知をオンにしてください。"
        case .invalidDeparture:
            return "バスの出発時刻を確認できませんでした。別の便を選んでください。"
        case .tooLate:
            return "この便は通知時刻がすでに過ぎています。もう少し先の便を選んでください。"
        case .registrationFailed:
            return "通知を設定できませんでした。もう一度お試しください。"
        }
    }
}

struct ScheduledBusNotification: Identifiable, Codable, Equatable {
    let id: String
    let busID: String
    let originName: String
    let destinationName: String
    let departure: String
    let routeName: String
    let departureDate: Date
    let notificationDate: Date
    let minutesBefore: Int

    var busDescription: String {
        "(originName) (departure)発 → (destinationName)"
    }

    var notificationDescription: String {
        "\(minutesBefore)分前（\(BusNotificationTimeCalculator.displayString(notificationDate))）"
    }
}

/// 時刻表の「午前4時を運行日の境目とする」ルールを通知にも適用します。
/// これにより、深夜0〜3時台の便を通常の暦日だけで判定するずれを防ぎます。
enum BusNotificationTimeCalculator {
    static let serviceDayBoundaryHour = 4

    static func nextDepartureDate(
        for departure: String,
        from now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard let (hour, minute) = timeComponents(from: departure),
              let boundaryToday = calendar.date(
                bySettingHour: serviceDayBoundaryHour,
                minute: 0,
                second: 0,
                of: now
              ) else {
            return nil
        }

        let serviceDayStart = now >= boundaryToday
            ? boundaryToday
            : calendar.date(byAdding: .day, value: -1, to: boundaryToday)

        guard let serviceDayStart else { return nil }

        let targetDay = hour < serviceDayBoundaryHour
            ? calendar.date(byAdding: .day, value: 1, to: serviceDayStart)
            : serviceDayStart

        guard let targetDay,
              var target = calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: targetDay
              ) else {
            return nil
        }

        if target <= now {
            guard let nextServiceDay = calendar.date(byAdding: .day, value: 1, to: serviceDayStart) else {
                return nil
            }
            let nextTargetDay = hour < serviceDayBoundaryHour
                ? calendar.date(byAdding: .day, value: 1, to: nextServiceDay)
                : nextServiceDay
            guard let nextTargetDay,
                  let nextTarget = calendar.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: nextTargetDay
                  ) else {
                return nil
            }
            target = nextTarget
        }

        return target
    }

    static func notificationDate(
        for departure: String,
        minutesBefore: Int,
        from now: Date,
        calendar: Calendar = .current
    ) -> (departureDate: Date, notificationDate: Date)? {
        guard minutesBefore >= 0,
              let departureDate = nextDepartureDate(for: departure, from: now, calendar: calendar),
              let notificationDate = calendar.date(
                byAdding: .minute,
                value: -minutesBefore,
                to: departureDate
              ) else {
            return nil
        }

        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let nowWithoutSeconds = calendar.date(from: nowComponents) ?? now
        guard notificationDate >= nowWithoutSeconds else { return nil }

        return (departureDate, notificationDate)
    }

    static func displayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E) H:mm"
        return formatter.string(from: date)
    }

    private static func timeComponents(from value: String) -> (hour: Int, minute: Int)? {
        let components = value.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2,
              (0...23).contains(components[0]),
              (0...59).contains(components[1]) else {
            return nil
        }
        return (components[0], components[1])
    }
}
