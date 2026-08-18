import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "BusTimeApp"

    static let location = Logger(subsystem: subsystem, category: "location")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let performance = Logger(subsystem: subsystem, category: "performance")
    static let weather = Logger(subsystem: subsystem, category: "weather")
}
