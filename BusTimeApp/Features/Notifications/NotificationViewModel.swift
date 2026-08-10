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
    private let storageKey = "scheduledBusNotifications"

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
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
        now: Date = Date(),
        completion: @escaping (Result<ScheduledBusNotification, BusNotificationSchedulingError>) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let permission = await resolvePermission()
            guard permission.isAuthorized else {
                completion(.failure(.permissionDenied))
                return
            }

            guard let scheduledDates = BusNotificationTimeCalculator.notificationDate(
                for: bus.departure,
                minutesBefore: minutesBefore,
                from: now
            ) else {
                completion(.failure(.tooLate))
                return
            }

            let item = ScheduledBusNotification(
                id: notificationIdentifier(for: bus.id),
                busID: bus.id,
                originName: bus.originName,
                destinationName: bus.destinationName,
                departure: bus.departure,
                routeName: routeName,
                departureDate: scheduledDates.departureDate,
                notificationDate: scheduledDates.notificationDate,
                minutesBefore: minutesBefore
            )

            let content = UNMutableNotificationContent()
            content.title = "バスの時間をお知らせします"
            content.body = "\(item.busDescription)が、あと\(minutesBefore)分で出発します。\n※時刻表の予定です。遅延・運休は反映されません。"
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: item.notificationDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)

            center.add(request) { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    if error != nil {
                        completion(.failure(.registrationFailed))
                        return
                    }

                    self.upsert(item)
                    completion(.success(item))
                }
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
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
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

    private func notificationIdentifier(for busID: String) -> String {
        "bus_notification_(busID)"
    }

    private func loadNotifications() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ScheduledBusNotification].self, from: data) else {
            scheduledNotifications = []
            return
        }

        let now = Date()
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
        guard let data = try? JSONEncoder().encode(scheduledNotifications) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
