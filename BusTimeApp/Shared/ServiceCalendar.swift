import Foundation

/// バスの運行判定で使う日本時間の暦です。
/// 端末が海外のタイムゾーンにあっても、現地の運行日と時刻が変わらないようにします。
enum AppCalendar {
    static let timeZone = TimeZone(identifier: "Asia/Tokyo")!

    static var japan: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = timeZone
        return calendar
    }
}

/// 土日と内閣府が公表する国民の祝日・休日を運休日として判定します。
enum BusServiceCalendar {
    /// 公式データを確認済みの最終日です。期限をテストとCIで監視します。
    static let holidayDataValidThrough = DateComponents(
        calendar: AppCalendar.japan,
        timeZone: AppCalendar.timeZone,
        year: 2027,
        month: 12,
        day: 31
    ).date!

    /// 内閣府「国民の祝日について」のCSVを基にした祝日・休日です。
    /// https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv
    private static let publicHolidays: Set<String> = [
        "2025-01-01", "2025-01-13", "2025-02-11", "2025-02-23", "2025-02-24",
        "2025-03-20", "2025-04-29", "2025-05-03", "2025-05-04", "2025-05-05",
        "2025-05-06", "2025-07-21", "2025-08-11", "2025-09-15", "2025-09-23",
        "2025-10-13", "2025-11-03", "2025-11-23", "2025-11-24",
        "2026-01-01", "2026-01-12", "2026-02-11", "2026-02-23", "2026-03-20",
        "2026-04-29", "2026-05-03", "2026-05-04", "2026-05-05", "2026-05-06",
        "2026-07-20", "2026-08-11", "2026-09-21", "2026-09-22", "2026-09-23",
        "2026-10-12", "2026-11-03", "2026-11-23",
        "2027-01-01", "2027-01-11", "2027-02-11", "2027-02-23", "2027-03-21",
        "2027-03-22", "2027-04-29", "2027-05-03", "2027-05-04", "2027-05-05",
        "2027-07-19", "2027-08-11", "2027-09-20", "2027-09-23", "2027-10-11",
        "2027-11-03", "2027-11-23"
    ]

    static func suspensionReason(
        for date: Date,
        calendar: Calendar = AppCalendar.japan
    ) -> String? {
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let weekday = components.weekday else {
            return nil
        }

        if weekday == 1 || weekday == 7 {
            return L10n.Holiday.weekend
        }

        let key = String(format: "%04d-%02d-%02d", year, month, day)
        return publicHolidays.contains(key) ? L10n.Holiday.publicHoliday : nil
    }

    static func isServiceDay(
        _ date: Date,
        calendar: Calendar = AppCalendar.japan
    ) -> Bool {
        suspensionReason(for: date, calendar: calendar) == nil
    }

    static func daysUntilHolidayDataExpires(
        from date: Date,
        calendar: Calendar = AppCalendar.japan
    ) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: holidayDataValidThrough)
        ).day ?? 0
    }
}
