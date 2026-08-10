//
//  BusTimeAppTests.swift
//  BusTimeAppTests
//
//  Created by hara ryuto   on 2025/06/13.
//

import Foundation
import Testing
@testable import BusTimeApp

struct BusTimeAppTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func homeStateMachineTransitions() {
        var machine = HomeStateMachine()

        #expect(machine.state == .idle)
        machine.send(.searchStarted)
        #expect(machine.state == .searching)
        machine.send(.searchSucceeded(hasResults: true))
        #expect(machine.state == .ready)
        machine.send(.searchSucceeded(hasResults: false))
        #expect(machine.state == .empty)
        machine.send(.serviceUnavailable("運休"))
        #expect(machine.state == .serviceUnavailable("運休"))
    }

    @Test @MainActor
    func appCoordinatorTransitions() {
        let suiteName = "BusTimeAppTests.AppCoordinator"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = AppCoordinator(defaults: defaults)
        coordinator.send(.showSettings)
        #expect(coordinator.state == .settings)
        coordinator.send(.dismiss)
        #expect(coordinator.state == .dashboard)
        coordinator.send(.showTutorial)
        #expect(coordinator.state == .tutorial)
    }

    @Test
    func notificationTimeUsesServiceDayBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let beforeBoundary = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 11, hour: 3, minute: 0)
        )!
        let sameServiceDay = BusNotificationTimeCalculator.nextDepartureDate(
            for: "0:04",
            from: beforeBoundary,
            calendar: calendar
        )!
        #expect(calendar.component(.day, from: sameServiceDay) == 11)
        #expect(calendar.component(.hour, from: sameServiceDay) == 0)
        #expect(calendar.component(.minute, from: sameServiceDay) == 4)

        let afterBoundary = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 11, hour: 5, minute: 0)
        )!
        let nextServiceDay = BusNotificationTimeCalculator.nextDepartureDate(
            for: "0:04",
            from: afterBoundary,
            calendar: calendar
        )!
        #expect(calendar.component(.day, from: nextServiceDay) == 12)
        #expect(calendar.component(.hour, from: nextServiceDay) == 0)
    }

    @Test
    func notificationTimeCannotBeScheduledInThePast() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 11, hour: 7, minute: 55)
        )!

        let schedule = BusNotificationTimeCalculator.notificationDate(
            for: "8:00",
            minutesBefore: 10,
            from: now,
            calendar: calendar
        )
        #expect(schedule == nil)
    }

}
