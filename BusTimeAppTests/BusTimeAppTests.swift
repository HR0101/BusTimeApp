//
//  BusTimeAppTests.swift
//  BusTimeAppTests
//
//  Created by hara ryuto   on 2025/06/13.
//

import Foundation
import CoreLocation
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
        coordinator.send(.dismiss)
        coordinator.send(.changeDesignMode(.minimalCute))
        #expect(coordinator.designMode == .minimalCute)
        #expect(defaults.string(forKey: "appDesignMode") == AppDesignMode.minimalCute.rawValue)
        coordinator.send(.changeDesignMode(.maximalism))
        #expect(coordinator.designMode == .maximalism)
        #expect(defaults.string(forKey: "appDesignMode") == AppDesignMode.maximalism.rawValue)
    }

    @Test
    func notificationTimeUsesServiceDayBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let beforeBoundary = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 11, hour: 3, minute: 0)
        )!
        let currentServiceDay = BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
            for: "0:04",
            from: beforeBoundary,
            calendar: calendar
        )!
        #expect(calendar.component(.day, from: currentServiceDay) == 11)
        #expect(calendar.component(.hour, from: currentServiceDay) == 0)
        #expect(calendar.component(.minute, from: currentServiceDay) == 4)

        let nextDeparture = BusNotificationTimeCalculator.nextDepartureDate(
            for: "0:04",
            from: beforeBoundary,
            calendar: calendar
        )!
        #expect(calendar.component(.day, from: nextDeparture) == 12)

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

    @Test
    func currentServiceDayDepartureDoesNotRollToTomorrow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 11, hour: 8, minute: 5)
        )!

        let currentServiceDayDeparture = BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
            for: "8:00",
            from: now,
            calendar: calendar
        )!
        let nextDeparture = BusNotificationTimeCalculator.nextDepartureDate(
            for: "8:00",
            from: now,
            calendar: calendar
        )!

        #expect(calendar.component(.day, from: currentServiceDayDeparture) == 11)
        #expect(currentServiceDayDeparture < now)
        #expect(calendar.component(.day, from: nextDeparture) == 12)
    }

    @Test
    func currentServiceDayKeepsAfterMidnightBusOnTheCorrectDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let beforeDeparture = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 11, hour: 0, minute: 10)
        )!

        let departure = BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
            for: "0:13",
            from: beforeDeparture,
            calendar: calendar
        )!

        #expect(calendar.component(.day, from: departure) == 11)
        #expect(calendar.component(.hour, from: departure) == 0)
        #expect(calendar.component(.minute, from: departure) == 13)
        #expect(departure > beforeDeparture)
    }

    @Test
    func liveActivityRemainingTimeOmitsSeconds() {
        let now = Date(timeIntervalSince1970: 0)

        #expect(
            BusRemainingTimeFormatter.string(
                until: now.addingTimeInterval(27 * 60 + 15),
                now: now
            ) == "27分"
        )
        #expect(
            BusRemainingTimeFormatter.string(
                until: now.addingTimeInterval(60 * 60 + 27 * 60 + 15),
                now: now
            ) == "1時間27分"
        )
        #expect(
            BusRemainingTimeFormatter.string(
                until: now.addingTimeInterval(2 * 60 * 60),
                now: now
            ) == "2時間"
        )
        #expect(
            BusRemainingTimeFormatter.string(
                until: now.addingTimeInterval(59),
                now: now
            ) == "1分未満"
        )
        #expect(
            BusRemainingTimeFormatter.string(until: now, now: now) == "出発済み"
        )
    }

    @Test @MainActor
    func liveActivityDefaultsOnWhenAvailableAndPersistsChanges() {
        let suiteName = "BusTimeAppTests.LiveActivityPreference"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let defaultViewModel = SettingsViewModel(
            defaults: defaults,
            liveActivityAvailability: { true }
        )
        #expect(defaultViewModel.prefersLiveActivity)
        #expect(defaultViewModel.shouldUseLiveActivity)

        defaultViewModel.setLiveActivityEnabled(false)
        let restoredViewModel = SettingsViewModel(
            defaults: defaults,
            liveActivityAvailability: { true }
        )
        #expect(!restoredViewModel.prefersLiveActivity)
        #expect(!restoredViewModel.shouldUseLiveActivity)
    }

    @Test @MainActor
    func liveActivityDefaultsOffWhenUnavailable() {
        let suiteName = "BusTimeAppTests.LiveActivityUnavailable"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = SettingsViewModel(
            defaults: defaults,
            liveActivityAvailability: { false }
        )
        #expect(!viewModel.prefersLiveActivity)
        #expect(!viewModel.shouldUseLiveActivity)
    }

    @Test
    func notificationIdentifiersAreUniqueForEachBus() {
        let first = BusNotificationIdentifier.value(for: "8:00-station")
        let second = BusNotificationIdentifier.value(for: "8:10-station")

        #expect(first == "bus_notification_8:00-station")
        #expect(first != second)
    }

    @Test
    func designModesUseFamiliarNames() {
        #expect(AppDesignMode.neumorphic.title == "シンプル")
        #expect(AppDesignMode.claymorphic.title == "カラフル")
        #expect(AppDesignMode.minimalCute.title == "やさしいモノクロ")
        #expect(AppDesignMode.maximalism.title == "ネオンポップ")
        #expect(AppDesignMode.neumorphic.description.contains("落ち着いた"))
        #expect(AppDesignMode.claymorphic.description.contains("明るく"))
        #expect(AppDesignMode.minimalCute.description.contains("白黒"))
        #expect(AppDesignMode.maximalism.description.contains("鮮やかな緑"))
        #expect(AppDesignMode.allCases.count == 4)
    }

    @Test
    func routeIsResolvedFromOriginAndDestination() {
        #expect(
            HomeViewModel.Route.route(from: .station, to: .mansion)
                == .stationToMansion
        )
        #expect(
            HomeViewModel.Route.route(from: .mansion, to: .yokado)
                == .mansionToYokado
        )
        #expect(
            HomeViewModel.Route.route(from: .yokado, to: .station)
                == nil
        )
    }

    @Test
    func routeAndSearchLabelsExplainTheirMeaning() {
        #expect(HomeViewModel.Route.stationToMansion.guidance.contains("ヨーカドー前"))
        #expect(HomeViewModel.SearchType.departure.timeTitle.contains("以降"))
        #expect(HomeViewModel.SearchType.arrival.timeTitle.contains("まで"))
    }

    @Test @MainActor
    func yokadoIsRemovedAfterItsLastBusForTheCurrentOrigin() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var currentDate = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 12, hour: 16, minute: 29)
        )!
        let viewModel = HomeViewModel(nowProvider: { currentDate })

        #expect(viewModel.availableDestinations.contains(.yokado))
        viewModel.selectDestination(.yokado)
        #expect(viewModel.selectedRoute == .mansionToYokado)

        currentDate = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 12, hour: 16, minute: 30)
        )!
        viewModel.refreshRouteAvailability(at: currentDate)

        #expect(!viewModel.availableDestinations.contains(.yokado))
        #expect(viewModel.selectedRoute == .mansionToStation)
        #expect(viewModel.routeAvailabilityMessage?.contains("候補から外しました") == true)
    }

    @Test @MainActor
    func currentLocationDoesNotSelectYokadoAfterTheLastDeparture() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let beforeLastBus = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 12, hour: 16, minute: 45)
        )!
        let afterLastBus = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 12, hour: 16, minute: 47)
        )!
        let yokadoLocation = CLLocation(latitude: 35.6569440, longitude: 140.0510100)

        let beforeViewModel = HomeViewModel(nowProvider: { beforeLastBus })
        beforeViewModel.updateOriginForCurrentLocation(yokadoLocation, at: beforeLastBus)
        #expect(beforeViewModel.selectedOrigin == .yokado)
        #expect(beforeViewModel.selectedRoute == .yokadoToMansion)

        let afterViewModel = HomeViewModel(nowProvider: { afterLastBus })
        afterViewModel.updateOriginForCurrentLocation(yokadoLocation, at: afterLastBus)
        #expect(afterViewModel.selectedOrigin != .yokado)
        #expect(!afterViewModel.availableOrigins.contains(.yokado))
        #expect(afterViewModel.routeAvailabilityMessage?.contains("終了") == true)

        let nextServiceDay = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 13, hour: 4, minute: 0)
        )!
        afterViewModel.refreshRouteAvailability(at: nextServiceDay)
        #expect(afterViewModel.availableOrigins.contains(.yokado))
        #expect(afterViewModel.routeAvailabilityMessage == nil)
    }

    @Test @MainActor
    func currentLocationSelectsTheNextAvailableRouteAfterYokadoServiceEnds() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let afterYokadoService = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 12, hour: 16, minute: 47)
        )!
        let stationLocation = CLLocation(latitude: 35.6485608, longitude: 140.0416924)
        let viewModel = HomeViewModel(nowProvider: { afterYokadoService })

        viewModel.updateOriginForCurrentLocation(stationLocation, at: afterYokadoService)

        #expect(viewModel.selectedOrigin == .station)
        #expect(viewModel.selectedDestination == .mansion)
        #expect(viewModel.selectedRoute == .stationToMansion)
        #expect(!viewModel.availableDestinations.contains(.yokado))
    }

}
