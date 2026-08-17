import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
final class NotificationViewModel: ObservableObject {
    @Published private(set) var scheduledNotifications: [ScheduledBusNotification] = []
    @Published private(set) var permissionStatus: BusNotificationPermission = .notDetermined

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let storageKey = "scheduledBusNotifications"

    private struct StoredNotifications: Codable {
        let version: Int
        let notifications: [ScheduledBusNotification]
    }

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard,
        calendar: Calendar = AppCalendar.japan
    ) {
        self.center = center
        self.defaults = defaults
        self.calendar = calendar
        loadNotifications()
        refreshPermissionStatus()
    }

    func refresh() {
        loadNotifications()
        refreshPermissionStatus()
    }

    func notification(for busID: String) -> ScheduledBusNotification? {
        scheduledNotifications.first { $0.busID == busID }
    }

    func scheduleNotification(
        for bus: Bus,
        routeName: String,
        minutesBefore: Int,
        now: Date = AppDate.now(),
        completion: @escaping (Result<ScheduledBusNotification, BusNotificationSchedulingError>) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let permission = await resolvePermission()
            guard permission.isAuthorized else {
                completion(.failure(.permissionDenied))
                return
            }

            guard BusNotificationTimeCalculator.nextDepartureDate(
                for: bus.departure,
                from: now,
                calendar: calendar
            ) != nil else {
                completion(.failure(.invalidDeparture))
                return
            }

            guard let scheduledDates = BusNotificationTimeCalculator.notificationDate(
                for: bus.departure,
                minutesBefore: minutesBefore,
                from: now,
                calendar: calendar
            ) else {
                completion(.failure(.tooLate))
                return
            }

            let item = ScheduledBusNotification(
                id: BusNotificationIdentifier.value(for: bus.id),
                busID: bus.id,
                originName: bus.originName,
                destinationName: bus.destinationName,
                stopSummary: bus.stopSummary,
                departure: bus.departure,
                routeName: routeName,
                departureDate: scheduledDates.departureDate,
                notificationDate: scheduledDates.notificationDate,
                minutesBefore: minutesBefore
            )

            let content = UNMutableNotificationContent()
            content.title = L10n.Notify.pushTitle
            content.body = L10n.Notify.pushBody(item.busDescription, minutesBefore)
            content.sound = .default

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: item.notificationDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)

            do {
                try await center.add(request)
                upsert(item)
                completion(.success(item))
            } catch {
                AppLogger.notifications.error(
                    "Notification registration failed: \(error.localizedDescription, privacy: .public)"
                )
                completion(.failure(.registrationFailed))
            }
        }
    }

    func cancelNotification(for item: ScheduledBusNotification) {
        center.removePendingNotificationRequests(withIdentifiers: [item.id])
        scheduledNotifications.removeAll { $0.id == item.id }
        persistNotifications()
    }

    func cancelNotification(for busID: String) {
        guard let item = notification(for: busID) else { return }
        cancelNotification(for: item)
    }

    func cancelAllNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: scheduledNotifications.map(\.id))
        scheduledNotifications.removeAll()
        persistNotifications()
    }

    func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func refreshPermissionStatus() {
        center.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.permissionStatus = Self.permissionStatus(from: settings.authorizationStatus)
            }
        }
    }

    private func resolvePermission() async -> BusNotificationPermission {
        let currentSettings = await notificationSettings()
        var status = Self.permissionStatus(from: currentSettings.authorizationStatus)

        if status == .notDetermined {
            _ = await requestAuthorization()
            let updatedSettings = await notificationSettings()
            status = Self.permissionStatus(from: updatedSettings.authorizationStatus)
        }

        permissionStatus = status
        return status
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    AppLogger.notifications.error(
                        "Notification permission request failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
                continuation.resume(returning: granted)
            }
        }
    }

    private static func permissionStatus(
        from authorizationStatus: UNAuthorizationStatus
    ) -> BusNotificationPermission {
        switch authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    private func loadNotifications() {
        guard let data = defaults.data(forKey: storageKey) else {
            scheduledNotifications = []
            return
        }

        let decoder = JSONDecoder()
        let decoded: [ScheduledBusNotification]
        do {
            if let stored = try? decoder.decode(StoredNotifications.self, from: data),
               stored.version == 1 {
                decoded = stored.notifications
            } else {
                // v0は配列を直接保存していました。読み込めたらv1へ移行します。
                decoded = try decoder.decode([ScheduledBusNotification].self, from: data)
                AppLogger.persistence.info("Migrating notification storage from v0 to v1")
            }
        } catch {
            scheduledNotifications = []
            AppLogger.persistence.error("Notification storage could not be decoded")
            return
        }

        let now = AppDate.now()
        scheduledNotifications = decoded
            .filter { $0.notificationDate >= now }
            .sorted { $0.notificationDate < $1.notificationDate }
        persistNotifications()
    }

    private func upsert(_ item: ScheduledBusNotification) {
        scheduledNotifications.removeAll { $0.busID == item.busID }
        scheduledNotifications.append(item)
        scheduledNotifications.sort { $0.notificationDate < $1.notificationDate }
        persistNotifications()
    }

    private func persistNotifications() {
        do {
            let stored = StoredNotifications(version: 1, notifications: scheduledNotifications)
            defaults.set(try JSONEncoder().encode(stored), forKey: storageKey)
        } catch {
            AppLogger.persistence.error("Notification storage could not be encoded")
        }
    }
}
