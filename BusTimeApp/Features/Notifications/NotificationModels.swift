import Foundation

enum BusNotificationPermission: Equatable {
    case notDetermined
    case authorized
    case denied

    var title: String {
        switch self {
        case .notDetermined:
            return L10n.Permission.notDetermined
        case .authorized:
            return L10n.Permission.authorized
        case .denied:
            return L10n.Permission.denied
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
            return L10n.ScheduleError.notPermitted
        case .invalidDeparture:
            return L10n.ScheduleError.noDeparture
        case .tooLate:
            return L10n.ScheduleError.tooLate
        case .registrationFailed:
            return L10n.ScheduleError.unknown
        }
    }
}

struct ScheduledBusNotification: Identifiable, Codable, Equatable {
    let id: String
    let busID: String
    let originName: String
    let destinationName: String
    let stopSummary: String?
    let departure: String
    let routeName: String
    let departureDate: Date
    let notificationDate: Date
    let minutesBefore: Int

    var busDescription: String {
        L10n.Notify.busDescription(departure, stopSummary ?? "\(originName) → \(destinationName)")
    }

    var notificationDescription: String {
        L10n.Notify.minutesBefore(
            minutesBefore,
            BusNotificationTimeCalculator.displayString(notificationDate)
        )
    }
}

enum BusNotificationIdentifier {
    static func value(for busID: String) -> String {
        "bus_notification_\(busID)"
    }
}

/// バスが走る日かどうかを判定します。
///
/// 土日と祝日は全便運休です。時刻表は平日ダイヤの1種類しかないため、
/// 「その日に走るかどうか」だけを見れば足ります。
/// 画面の案内と通知の時刻計算で同じ判定を使うため、ここにまとめています。
enum BusServiceCalendar {
    /// 運休となる祝日の一覧です。
    private static let publicHolidays: Set<String> = [
        "2025-01-01", "2025-01-13", "2025-02-11", "2025-02-23", "2025-03-20",
        "2025-04-29", "2025-05-03", "2025-05-04", "2025-05-05", "2025-07-21",
        "2025-08-11", "2025-09-15", "2025-09-23", "2025-10-13", "2025-11-03",
        "2025-11-23", "2025-12-23"
    ]

    /// その日が運休になる理由です。運行日であればnilを返します。
    static func suspensionReason(for date: Date, calendar: Calendar = .current) -> String? {
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let weekday = components.weekday else {
            return nil
        }

        // 1が日曜、7が土曜です。
        if weekday == 1 || weekday == 7 {
            return L10n.Holiday.weekend
        }

        let key = String(format: "%04d-%02d-%02d", year, month, day)
        return publicHolidays.contains(key) ? L10n.Holiday.publicHoliday : nil
    }

    /// その日にバスが走るかどうかです。
    static func isServiceDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        suspensionReason(for: date, calendar: calendar) == nil
    }
}

/// 時刻表の「午前4時を運行日の境目とする」ルールを通知にも適用します。
/// これにより、深夜0〜3時台の便を通常の暦日だけで判定するずれを防ぎます。
enum BusNotificationTimeCalculator {
    static let serviceDayBoundaryHour = 4

    /// `now` が属する運行日（午前4時区切り）における出発日時を返します。
    /// 出発済みでも翌日に繰り越さないため、選択中の便そのものの判定に使用できます。
    static func departureDateForCurrentServiceDay(
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

        guard let targetDay else { return nil }
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: targetDay
        )
    }

    /// その日時が属する運行日の起点（午前4時）を返します。
    static func serviceDayStart(for date: Date, calendar: Calendar = .current) -> Date? {
        guard let boundary = calendar.date(
            bySettingHour: serviceDayBoundaryHour,
            minute: 0,
            second: 0,
            of: date
        ) else {
            return nil
        }

        return date >= boundary
            ? boundary
            : calendar.date(byAdding: .day, value: -1, to: boundary)
    }

    /// 次にその便が実際に走る日時を返します。
    ///
    /// 単純に翌日へ繰り越すと、土日や祝日など運休の日を指してしまい、
    /// 走らない日に通知が鳴ります。そのため運行日が見つかるまで日を進めます。
    /// 深夜0〜3時台の便は前日の運行日に属するため、暦日ではなく運行日で判定します。
    static func nextDepartureDate(
        for departure: String,
        from now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        for offset in 0...maximumDaysToFindServiceDay {
            guard let reference = calendar.date(byAdding: .day, value: offset, to: now),
                  let candidate = departureDateForCurrentServiceDay(
                    for: departure,
                    from: reference,
                    calendar: calendar
                  ),
                  candidate > now,
                  let serviceDay = serviceDayStart(for: candidate, calendar: calendar),
                  BusServiceCalendar.isServiceDay(serviceDay, calendar: calendar) else {
                continue
            }
            return candidate
        }
        return nil
    }

    /// 次の運行日を探すときに、何日先まで見るかです。
    /// 連休が続いても必ず見つかる長さにしています。
    private static let maximumDaysToFindServiceDay = 14

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
        formatter.dateFormat = L10n.Notify.dateFormat
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
