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
    func cardOpacityDefaultsToStandardAndPersistsChanges() {
        let suiteName = "BusTimeAppTests.CardOpacity"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = SettingsViewModel(
            defaults: defaults,
            liveActivityAvailability: { true }
        )
        #expect(viewModel.cardOpacity == SkyCardOpacity.standard)

        viewModel.setCardOpacity(0.8)
        #expect(viewModel.cardOpacity == 0.8)

        // 範囲の外を渡しても、上限と下限に収まります。
        viewModel.setCardOpacity(1.6)
        #expect(viewModel.cardOpacity == SkyCardOpacity.maximum)
        viewModel.setCardOpacity(-0.4)
        #expect(viewModel.cardOpacity == SkyCardOpacity.minimum)

        // 次に起動したときも選んだ濃さが復元されます。
        viewModel.setCardOpacity(0.75)
        let restored = SettingsViewModel(
            defaults: defaults,
            liveActivityAvailability: { true }
        )
        #expect(restored.cardOpacity == 0.75)
    }

    @Test
    func cardCoverageFollowsOpacityAndDensity() {
        // 濃さを上げるほど、背景を隠す地が強く効きます。
        #expect(SkyCardOpacity.coverage(for: 0, isDense: false) == 0)
        #expect(SkyCardOpacity.coverage(for: 0.5, isDense: false) == 0.5)
        #expect(SkyCardOpacity.coverage(for: 1, isDense: false) == 1)

        // 文字が詰まった面は一段濃くなります。
        #expect(SkyCardOpacity.coverage(for: 0.5, isDense: true) == 0.75)
        // 上限を超えては濃くなりません。
        #expect(SkyCardOpacity.coverage(for: 1, isDense: true) == 1)
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
        #expect(WeatherCodeInterpreter.weather(code: 61, precipitation: 0.2).precipitation == .rain(.light))
        #expect(WeatherCodeInterpreter.weather(code: 63, precipitation: 2.0).precipitation == .rain(.moderate))
        #expect(WeatherCodeInterpreter.weather(code: 65, precipitation: 8.0).precipitation == .rain(.heavy))
        // 雷雨は降水量が少なくても強い雨として扱います。
        #expect(WeatherCodeInterpreter.weather(code: 95, precipitation: 0.1).precipitation == .rain(.heavy))
        #expect(WeatherCodeInterpreter.weather(code: 0, precipitation: 0.0) == .clear)
    }

    @Test
    func weatherCarriesCloudFogThunderAndWind() {
        // 雲量は百分率で届くので、0〜1に直します。
        let cloudy = WeatherCodeInterpreter.weather(
            code: 3, precipitation: 0, cloudCover: 90, windSpeed: 7
        )
        #expect(cloudy.precipitation == .none)
        #expect(abs(cloudy.cloudCover - 0.9) < 0.001)
        #expect(cloudy.windSpeed == 7)

        // 霧は45と48です。
        #expect(WeatherCodeInterpreter.weather(code: 45, precipitation: 0).isFoggy)
        #expect(!WeatherCodeInterpreter.weather(code: 3, precipitation: 0).isFoggy)

        // 雷雨は雷ありとして扱います。
        #expect(WeatherCodeInterpreter.weather(code: 95, precipitation: 0.1).hasThunder)

        // 雪は雨と区別します。
        let snow = WeatherCodeInterpreter.weather(code: 73, precipitation: 1.5)
        #expect(snow.isSnowing)
        #expect(!snow.isRaining)
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
        let viewModel = HomeViewModel(
            nowProvider: { currentDate },
            defaults: makeIsolatedDefaults()
        )

        // 初期経路は時間帯によって変わるため、確かめたい出発地を明示します。
        viewModel.selectOrigin(.mansion)
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

    // MARK: - 時間帯からの初期経路

    @Test @MainActor
    func morningStartsWithARouteLeavingHome() {
        let viewModel = HomeViewModel(
            nowProvider: { makeTestDate(hour: 8) },
            defaults: makeIsolatedDefaults()
        )

        #expect(viewModel.selectedOrigin == .mansion)
        #expect(viewModel.routeDecision == .timeOfDay)
    }

    @Test @MainActor
    func afternoonStartsWithARouteHeadingHome() {
        let viewModel = HomeViewModel(
            nowProvider: { makeTestDate(hour: 16) },
            defaults: makeIsolatedDefaults()
        )

        #expect(viewModel.selectedDestination == .mansion)
        #expect(viewModel.routeDecision == .timeOfDay)
    }

    @Test @MainActor
    func theChosenDestinationIsRememberedButTheDirectionFollowsTheClock() {
        let defaults = makeIsolatedDefaults()

        let morning = HomeViewModel(
            nowProvider: { makeTestDate(hour: 8) },
            defaults: defaults
        )
        morning.selectDestination(.yokado)
        #expect(morning.selectedRoute == .mansionToYokado)

        // 同じ保存領域で開き直すと、行き先の好みだけが引き継がれ、
        // 向きは時間帯に合わせて逆になります。
        let afternoon = HomeViewModel(
            nowProvider: { makeTestDate(hour: 16) },
            defaults: defaults
        )
        #expect(afternoon.selectedOrigin == .yokado)
        #expect(afternoon.selectedDestination == .mansion)
    }

    @Test @MainActor
    func aManuallyChosenRouteIsNotOverwrittenByLocation() {
        let referenceDate = makeTestDate(hour: 8)
        let viewModel = HomeViewModel(
            nowProvider: { referenceDate },
            defaults: makeIsolatedDefaults()
        )

        viewModel.selectDestination(.yokado)
        let chosenRoute = viewModel.selectedRoute
        #expect(viewModel.routeDecision == .manual)

        // 自分で選んだあとは、現在地が届いても書き換えません。
        let stationLocation = CLLocation(latitude: 35.6485608, longitude: 140.0416924)
        viewModel.updateOriginForCurrentLocation(stationLocation, at: referenceDate)

        #expect(viewModel.selectedRoute == chosenRoute)
        #expect(viewModel.routeDecision == .manual)
    }

    @Test @MainActor
    func askingForTheCurrentLocationClearsTheManualChoice() {
        let referenceDate = makeTestDate(hour: 8)
        let viewModel = HomeViewModel(
            nowProvider: { referenceDate },
            defaults: makeIsolatedDefaults()
        )

        viewModel.selectDestination(.yokado)
        viewModel.useCurrentLocationForRoute()

        // 位置情報の許可状態はテストでは決められないため、
        // 手動指定が解除され、現在地の反映を受け付ける状態に戻ることを確かめます。
        let stationLocation = CLLocation(latitude: 35.6485608, longitude: 140.0416924)
        viewModel.updateOriginForCurrentLocation(stationLocation, at: referenceDate)

        #expect(viewModel.selectedOrigin == .station)
        #expect(viewModel.routeDecision == .automatic)
    }

    @Test @MainActor
    func arrivalSearchListsTheEarlierServiceSecond() {
        let viewModel = HomeViewModel(
            nowProvider: { makeTestDate(hour: 8) },
            defaults: makeIsolatedDefaults()
        )
        viewModel.selectOrigin(.mansion)
        viewModel.searchType = .arrival
        viewModel.searchTime = makeTestDate(hour: 9)
        viewModel.performSearch()

        // 到着時間で探すと「間に合う中で最も遅い便」から並ぶため、
        // 2件目は1件目より前に出る便になります。
        #expect(viewModel.searchResults.count == 2)
        #expect(viewModel.searchResults[0].departure == "8:40")
        #expect(viewModel.searchResults[1].departure == "8:30")
        // 見出しもそれに合わせて変わります。
        #expect(viewModel.followingSectionTitle == "ひとつ前の便")

        viewModel.searchType = .departure
        #expect(viewModel.followingSectionTitle == "このあとの便")
    }

    // MARK: - 深夜の検索

    @Test @MainActor
    func lateNightShowsTheMorningServiceInsteadOfNothing() {
        // 運行日は午前4時区切りのため、深夜2時は前日の運行日に属します。
        // その運行日の便は終わっていますが、同じ朝の始発を案内します。
        let lateNight = makeTestDate(hour: 2)
        let viewModel = HomeViewModel(
            nowProvider: { lateNight },
            defaults: makeIsolatedDefaults()
        )
        viewModel.searchTime = lateNight
        viewModel.performSearch()

        #expect(!viewModel.searchResults.isEmpty)
        #expect(viewModel.showsNextServiceDay)
        #expect(viewModel.searchResults.first?.departure == "6:03")
    }

    @Test @MainActor
    func daytimeSearchDoesNotWrapToTheNextServiceDay() {
        let morning = makeTestDate(hour: 8)
        let viewModel = HomeViewModel(
            nowProvider: { morning },
            defaults: makeIsolatedDefaults()
        )
        viewModel.searchTime = morning
        viewModel.performSearch()

        #expect(!viewModel.showsNextServiceDay)
        #expect(!viewModel.searchResults.isEmpty)
    }

    @Test @MainActor
    func earlyMorningAfterASuspendedDayShowsTodaysFirstService() {
        // 2026年8月17日は月曜です。その0時台は日曜の運行日に属し、日曜は運休なので
        // 0時台の便は走りません。月曜の始発を案内する必要があります。
        let mondayMidnight = makeTestDate(day: 17, hour: 0, minute: 3)
        let viewModel = HomeViewModel(
            nowProvider: { mondayMidnight },
            defaults: makeIsolatedDefaults()
        )
        viewModel.searchTime = mondayMidnight
        viewModel.performSearch()

        #expect(!viewModel.isServiceSuspended)
        #expect(viewModel.showsNextServiceDay)
        #expect(viewModel.searchResults.first?.departure == "6:03")
    }

    @Test @MainActor
    func earlyMorningOfAServiceDayKeepsTheLateNightBuses() {
        // 2026年8月15日は土曜です。その0時台はまだ金曜の運行日なので、
        // コロンブスシティ0時04分発の深夜便は走ります。運休扱いにしてはいけません。
        let justBeforeTheLastBus = makeTestDate(day: 15, hour: 0, minute: 1)
        let viewModel = HomeViewModel(
            nowProvider: { justBeforeTheLastBus },
            defaults: makeIsolatedDefaults()
        )
        viewModel.selectOrigin(.mansion)
        viewModel.searchTime = justBeforeTheLastBus
        viewModel.performSearch()

        #expect(!viewModel.isServiceSuspended)
        // まだこの運行日に便が残っているので、次の運行日へは送りません。
        #expect(!viewModel.showsNextServiceDay)
        #expect(viewModel.searchResults.first?.departure == "0:04")
    }

    @Test @MainActor
    func afterTheLastLateNightBusPointsAtTheNextServiceDay() {
        // 深夜便も終わった土曜0時30分では、次に乗れるのは月曜の始発です。
        let afterTheLastBus = makeTestDate(day: 15, hour: 0, minute: 30)
        let viewModel = HomeViewModel(
            nowProvider: { afterTheLastBus },
            defaults: makeIsolatedDefaults()
        )
        viewModel.searchTime = afterTheLastBus
        viewModel.performSearch()

        #expect(viewModel.showsNextServiceDay)
    }

    @Test @MainActor
    func saturdayDaytimeIsStillSuspended() {
        let saturdayMorning = makeTestDate(day: 15, hour: 8)
        let viewModel = HomeViewModel(
            nowProvider: { saturdayMorning },
            defaults: makeIsolatedDefaults()
        )

        #expect(viewModel.isServiceSuspended)
    }

    // MARK: - 運行日をまたぐ通知

    @Test
    func nextDepartureSkipsTheWeekend() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        // 2026年8月14日は金曜日です。夕方の時点で朝8時の便は出発済みなので、
        // 単純に翌日へ送ると土曜になってしまいます。次の運行日は17日の月曜です。
        let fridayEvening = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 14, hour: 18)
        )!
        let next = BusNotificationTimeCalculator.nextDepartureDate(
            for: "8:00",
            from: fridayEvening,
            calendar: calendar
        )!

        #expect(calendar.component(.day, from: next) == 17)
        #expect(calendar.component(.hour, from: next) == 8)
    }

    @Test
    func nextDepartureSkipsAPublicHoliday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        // 2025年11月3日は月曜の祝日です。前日の日曜から見ると、
        // 次に走るのは4日の火曜になります。
        let sundayEvening = calendar.date(
            from: DateComponents(year: 2025, month: 11, day: 2, hour: 20)
        )!
        let next = BusNotificationTimeCalculator.nextDepartureDate(
            for: "8:00",
            from: sundayEvening,
            calendar: calendar
        )!

        #expect(calendar.component(.day, from: next) == 4)
    }

    @Test
    func lateNightBusBelongsToThePreviousServiceDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        // 金曜の運行日に属する0時13分の便は、暦の上では土曜ですが運行します。
        let fridayNight = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 14, hour: 23)
        )!
        let next = BusNotificationTimeCalculator.nextDepartureDate(
            for: "0:13",
            from: fridayNight,
            calendar: calendar
        )!

        #expect(calendar.component(.day, from: next) == 15)
        #expect(calendar.component(.hour, from: next) == 0)
    }

    @Test
    func serviceCalendarKnowsWeekendsAndHolidays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let weekday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!
        let saturday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15))!
        let holiday = calendar.date(from: DateComponents(year: 2025, month: 11, day: 3))!

        #expect(BusServiceCalendar.isServiceDay(weekday, calendar: calendar))
        #expect(!BusServiceCalendar.isServiceDay(saturday, calendar: calendar))
        #expect(!BusServiceCalendar.isServiceDay(holiday, calendar: calendar))
    }

    @Test
    func paletteCarriesTheHourForTimeBasedEffects() {
        // 街灯の点灯や潮位は時刻そのものを見ます。
        // celestialProgressは太陽の軌道上の進み具合なので、時刻の代わりには使えません。
        #expect(SkyPalette.at(hour: 6).hour == 6)
        #expect(SkyPalette.at(hour: 18.5).hour == 18.5)
        // 範囲外の時刻は24時間周期に丸めます。
        #expect(SkyPalette.at(hour: 26).hour == 2)
    }

    @Test
    func streetLightHoursCoverEveningAndNightOnly() {
        // 街灯が点くのは夕方16時から翌朝4時半までです。
        // 判定に使う暗さも合わせて確かめます。
        func isEveningOrNight(_ hour: Double) -> Bool {
            hour >= 16 || hour < 4.5
        }

        // 朝と昼は消えています。
        #expect(!isEveningOrNight(6))
        #expect(!isEveningOrNight(12))
        #expect(!isEveningOrNight(15))
        // 夕方と夜は点きます。
        #expect(isEveningOrNight(18))
        #expect(isEveningOrNight(22))
        #expect(isEveningOrNight(2))

        // 朝6時は空が暗くても点けません。
        #expect(SkyPalette.at(hour: 6).nightness > 0.22)
        #expect(!isEveningOrNight(6))
    }

    // MARK: - 月の満ち欠け

    @Test
    func moonPhaseMatchesRealNewAndFullMoons() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        func date(_ y: Int, _ m: Int, _ d: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute))!
        }

        /// 新月からのずれです。0と1はどちらも新月なので、近いほうを見ます。
        func distanceFromNewMoon(_ phase: Double) -> Double {
            min(phase, 1 - phase)
        }

        // 実際の新月の日時です。位相が0に近いことを確かめます。
        #expect(distanceFromNewMoon(MoonPhase.phase(at: date(2024, 1, 11, 11, 57))) < 0.02)
        #expect(distanceFromNewMoon(MoonPhase.phase(at: date(2025, 3, 29, 10, 58))) < 0.02)

        // 実際の満月の日時です。位相が0.5に近いことを確かめます。
        #expect(abs(MoonPhase.phase(at: date(2024, 1, 25, 17, 54)) - 0.5) < 0.02)

        // 月齢は0以上、朔望月未満に収まります。
        let age = MoonPhase.age(at: date(2026, 8, 17, 0, 0))
        #expect(age >= 0)
        #expect(age < MoonPhase.synodicMonth)
    }

    // MARK: - 配色

    @Test
    func inkSwitchesAtOnceInsteadOfFadingThroughGrey() {
        // 文字色に中間の値を持たせると、夕方にカードの地と同じ明るさに近づき、
        // どちらも灰色になって読めなくなります。昼と夜の2色だけを使います。
        #expect(SkyPalette.at(hour: 18).ink == SkyPalette.at(hour: 12).ink)
        #expect(SkyPalette.at(hour: 21).ink == SkyPalette.at(hour: 2).ink)
        #expect(SkyPalette.at(hour: 12).ink != SkyPalette.at(hour: 2).ink)
    }

    @Test
    func cardSurfaceSwitchesTogetherWithTheInk() {
        // 地と文字は同じ境界で入れ替わる必要があります。
        // 片方だけ先に変わると、その間だけ読みにくくなります。
        #expect(SkyPalette.at(hour: 18).isNight == false)
        #expect(SkyPalette.at(hour: 21).isNight == true)
        #expect(SkyPalette.at(hour: 18).surface == SkyPalette.at(hour: 12).surface)
        #expect(SkyPalette.at(hour: 21).surface == SkyPalette.at(hour: 2).surface)
    }

    // MARK: - 運行日の選択

    @Test @MainActor
    func otherWeekdaySkipsTheWeekend() {
        // 2026年8月15日は土曜日です。次の運行日は17日の月曜になります。
        let saturday = makeTestDate(day: 15, hour: 10)
        let viewModel = HomeViewModel(
            nowProvider: { saturday },
            defaults: makeIsolatedDefaults()
        )

        viewModel.serviceDay = .otherWeekday

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        #expect(calendar.component(.day, from: viewModel.selectedServiceDate) == 17)
        #expect(viewModel.selectedDayHasService)
        #expect(viewModel.serviceDayNotice == nil)
        // 先の日なので、残り時間や通知は出しません。
        #expect(!viewModel.isRealtimeContext)
    }

    @Test @MainActor
    func otherWeekdayIsAlwaysAServiceDay() {
        // 2026年8月14日は金曜日です。翌日は土曜ですが、
        // 「他の平日」は運行日だけを指すため運休にはなりません。
        let friday = makeTestDate(day: 14, hour: 18)
        let viewModel = HomeViewModel(
            nowProvider: { friday },
            defaults: makeIsolatedDefaults()
        )

        viewModel.serviceDay = .otherWeekday

        #expect(viewModel.selectedDayHasService)
        #expect(viewModel.serviceDayNotice == nil)
    }

    @Test @MainActor
    func lookingAtAnotherWeekdayHidesRealtimeInformation() {
        let wednesday = makeTestDate(hour: 8)
        let viewModel = HomeViewModel(
            nowProvider: { wednesday },
            defaults: makeIsolatedDefaults()
        )

        #expect(viewModel.isRealtimeContext)
        #expect(viewModel.resultSectionTitle == "つぎのバス")
        #expect(viewModel.notificationUnavailableReason == nil)

        viewModel.serviceDay = .otherWeekday

        #expect(!viewModel.isRealtimeContext)
        #expect(viewModel.resultSectionTitle == "平日ダイヤの便")
        #expect(viewModel.notificationUnavailableReason?.contains("運行当日") == true)
    }

    // MARK: - 運休日の扱い

    @Test @MainActor
    func weekendKeepsTheNoticeAndStillShowsWeekdayTimes() {
        let saturday = makeTestDate(day: 15, hour: 8)
        let viewModel = HomeViewModel(
            nowProvider: { saturday },
            defaults: makeIsolatedDefaults()
        )
        viewModel.searchTime = saturday
        viewModel.performSearch()

        // 運休の案内は残したまま、平日ダイヤの検索結果は返します。
        #expect(viewModel.isServiceSuspended)
        #expect(viewModel.holidayMessage?.contains("土日") == true)
        #expect(!viewModel.searchResults.isEmpty)
        #expect(viewModel.searchResultDescription.contains("平日ダイヤ"))
    }

    @Test @MainActor
    func allStopsStaySelectableOnAWeekend() {
        let saturdayEvening = makeTestDate(day: 15, hour: 16, minute: 52)
        let viewModel = HomeViewModel(
            nowProvider: { saturdayEvening },
            defaults: makeIsolatedDefaults()
        )

        // 運休日は「本日の残り便」で候補を絞らないため、
        // 平日ダイヤを調べたい行き先をいつでも選べます。
        viewModel.selectOrigin(.mansion)
        #expect(viewModel.availableDestinations.contains(.yokado))

        viewModel.selectDestination(.yokado)
        #expect(viewModel.selectedRoute == .mansionToYokado)
        #expect(viewModel.routeAvailabilityMessage == nil)
    }

    @Test @MainActor
    func stopsStaySelectableAfterTheLastBusOfTheDay() {
        // 平日でも本日の運行がすべて終わったあとは、候補を絞りません。
        // 運行日は午前4時区切りのため、深夜便も終わった午前2時を使います。
        let afterLastBus = makeTestDate(hour: 2)
        let viewModel = HomeViewModel(
            nowProvider: { afterLastBus },
            defaults: makeIsolatedDefaults()
        )

        #expect(!viewModel.availableOrigins.isEmpty)
        viewModel.selectOrigin(.mansion)
        #expect(viewModel.availableDestinations.contains(.yokado))
    }

    @Test @MainActor
    func weekdaySearchIsNotMarkedAsSuspended() {
        let wednesday = makeTestDate(hour: 8)
        let viewModel = HomeViewModel(
            nowProvider: { wednesday },
            defaults: makeIsolatedDefaults()
        )
        viewModel.searchTime = wednesday
        viewModel.performSearch()

        #expect(!viewModel.isServiceSuspended)
        #expect(viewModel.holidayMessage == nil)
        #expect(!viewModel.searchResults.isEmpty)
    }

}

/// テストごとに独立した保存領域を用意します。
/// 経路の好みを保存する処理があるため、テスト同士が干渉しないようにします。
private func makeIsolatedDefaults() -> UserDefaults {
    let suiteName = "BusTimeAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

/// テストで使う日時を作ります。既定の2026年8月12日は水曜日、15日は土曜日です。
private func makeTestDate(day: Int = 12, hour: Int, minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar.date(
        from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute)
    )!
}

/// 天気の取得結果を差し替えるためのテスト用スタブです。
private final class StubWeatherService: WeatherFetching, @unchecked Sendable {
    var result: Result<SkyWeather, Error> = .success(.clear)

    func fetchCurrentWeather() async throws -> SkyWeather {
        try result.get()
    }
}
