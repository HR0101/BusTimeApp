import Foundation

/// 端末の時刻表記を保ち、数字の直後のAM/PMだけを通常の空白で区切ります。
enum TimeDisplayFormatter {
    static func string(
        from date: Date, locale: Locale = .current, calendar: Calendar = AppCalendar.japan
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let value = formatter.string(from: date)
        for symbol in [formatter.amSymbol, formatter.pmSymbol].compactMap({ $0 }) where !symbol.isEmpty {
            guard value.hasSuffix(symbol) else { continue }
            let prefix = String(value.dropLast(symbol.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if prefix.last?.isNumber == true {
                return prefix + " " + symbol
            }
        }
        return value
    }
}
