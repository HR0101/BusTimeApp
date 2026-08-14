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
        #expect(coordinator.state == .dashboard)
        coordinator.send(.showNotifications)
        #expect(coordinator.state == .notifications)
        coordinator.send(.dismiss)
        #expect(coordinator.state == .dashboard)
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
    func skyPaletteSwitchesBetweenDayAndNight() {
        // 昼は明るい空なので暗い文字、夜は暗い空なので明るい文字になります。
        #expect(SkyPalette.at(hour: 12).isNight == false)
        #expect(SkyPalette.at(hour: 23).isNight == true)
        #expect(SkyPalette.at(hour: 3).isNight == true)
        #expect(SkyPalette.at(hour: 8).isNight == false)
    }

    @Test
    func skyPaletteIsContinuousAcrossMidnight() {
        // 0時と24時は同じキーフレームなので、日付をまたいでも色が飛びません。
        #expect(SkyPalette.at(hour: 0) == SkyPalette.at(hour: 24))
        // 範囲外の時刻は24時間周期に丸められます。
        #expect(SkyPalette.at(hour: 25) == SkyPalette.at(hour: 1))
        #expect(SkyPalette.at(hour: -1) == SkyPalette.at(hour: 23))
    }

    @Test
    func celestialPositionStaysWithinScreen() {
        // 太陽・月の位置は画面内に収まる0〜1の範囲で表されます。
        for tick in 0...96 {
            let hour = Double(tick) / 4
            let palette = SkyPalette.at(hour: hour)
            #expect(palette.celestialProgress >= 0)
            #expect(palette.celestialProgress <= 1)
            #expect(palette.celestialAltitude >= 0)
            #expect(palette.celestialAltitude <= 1)
        }
    }

    @Test
    func weatherCodeIdentifiesRainOnly() {
        // 晴れや曇りは雨として扱いません。
        #expect(WeatherCodeInterpreter.isRaining(code: 0) == false)
        #expect(WeatherCodeInterpreter.isRaining(code: 3) == false)
        #expect(WeatherCodeInterpreter.isRaining(code: 45) == false)
        // 雪とあられも対象外です。
        #expect(WeatherCodeInterpreter.isRaining(code: 71) == false)
        #expect(WeatherCodeInterpreter.isRaining(code: 85) == false)
        // 霧雨・雨・にわか雨・雷雨は雨として扱います。
        #expect(WeatherCodeInterpreter.isRaining(code: 51) == true)
        #expect(WeatherCodeInterpreter.isRaining(code: 63) == true)
        #expect(WeatherCodeInterpreter.isRaining(code: 80) == true)
        #expect(WeatherCodeInterpreter.isRaining(code: 95) == true)
    }

    @Test
    func rainIntensityFollowsPrecipitation() {
        #expect(WeatherCodeInterpreter.weather(code: 61, precipitation: 0.2) == .rain(.light))
        #expect(WeatherCodeInterpreter.weather(code: 63, precipitation: 2.0) == .rain(.moderate))
        #expect(WeatherCodeInterpreter.weather(code: 65, precipitation: 8.0) == .rain(.heavy))
        // 雷雨は降水量が少なくても強い雨として扱います。
        #expect(WeatherCodeInterpreter.weather(code: 95, precipitation: 0.1) == .rain(.heavy))
        #expect(WeatherCodeInterpreter.weather(code: 0, precipitation: 0.0) == .clear)
    }

    @Test @MainActor
    func weatherRefreshesOnlyAfterTheInterval() async {
        var now = Date(timeIntervalSince1970: 0)
        let stub = StubWeatherService()
        let viewModel = WeatherViewModel(
            service: stub,
            nowProvider: { now },
            startsAutomaticRefresh: false
        )

        stub.result = .success(.rain(.light))
        await viewModel.refreshIfNeeded()
        #expect(viewModel.weather == .rain(.light))

        // 取得間隔の内側では問い合わせません。
        stub.result = .success(.rain(.heavy))
        now = now.addingTimeInterval(60)
        await viewModel.refreshIfNeeded()
        #expect(viewModel.weather == .rain(.light))

        // 間隔を過ぎたら取り直します。画面を開いたままでもここに到達します。
        now = now.addingTimeInterval(15 * 60)
        await viewModel.refreshIfNeeded()
        #expect(viewModel.weather == .rain(.heavy))
    }

    @Test @MainActor
    func weatherKeepsLastValueWhenFetchFails() async {
        let stub = StubWeatherService()
        let viewModel = WeatherViewModel(service: stub, startsAutomaticRefresh: false)

        stub.result = .success(.rain(.moderate))
        await viewModel.refresh()
        #expect(viewModel.weather == .rain(.moderate))
        #expect(viewModel.hasFailedRecently == false)

        // 取得に失敗しても、直前に取れていた空模様を保ちます。
        stub.result = .failure(WeatherServiceError.requestFailed)
        await viewModel.refresh()
        #expect(viewModel.weather == .rain(.moderate))
        #expect(viewModel.hasFailedRecently == true)
    }

    @Test
    func celestialBodyRisesAtDawnAndPeaksAtNoon() {
        // 日の出直後は地平線近く、正午前後で最も高くなります。
        let dawn = SkyPalette.at(hour: 5.5)
        let noon = SkyPalette.at(hour: 12)
        #expect(dawn.celestialAltitude < 0.1)
        #expect(noon.celestialAltitude > 0.9)
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

    @Test @MainActor
    func appActivationRefreshesPastSearchTimeAndResults() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var currentDate = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 12, hour: 8)
        )!
        let viewModel = HomeViewModel(nowProvider: { currentDate })
        viewModel.searchTime = currentDate
        viewModel.performSearch()
        let morningDepartures = viewModel.searchResults.map(\.departure)

        currentDate = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 12, hour: 18)
        )!
        viewModel.refreshForAppActivation()

        #expect(viewModel.searchTime == currentDate)
        #expect(viewModel.searchCriteriaDescription.contains("18:00以降に出発"))
        #expect(viewModel.searchResults.map(\.departure) != morningDepartures)

        let futureSearchTime = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 12, hour: 20)
        )!
        viewModel.searchTime = futureSearchTime
        viewModel.refreshForAppActivation()

        #expect(viewModel.searchTime == futureSearchTime)
    }

}

/// 天気の取得結果を差し替えるためのテスト用スタブです。
private final class StubWeatherService: WeatherFetching, @unchecked Sendable {
    var result: Result<SkyWeather, Error> = .success(.clear)

    func fetchCurrentWeather() async throws -> SkyWeather {
        try result.get()
    }
}
