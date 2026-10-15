//
//  BusTimeAppTests.swift
//  BusTimeAppTests
//
//  Created by hara ryuto   on 2025/06/13.
//

import Foundation
import CoreLocation
import SwiftUI
import UIKit
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
        coordinator.send(.tutorialCompleted)
        #expect(coordinator.state == .dashboard)
        #expect(defaults.bool(forKey: "hasSeenTutorial"))
        coordinator.send(.showNotifications)
        #expect(coordinator.state == .notifications)
        coordinator.send(.dismiss)
        #expect(coordinator.state == .dashboard)
    }

    @Test @MainActor
    func tutorialIsOnlyMarkedSeenAfterCompletion() {
        let defaults = makeIsolatedDefaults()
        let first = AppCoordinator(defaults: defaults)
        first.send(.launch)
        #expect(first.state == .tutorial)
        first.send(.dismiss)

        let reopened = AppCoordinator(defaults: defaults)
        reopened.send(.launch)
        #expect(reopened.state == .tutorial)
        reopened.send(.tutorialCompleted)

        let completed = AppCoordinator(defaults: defaults)
        completed.send(.launch)
        #expect(completed.state == .dashboard)
    }

    @Test
    func notificationTimeUsesServiceDayBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let beforeBoundary = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 13, hour: 3, minute: 0)
        )!
        let currentServiceDay = BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
            for: "0:04",
            from: beforeBoundary,
            calendar: calendar
        )!
        #expect(calendar.component(.day, from: currentServiceDay) == 13)
        #expect(calendar.component(.hour, from: currentServiceDay) == 0)
        #expect(calendar.component(.minute, from: currentServiceDay) == 4)

        let nextDeparture = BusNotificationTimeCalculator.nextDepartureDate(
            for: "0:04",
            from: beforeBoundary,
            calendar: calendar
        )!
        #expect(calendar.component(.day, from: nextDeparture) == 14)

        let afterBoundary = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 13, hour: 5, minute: 0)
        )!
        let nextServiceDay = BusNotificationTimeCalculator.nextDepartureDate(
            for: "0:04",
            from: afterBoundary,
            calendar: calendar
        )!
        #expect(calendar.component(.day, from: nextServiceDay) == 14)
        #expect(calendar.component(.hour, from: nextServiceDay) == 0)
    }

    @Test
    func notificationTimeCannotBeScheduledInThePast() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 12, hour: 7, minute: 55)
        )!

        let schedule = BusNotificationTimeCalculator.notificationDate(
            for: "8:00",
            minutesBefore: 10,
            from: now,
            calendar: calendar
        )
        #expect(schedule == nil)
    }

    @Test @MainActor
    func legacyNotificationStorageMigratesToVersionedEnvelope() throws {
        let defaults = makeIsolatedDefaults()
        let item = makeFutureScheduledNotification()
        defaults.set(
            try JSONEncoder().encode([item]),
            forKey: "scheduledBusNotifications"
        )

        let viewModel = NotificationViewModel(defaults: defaults)
        #expect(viewModel.scheduledNotifications == [item])

        let migratedData = try #require(
            defaults.data(forKey: "scheduledBusNotifications")
        )
        let migrated = try JSONDecoder().decode(
            StoredNotificationsEnvelope.self,
            from: migratedData
        )
        #expect(migrated.version == 1)
        #expect(migrated.notifications == [item])
    }

    @Test @MainActor
    func corruptNotificationStorageIsNotOverwritten() {
        let defaults = makeIsolatedDefaults()
        let corruptData = Data("not-json".utf8)
        defaults.set(corruptData, forKey: "scheduledBusNotifications")

        let viewModel = NotificationViewModel(defaults: defaults)
        #expect(viewModel.scheduledNotifications.isEmpty)
        #expect(defaults.data(forKey: "scheduledBusNotifications") == corruptData)
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

    @Test
    func showButtonShapesStrengthensTheOutline() {
        // 「ボタンの形」がオンのときは、押せる範囲がはっきり分かるよう輪郭を濃くします。
        let normal = SkyButtonOutline.opacity(showButtonShapes: false)
        let emphasized = SkyButtonOutline.opacity(showButtonShapes: true)

        #expect(emphasized > normal)
        // ふだんは風景を邪魔しない薄さに保ちます。
        #expect(normal < 0.3)
    }

    @Test
    func accentKeepsItsLabelReadable() {
        // 選んだチップや主要なボタンは、強調色の上に文字を置きます。
        // 昼と夜の中間で白と黒のどちらを置いても足りない明るさになりやすいので、
        // どの時刻・季節でも余裕を持って読めることを確かめます。
        var worst = (ratio: Double.infinity, season: Season.spring, hour: 0.0)

        for season in Season.allCases {
            for step in 0..<(24 * 4) {
                let hour = Double(step) / 4
                let palette = SkyPalette.at(hour: hour, season: season)
                let background = components(of: palette.accent)
                let label = blend(components(of: palette.accentInk), over: background)
                let ratio = contrastRatio(label, background)
                if ratio < worst.ratio {
                    worst = (ratio, season, hour)
                }
            }
        }

        // 4.5ちょうどでは、実際の描画のわずかな差で下回ります。余裕を持たせます。
        #expect(
            worst.ratio >= 5.0,
            "強調色の上の文字が最も読みにくいのは\(worst.season)の\(worst.hour)時で、比は\(worst.ratio)でした"
        )
    }

    @Test
    func reduceTransparencyHidesTheSceneBehindCards() {
        // 「透明度を下げる」がオンのときは、濃さの設定にかかわらず地を敷き切ります。
        // 背景の風景が透けること自体が、この設定で避けたいことだからです。
        #expect(SkyCardOpacity.coverage(for: 0, isDense: false, reduceTransparency: true) == 1)
        #expect(SkyCardOpacity.coverage(for: 0.5, isDense: false, reduceTransparency: true) == 1)

        // オフのときは、これまでどおり設定の濃さに従います。
        #expect(SkyCardOpacity.coverage(for: 0, isDense: false, reduceTransparency: false) == 0)
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
    func localizedTimeSeparatesEnglishPeriodAndKeeps24HourLocales() {
        let evening = makeTestDate(hour: 18, minute: 48)
        let morning = makeTestDate(hour: 6, minute: 48)
        #expect(TimeDisplayFormatter.string(from: evening, locale: Locale(identifier: "en_US")) == "6:48 PM")
        #expect(TimeDisplayFormatter.string(from: morning, locale: Locale(identifier: "en_US")) == "6:48 AM")
        #expect(TimeDisplayFormatter.string(from: evening, locale: Locale(identifier: "ja_JP")) == "18:48")
        #expect(TimeDisplayFormatter.string(from: evening, locale: Locale(identifier: "en_GB")) == "18:48")
    }

    @Test
    func skyPaletteSwitchesBetweenDayAndNight() {
        // 昼は明るい空なので暗い文字、夜は暗い空なので明るい文字になります。
        // 昼の長さは季節で変わるので、季節を決めてから確かめます。
        #expect(SkyPalette.at(hour: 12, season: .spring).isNight == false)
        #expect(SkyPalette.at(hour: 23, season: .spring).isNight == true)
        #expect(SkyPalette.at(hour: 3, season: .spring).isNight == true)
        #expect(SkyPalette.at(hour: 8, season: .spring).isNight == false)
    }

    @Test
    func skyPaletteIsContinuousAcrossMidnight() {
        // 0時と24時は同じキーフレームなので、日付をまたいでも色が飛びません。
        #expect(SkyPalette.at(hour: 0, season: .spring) == SkyPalette.at(hour: 24, season: .spring))
        // 範囲外の時刻は24時間周期に丸められます。
        #expect(SkyPalette.at(hour: 25, season: .spring) == SkyPalette.at(hour: 1, season: .spring))
        #expect(SkyPalette.at(hour: -1, season: .spring) == SkyPalette.at(hour: 23, season: .spring))
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

    @Test @MainActor
    func appearanceOverridesKeepControlsAndSurfacesConsistent() {
        let settings = SettingsViewModel(defaults: makeIsolatedDefaults())
        settings.setAppearancePreference(.automatic)
        #expect(settings.paletteColorScheme(systemColorScheme: .dark) == nil)
        settings.setAppearancePreference(.system)
        #expect(settings.paletteColorScheme(systemColorScheme: .dark) == .dark)
        #expect(settings.paletteColorScheme(systemColorScheme: .light) == .light)
        settings.setAppearancePreference(.dark)
        #expect(settings.paletteColorScheme(systemColorScheme: .light) == .dark)
        settings.setAppearancePreference(.light)
        #expect(settings.paletteColorScheme(systemColorScheme: .dark) == .light)

        for scheme in [ColorScheme.light, .dark] {
            for season in Season.allCases {
                for step in 0..<96 {
                    let hour = Double(step) / 4
                    let natural = SkyPalette.at(hour: hour, season: season)
                    let palette = SkyPalette.at(hour: hour, season: season, colorScheme: scheme)
                    #expect(palette.skyTop == natural.skyTop)
                    #expect(palette.skyBottom == natural.skyBottom)
                    #expect(palette.nightness == natural.nightness)
                    let card = blend(components(of: palette.surface), over: components(of: palette.skyTop))
                    #expect(contrastRatio(components(of: palette.ink), card) >= 4.5)
                    #expect(contrastRatio(components(of: palette.ink), components(of: palette.surfaceOpaque)) >= 4.5)
                }
            }
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
    func rainAndCloudsDimTheSkyAndHideTheSun() {
        let palette = SkyPalette.at(hour: 12 + 22.0 / 60, season: .summer)
        let clear = components(of: palette.skyColor(at: 0, weather: .clear))
        let rainy = components(of: palette.skyColor(at: 0, weather: .rain(.heavy)))
        #expect(relativeLuminance(rainy) < relativeLuminance(clear))
        #expect(rainy.b - rainy.r < clear.b - clear.r)
        #expect(SkyWeather.clear.celestialVisibility == 1)
        #expect(SkyWeather.rain(.heavy).celestialVisibility == 0)
        #expect(SkyWeather.rain(.heavy).rainStrokeOpacity > SkyWeather.rain(.light).rainStrokeOpacity)
        #expect(SkyWeather(cloudCover: 1).celestialVisibility == 0)
        #expect(SkyWeather(cloudCover: 0.5).celestialVisibility > SkyWeather(cloudCover: 0.9).celestialVisibility)
        #expect(SkyWeather(precipitation: .rain(.heavy)).skyObscuration == 1)
        #expect(palette.quantizedSkyColors(steps: 8) == palette.quantizedSkyColors(steps: 8, weather: .clear))
        #expect(palette.quantizedWaterColors(steps: 8, weather: .rain(.heavy)) != palette.quantizedWaterColors(steps: 8))
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
            defaults: makeIsolatedDefaults(),
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
        let viewModel = WeatherViewModel(
            service: stub,
            defaults: makeIsolatedDefaults(),
            startsAutomaticRefresh: false
        )

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

    @Test @MainActor
    func weatherRestoresTheLastSuccessfulValueFromCache() async {
        let defaults = makeIsolatedDefaults()
        let firstService = StubWeatherService()
        firstService.result = .success(.snow(.moderate))
        let first = WeatherViewModel(
            service: firstService,
            defaults: defaults,
            startsAutomaticRefresh: false
        )
        await first.refresh()

        let restored = WeatherViewModel(
            service: StubWeatherService(),
            defaults: defaults,
            startsAutomaticRefresh: false
        )
        #expect(restored.weather == .snow(.moderate))
        #expect(restored.lastSuccessfulUpdate != nil)
    }

    @Test @MainActor
    func weatherRejectsCacheWithAFutureTimestamp() async {
        let defaults = makeIsolatedDefaults()
        let service = StubWeatherService()
        service.result = .success(.rain(.heavy))
        let future = Date(timeIntervalSince1970: 20_000)
        let first = WeatherViewModel(
            service: service,
            nowProvider: { future },
            defaults: defaults,
            startsAutomaticRefresh: false
        )
        await first.refresh()

        let restored = WeatherViewModel(
            service: StubWeatherService(),
            nowProvider: { Date(timeIntervalSince1970: 10_000) },
            defaults: defaults,
            startsAutomaticRefresh: false
        )
        #expect(restored.weather == .clear)
        #expect(restored.lastSuccessfulUpdate == nil)
    }

    @Test @MainActor
    func weatherFailureUsesExponentialBackoff() async {
        var now = Date(timeIntervalSince1970: 10_000)
        let stub = StubWeatherService()
        stub.result = .failure(WeatherServiceError.requestFailed)
        let viewModel = WeatherViewModel(
            service: stub,
            nowProvider: { now },
            defaults: makeIsolatedDefaults(),
            startsAutomaticRefresh: false
        )

        await viewModel.refreshIfNeeded()
        #expect(stub.callCount == 1)
        now = now.addingTimeInterval(30)
        await viewModel.refreshIfNeeded()
        #expect(stub.callCount == 1)
        now = now.addingTimeInterval(30)
        await viewModel.refreshIfNeeded()
        #expect(stub.callCount == 2)
        now = now.addingTimeInterval(60)
        await viewModel.refreshIfNeeded()
        #expect(stub.callCount == 2)
        now = now.addingTimeInterval(60)
        await viewModel.refreshIfNeeded()
        #expect(stub.callCount == 3)
    }

    @Test @MainActor
    func appearancePreferencePersists() {
        let defaults = makeIsolatedDefaults()
        let first = SettingsViewModel(
            defaults: defaults,
            liveActivityAvailability: { false }
        )
        first.setAppearancePreference(.dark)

        let restored = SettingsViewModel(
            defaults: defaults,
            liveActivityAvailability: { false }
        )
        #expect(restored.appearancePreference == .dark)
        #expect(restored.preferredColorScheme(for: SkyPalette.at(hour: 12)) == .dark)
    }

    @Test @MainActor
    func homeSearchPreferencesRestoreAcrossLaunches() {
        let defaults = makeIsolatedDefaults()
        let now = makeTestDate(hour: 8)
        let futureSearchTime = makeTestDate(hour: 12)
        let first = HomeViewModel(nowProvider: { now }, defaults: defaults)
        first.serviceDay = .otherWeekday
        first.searchType = .arrival
        first.searchTime = futureSearchTime
        first.persistSearchPreferences()

        let restored = HomeViewModel(nowProvider: { now }, defaults: defaults)
        #expect(restored.serviceDay == .otherWeekday)
        #expect(restored.searchType == .arrival)
        #expect(restored.searchTime == futureSearchTime)
    }

    @Test
    func celestialBodyRisesAtDawnAndPeaksAtNoon() {
        // 日の出直後は地平線近く、正午前後で最も高くなります。
        // 日の出の時刻は季節で変わるので、季節ごとの日の出で確かめます。
        for season in Season.allCases {
            let daylight = SkyPalette.daylight(for: season)
            let dawn = SkyPalette.at(hour: daylight.sunrise, season: season)
            let noon = SkyPalette.at(hour: daylight.solarNoon, season: season)
            #expect(dawn.celestialAltitude < 0.1)
            #expect(noon.celestialAltitude > 0.9)
        }
    }

    @Test
    func celestialOrbitSharesTheSeasonalDaylightWithTheSky() {
        // 空の色と太陽の軌道は同じ日の出・日の入りを使います。
        // どの季節でも、日の入りの瞬間の空は同じ暗さで、太陽はちょうど地平線にあります。
        let sunsetNightness = SkyPalette.at(
            hour: SkyPalette.daylight(for: .spring).sunset,
            season: .spring
        ).nightness
        for season in Season.allCases {
            let daylight = SkyPalette.daylight(for: season)
            let sunset = SkyPalette.at(hour: daylight.sunset, season: season)
            #expect(abs(sunset.nightness - sunsetNightness) < 0.000_001)
            #expect(sunset.celestialAltitude < 0.000_001)
            #expect(sunset.daylight == daylight)
        }

        // 冬は日が短く、夏は長くなります。
        #expect(SkyPalette.daylight(for: .winter).sunset < SkyPalette.daylight(for: .spring).sunset)
        #expect(SkyPalette.daylight(for: .summer).sunset > SkyPalette.daylight(for: .spring).sunset)
        #expect(SkyPalette.daylight(for: .summer).sunrise < SkyPalette.daylight(for: .winter).sunrise)

        // 冬の17時45分は日が沈んで暮れており、太陽は描かれません。
        let winterEvening = SkyPalette.at(hour: 17.75, season: .winter)
        #expect(!winterEvening.isSunUp)
        #expect(winterEvening.nightness > 0.5)
        // 夏の18時45分は空がまだ明るく、太陽も沈みきっていません。
        let summerEvening = SkyPalette.at(hour: 18.75, season: .summer)
        #expect(summerEvening.isSunUp)
        #expect(summerEvening.isNight == false)
    }

    @Test
    func daylightFollowsTheDateAtMakuhari() {
        // 国立天文台の暦（千葉）の日の出・日の入りと、4分以内で一致することを確かめます。
        let references: [(dayOfYear: Int, sunrise: Double, sunset: Double)] = [
            // 夏至（6月21日）: 4時25分、19時0分
            (172, 4 + 25.0 / 60, 19),
            // 冬至（12月22日）: 6時45分、16時30分
            (356, 6 + 45.0 / 60, 16 + 30.0 / 60),
            // 春分（3月20日）: 5時43分、17時52分
            (79, 5 + 43.0 / 60, 17 + 52.0 / 60)
        ]
        for reference in references {
            let daylight = SeasonalDay(dayOfYear: reference.dayOfYear).daylight
            #expect(abs(daylight.sunrise - reference.sunrise) * 60 <= 4, "\(reference.dayOfYear)日目の日の出")
            #expect(abs(daylight.sunset - reference.sunset) * 60 <= 4, "\(reference.dayOfYear)日目の日の入り")
        }

        // 海浜幕張は日本標準時の基準より東にあるため、南中は一年を通して正午より前です。
        for dayOfYear in stride(from: 1, through: 365, by: 7) {
            let solarNoon = SeasonalDay(dayOfYear: dayOfYear).daylight.solarNoon
            #expect(solarNoon > 11 + 20.0 / 60)
            #expect(solarNoon < 12)
        }
    }

    @Test
    func skyFollowsTheSunriseAndSunsetOfTheDay() {
        let summer = SeasonalDay(dayOfYear: 172)
        let winter = SeasonalDay(dayOfYear: 356)

        // 日の出の空は、季節にかかわらず同じ明るさです。
        let summerSunrise = SkyPalette.at(hour: summer.daylight.sunrise, day: summer)
        let winterSunrise = SkyPalette.at(hour: winter.daylight.sunrise, day: winter)
        #expect(abs(summerSunrise.nightness - winterSunrise.nightness) < 0.000_001)

        // 冬至の16時45分は日が沈み、空は暮れています（日の入りは16時30分ごろ）。
        let winterDusk = SkyPalette.at(hour: 16.75, day: winter)
        #expect(!winterDusk.isSunUp)
        #expect(winterDusk.nightness > SkyPalette.at(hour: 16.75, day: summer).nightness + 0.4)
        // 夏至の4時30分はもう日が出ており、空も明るくなっています（日の出は4時25分ごろ）。
        let summerDawn = SkyPalette.at(hour: 4.5, day: summer)
        #expect(summerDawn.isSunUp)
        #expect(summerDawn.nightness < SkyPalette.at(hour: 4.5, day: winter).nightness - 0.4)

        // 南中のころは、どの日も完全な昼の空です。
        for day in [summer, winter] {
            #expect(SkyPalette.at(hour: day.daylight.solarNoon, day: day).nightness == 0)
        }
    }

    @Test
    func seasonalDayKnowsItsMonthInLeapYears() {
        #expect(SeasonalDay(dayOfYear: 59).month == 2)
        // 平年の60日目は3月1日、うるう年の60日目は2月29日です。
        #expect(SeasonalDay(dayOfYear: 60).month == 3)
        #expect(SeasonalDay(dayOfYear: 60, daysInYear: 366).month == 2)
        #expect(SeasonalDay(dayOfYear: 61, daysInYear: 366).month == 3)
        #expect(SeasonalDay(dayOfYear: 365).month == 12)
        #expect(SeasonalDay(dayOfYear: 366, daysInYear: 366).month == 12)

        // 日付からは、日本時間の暦で年内の何日目かを数えます。2026年8月12日は224日目です。
        let date = makeTestDate(hour: 12)
        #expect(SeasonalDay(date: date, calendar: AppCalendar.japan).dayOfYear == 224)

        // 季節を代表する日は、その季節に含まれます。
        for season in Season.allCases {
            #expect(SeasonalDay(season: season).season == season)
        }
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

    @Test @MainActor
    func timerAdvancesDeparturesWithoutAppActivation() {
        var currentDate = makeTestDate(hour: 8)
        let viewModel = HomeViewModel(
            nowProvider: { currentDate }, defaults: makeIsolatedDefaults()
        )
        viewModel.setAutomaticUpdatesActive(false)
        let first = viewModel.searchResults.first!
        let departure = BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
            for: first.departure, from: currentDate, calendar: AppCalendar.japan
        )!
        currentDate = departure.addingTimeInterval(61)
        viewModel.refreshForTimerTick()

        #expect(viewModel.searchResults.first?.id != first.id)
        #expect(viewModel.searchResults.count == 4)
        #expect(viewModel.searchResults.allSatisfy {
            (BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
                for: $0.departure, from: currentDate, calendar: AppCalendar.japan
            ) ?? .distantPast) > currentDate
        })
        #expect(viewModel.remainingMinutes[first.id] == nil)
    }

    @Test @MainActor
    func timerPreservesFutureAndOtherWeekdaySearches() {
        var currentDate = makeTestDate(hour: 8)
        let viewModel = HomeViewModel(
            nowProvider: { currentDate }, defaults: makeIsolatedDefaults()
        )
        viewModel.setAutomaticUpdatesActive(false)
        viewModel.searchTime = makeTestDate(hour: 18)
        viewModel.performSearch()
        let futureResults = viewModel.searchResults.map(\.id)
        currentDate = currentDate.addingTimeInterval(120)
        viewModel.refreshForTimerTick()
        #expect(viewModel.searchResults.map(\.id) == futureResults)
        #expect(viewModel.searchTime == makeTestDate(hour: 18))

        viewModel.serviceDay = .otherWeekday
        viewModel.searchTime = makeTestDate(hour: 7)
        viewModel.performSearch()
        let weekdayResults = viewModel.searchResults.map(\.id)
        currentDate = makeTestDate(hour: 10)
        viewModel.refreshForTimerTick()
        #expect(viewModel.searchResults.map(\.id) == weekdayResults)
        #expect(viewModel.remainingMinutes.isEmpty)
    }

    @Test @MainActor
    func departureSearchExcludesTheBusAtItsDepartureInstant() {
        var currentDate = makeTestDate(hour: 7, minute: 59)
        let viewModel = HomeViewModel(
            nowProvider: { currentDate }, defaults: makeIsolatedDefaults()
        )
        viewModel.setAutomaticUpdatesActive(false)
        let bus = viewModel.searchResults.first!
        let departure = BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
            for: bus.departure, from: currentDate, calendar: AppCalendar.japan
        )!
        currentDate = departure.addingTimeInterval(-1)
        viewModel.searchTime = currentDate
        viewModel.performSearch()
        #expect(viewModel.searchResults.first?.id == bus.id)

        for seconds in [0.0, 30.0] {
            currentDate = departure.addingTimeInterval(seconds)
            viewModel.searchTime = currentDate
            viewModel.performSearch()
            #expect(!viewModel.searchResults.contains { $0.id == bus.id })
            #expect(viewModel.searchResults.allSatisfy {
                (BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
                    for: $0.departure, from: currentDate, calendar: AppCalendar.japan
                ) ?? .distantPast) > currentDate
            })
        }
    }

    @Test @MainActor
    func otherWeekdaySearchKeepsTheBusAtTheSpecifiedMinute() {
        let currentDate = makeTestDate(hour: 8)
        let viewModel = HomeViewModel(
            nowProvider: { currentDate }, defaults: makeIsolatedDefaults()
        )
        viewModel.setAutomaticUpdatesActive(false)
        viewModel.serviceDay = .otherWeekday
        viewModel.searchTime = currentDate
        viewModel.performSearch()
        #expect(viewModel.searchResults.first?.departure == "8:00")
    }


    @Test @MainActor
    func departureBannerUsesTheEffectiveReferenceAndExplainsAdjustment() {
        let current = makeTestDate(hour: 9)
        let viewModel = HomeViewModel(nowProvider: { current }, defaults: makeIsolatedDefaults())
        viewModel.setAutomaticUpdatesActive(false)
        viewModel.selectOrigin(.mansion)
        viewModel.searchTime = makeTestDate(hour: 7)
        viewModel.performSearch()
        #expect(viewModel.searchTime == makeTestDate(hour: 7))
        #expect(viewModel.searchCriteriaDescription.contains("9:00以降に出発"))
        #expect(viewModel.searchCriteriaDescription.contains(L10n.Search.adjustedToCurrentTime))
        #expect(viewModel.searchResults.allSatisfy {
            (BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
                for: $0.departure, from: current, calendar: AppCalendar.japan
            ) ?? .distantPast) >= current
        })

        viewModel.searchTime = makeTestDate(hour: 18)
        viewModel.performSearch()
        #expect(viewModel.searchCriteriaDescription.contains("18:00以降に出発"))
        #expect(!viewModel.searchCriteriaDescription.contains(L10n.Search.adjustedToCurrentTime))

        viewModel.serviceDay = .otherWeekday
        viewModel.searchTime = makeTestDate(hour: 7)
        viewModel.performSearch()
        #expect(viewModel.searchCriteriaDescription.contains("7:00以降に出発"))
        #expect(!viewModel.searchCriteriaDescription.contains(L10n.Search.adjustedToCurrentTime))
    }

    @Test @MainActor
    func arrivalBannerRetainsTheRequestedDeadline() {
        let viewModel = HomeViewModel(
            nowProvider: { makeTestDate(hour: 9) }, defaults: makeIsolatedDefaults()
        )
        viewModel.setAutomaticUpdatesActive(false)
        viewModel.searchType = .arrival
        viewModel.searchTime = makeTestDate(hour: 7)
        viewModel.performSearch()
        #expect(viewModel.searchCriteriaDescription.contains("7:00までに到着"))
        #expect(!viewModel.searchCriteriaDescription.contains(L10n.Search.adjustedToCurrentTime))
    }


    @Test @MainActor
    func switchingToArrivalStartsWithAFutureDeadlineAndBoardableBuses() {
        let current = makeTestDate(hour: 9)
        let viewModel = HomeViewModel(nowProvider: { current }, defaults: makeIsolatedDefaults())
        viewModel.setAutomaticUpdatesActive(false)
        viewModel.selectOrigin(.mansion)
        viewModel.searchType = .arrival
        viewModel.performSearch()
        #expect(viewModel.searchTime >= current.addingTimeInterval(30 * 60))
        #expect(!viewModel.searchResults.isEmpty)
        #expect(viewModel.searchResults.allSatisfy {
            (BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
                for: $0.departure, from: current, calendar: AppCalendar.japan
            ) ?? .distantPast) > current
        })

        viewModel.searchTime = makeTestDate(hour: 7)
        viewModel.performSearch()
        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.searchCriteriaDescription.contains("7:00までに到着"))

        viewModel.serviceDay = .otherWeekday
        viewModel.performSearch()
        #expect(!viewModel.searchResults.isEmpty)
    }

    @Test @MainActor
    func restoredArrivalModeUsesAFutureDefaultAndKeepsExplicitFutureDeadline() {
        let current = makeTestDate(hour: 9)
        let defaults = makeIsolatedDefaults()
        defaults.set(HomeViewModel.SearchType.arrival.rawValue, forKey: "home.searchType")
        defaults.set(makeTestDate(hour: 7), forKey: "home.searchTime")
        let viewModel = HomeViewModel(nowProvider: { current }, defaults: defaults)
        viewModel.setAutomaticUpdatesActive(false)
        #expect(viewModel.searchTime >= current.addingTimeInterval(30 * 60))
        #expect(!viewModel.searchResults.isEmpty)

        defaults.set(makeTestDate(hour: 18), forKey: "home.searchTime")
        let future = HomeViewModel(nowProvider: { current }, defaults: defaults)
        future.setAutomaticUpdatesActive(false)
        #expect(future.searchTime == makeTestDate(hour: 18))
    }


    @Test @MainActor
    func locationRouteChangesExplainWhyTheResultsChanged() {
        let current = makeTestDate(hour: 8)
        let viewModel = HomeViewModel(nowProvider: { current }, defaults: makeIsolatedDefaults())
        viewModel.setAutomaticUpdatesActive(false)
        #expect(viewModel.locationAdjustmentMessage == nil)
        let station = CLLocation(latitude: 35.6485608, longitude: 140.0416924)
        viewModel.updateOriginForCurrentLocation(station, at: current)
        #expect(viewModel.selectedOrigin == .station)
        #expect(viewModel.routeDecision == .automatic)
        #expect(viewModel.locationAdjustmentMessage == L10n.Route.adjustedForLocation(
            viewModel.selectedOrigin.rawValue, viewModel.selectedDestination.rawValue
        ))
        #expect(viewModel.routeDecisionDescription.contains("現在地に合わせました"))

        viewModel.selectRouteFromWidget(.mansionToStation)
        #expect(viewModel.locationAdjustmentMessage == nil)
        viewModel.updateOriginForCurrentLocation(station, at: current)
        #expect(viewModel.selectedRoute == .mansionToStation)
        #expect(viewModel.locationAdjustmentMessage == nil)
    }

    @Test @MainActor
    func anUnchangedLocationRouteDoesNotClaimAChange() {
        let current = makeTestDate(hour: 8)
        let viewModel = HomeViewModel(nowProvider: { current }, defaults: makeIsolatedDefaults())
        viewModel.setAutomaticUpdatesActive(false)
        let mansion = CLLocation(latitude: 35.6589411, longitude: 140.0357708)
        viewModel.updateOriginForCurrentLocation(mansion, at: current)
        #expect(viewModel.selectedRoute == .mansionToStation)
        #expect(viewModel.locationAdjustmentMessage == nil)
        #expect(viewModel.routeDecisionDescription == L10n.Route.decisionAutomatic)
    }


    @Test @MainActor
    func departureSearchKeepsFourCandidates() {
        let viewModel = HomeViewModel(
            nowProvider: { makeTestDate(hour: 8) }, defaults: makeIsolatedDefaults()
        )
        viewModel.setAutomaticUpdatesActive(false)
        #expect(viewModel.searchResults.count == 4)
        #expect(Set(viewModel.searchResults.map(\.id)).count == 4)
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
        #expect(viewModel.searchResults.count == 4)
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
        let holiday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 22))!
        let substituteHoliday = calendar.date(from: DateComponents(year: 2027, month: 3, day: 22))!

        #expect(BusServiceCalendar.isServiceDay(weekday, calendar: calendar))
        #expect(!BusServiceCalendar.isServiceDay(saturday, calendar: calendar))
        #expect(!BusServiceCalendar.isServiceDay(holiday, calendar: calendar))
        #expect(!BusServiceCalendar.isServiceDay(substituteHoliday, calendar: calendar))
    }

    @Test
    func holidayDataHasAForwardLookingValidityWindow() {
        #expect(BusServiceCalendar.daysUntilHolidayDataExpires(from: Date()) > 90)
    }

    @Test
    func defaultServiceCalendarUsesJapanTime() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        // UTCでは8月10日ですが、日本では山の日の8月11日です。
        let date = utc.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 16))!
        #expect(!BusServiceCalendar.isServiceDay(date))
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
    func streetLightsFollowSunsetAndSunrise() {
        for season in Season.allCases {
            let daylight = SkyPalette.daylight(for: season)
            func isOn(_ hour: Double) -> Bool {
                SkyPalette.at(hour: hour, season: season).isStreetLightOn
            }

            // 昼と、日の入りの1時間前はまだ消えています。
            #expect(!isOn(daylight.solarNoon), "\(season)の南中")
            #expect(!isOn(daylight.sunset - 1), "\(season)の日の入り1時間前")
            // 日が沈んで暗くなってから、夜のあいだは点いています。
            #expect(isOn(daylight.sunset + 0.5), "\(season)の日の入り30分後")
            #expect(isOn(22), "\(season)の22時")
            #expect(isOn(2), "\(season)の2時")
            // 夜明けの30分前に消え、朝は消えたままです。
            #expect(!isOn(daylight.sunrise - 0.25), "\(season)の日の出15分前")
            #expect(!isOn(daylight.sunrise + 1), "\(season)の日の出1時間後")
        }

        // 冬は日の出が遅いので、5時45分でも点いています。
        // 4時30分で一律に消していたころは、冬の夜明け前が暗いままでした。
        #expect(SkyPalette.at(hour: 5.75, season: .winter).isStreetLightOn)
    }

    // MARK: - 文字の読みやすさ

    @Test
    func cardTextStaysReadableAtEveryHourAndSeason() {
        // カードは「空 → 半透明の白 → 不透明の地」を重ねた上に文字を置きます。
        // 季節で空の色を変えたことで、どこかの時刻で文字とカードが近づいていないかを確かめます。
        // 判定は初期値の濃さで行います。設定で地をいちばん薄くすると
        // カードはほぼ背景そのものになり、読みやすさより風景を優先した状態になります。
        let coverage = SkyCardOpacity.coverage(for: SkyCardOpacity.standard, isDense: false)
        var worst = (ratio: Double.infinity, season: Season.spring, hour: 0.0)
        var worstSecondary = (ratio: Double.infinity, season: Season.spring, hour: 0.0)

        for season in Season.allCases {
            for step in 0..<(24 * 4) {
                let hour = Double(step) / 4
                let palette = SkyPalette.at(hour: hour, season: season)

                let background = components(of: palette.skyBottom)
                let onSurface = blend(components(of: palette.surface), over: background)
                let card = blend(
                    components(of: palette.surfaceOpaque, alpha: coverage),
                    over: onSurface
                )
                let text = blend(components(of: palette.ink), over: card)

                let ratio = contrastRatio(text, card)
                if ratio < worst.ratio {
                    worst = (ratio, season, hour)
                }

                // 補足の文字も同じ地の上に置きます。チップの見出しや経路の控えめな
                // 表示に使うので、本文と同じ基準で読めることを求めます。
                let secondary = blend(components(of: palette.inkSecondary), over: card)
                let secondaryRatio = contrastRatio(secondary, card)
                if secondaryRatio < worstSecondary.ratio {
                    worstSecondary = (secondaryRatio, season, hour)
                }
            }
        }

        #expect(
            worst.ratio >= 4.5,
            "主な文字が最も読みにくいのは\(worst.season)の\(worst.hour)時で、比は\(worst.ratio)でした"
        )
        #expect(
            worstSecondary.ratio >= 4.5,
            "補足の文字が最も読みにくいのは\(worstSecondary.season)の\(worstSecondary.hour)時で、比は\(worstSecondary.ratio)でした"
        )
    }

    @Test
    func cardTextStaysReadableOnEveryDayOfTheYear() {
        // 季節の色は日ごとに隣の季節へ移るので、四季の代表日のあいだの日も確かめます。
        let coverage = SkyCardOpacity.coverage(for: SkyCardOpacity.standard, isDense: false)
        var worst = (ratio: Double.infinity, dayOfYear: 0, hour: 0.0)

        for dayOfYear in stride(from: 1, through: 365, by: 5) {
            let day = SeasonalDay(dayOfYear: dayOfYear)
            for step in 0..<(24 * 4) {
                let hour = Double(step) / 4
                let palette = SkyPalette.at(hour: hour, day: day)
                let background = components(of: palette.skyBottom)
                let onSurface = blend(components(of: palette.surface), over: background)
                let card = blend(
                    components(of: palette.surfaceOpaque, alpha: coverage),
                    over: onSurface
                )
                let ratio = contrastRatio(blend(components(of: palette.ink), over: card), card)
                if ratio < worst.ratio {
                    worst = (ratio, dayOfYear, hour)
                }
            }
        }

        #expect(
            worst.ratio >= 4.5,
            "主な文字が最も読みにくいのは\(worst.dayOfYear)日目の\(worst.hour)時で、比は\(worst.ratio)でした"
        )
    }

    @Test
    func accentTextStaysReadableAtEveryHourAndSeason() {
        var worstRatio = Double.infinity
        var worstReadableRatio = Double.infinity
        let coverage = SkyCardOpacity.coverage(for: SkyCardOpacity.standard, isDense: false)
        for season in Season.allCases {
            for step in 0..<(24 * 4) {
                let palette = SkyPalette.at(hour: Double(step) / 4, season: season)
                let ratio = contrastRatio(
                    components(of: palette.accentInk),
                    components(of: palette.accent)
                )
                worstRatio = min(worstRatio, ratio)

                let background = components(of: palette.skyBottom)
                let onSurface = blend(components(of: palette.surface), over: background)
                let card = blend(
                    components(of: palette.surfaceOpaque, alpha: coverage),
                    over: onSurface
                )
                worstReadableRatio = min(
                    worstReadableRatio,
                    contrastRatio(components(of: palette.accentReadable), card)
                )
            }
        }
        #expect(worstRatio >= 4.5, "強調色上の文字コントラスト比が\(worstRatio)でした")
        #expect(
            worstReadableRatio >= 4.5,
            "カード上の強調文字コントラスト比が\(worstReadableRatio)でした"
        )
    }

    @Test
    func semanticStatusColorsStayDistinguishableOnCards() {
        var worstWarningRatio = Double.infinity
        var worstPositiveRatio = Double.infinity
        let coverage = SkyCardOpacity.coverage(for: SkyCardOpacity.standard, isDense: false)

        for season in Season.allCases {
            for step in 0..<(24 * 4) {
                let palette = SkyPalette.at(hour: Double(step) / 4, season: season)
                let background = components(of: palette.skyBottom)
                let onSurface = blend(components(of: palette.surface), over: background)
                let card = blend(
                    components(of: palette.surfaceOpaque, alpha: coverage),
                    over: onSurface
                )
                worstWarningRatio = min(
                    worstWarningRatio,
                    contrastRatio(components(of: palette.warning), card)
                )
                worstPositiveRatio = min(
                    worstPositiveRatio,
                    contrastRatio(components(of: palette.positive), card)
                )
            }
        }

        // 状態色は必ず形や文言と併用します。非テキスト要素に必要な3:1を全配色で守ります。
        #expect(worstWarningRatio >= 3, "注意色のコントラスト比が\(worstWarningRatio)でした")
        #expect(worstPositiveRatio >= 3, "状態色のコントラスト比が\(worstPositiveRatio)でした")
    }

    // MARK: - 季節

    @Test
    func seasonFollowsTheMonth() {
        // 3〜5月が春、6〜8月が夏、9〜11月が秋、12〜2月が冬です。
        #expect(Season.from(month: 3) == .spring)
        #expect(Season.from(month: 5) == .spring)
        #expect(Season.from(month: 6) == .summer)
        #expect(Season.from(month: 8) == .summer)
        #expect(Season.from(month: 9) == .autumn)
        #expect(Season.from(month: 11) == .autumn)
        #expect(Season.from(month: 12) == .winter)
        #expect(Season.from(month: 1) == .winter)
        #expect(Season.from(month: 2) == .winter)
    }

    @Test
    func daylightLengthChangesWithTheSeason() {
        // 同じ17時でも、冬は暗く夏は明るく見えるようにします。
        let winter = SkyPalette.at(hour: 17, season: .winter).nightness
        let spring = SkyPalette.at(hour: 17, season: .spring).nightness
        let summer = SkyPalette.at(hour: 17, season: .summer).nightness

        #expect(winter > spring)
        #expect(spring > summer)
    }

    @Test
    func noonStaysBrightInEverySeason() {
        // 昼の長さを伸び縮みさせても、正午は必ず昼のままにします。
        for season in Season.allCases {
            #expect(SkyPalette.at(hour: 12, season: season).isNight == false)
            #expect(SkyPalette.at(hour: 0, season: season).isNight == true)
        }
    }

    @Test @MainActor
    func seasonFollowsJapanTimeAtTheEndOfTheMonth() {
        // 2026年2月28日16時（協定世界時）は、日本時間では3月1日1時です。
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = utc.date(from: DateComponents(year: 2026, month: 2, day: 28, hour: 16))!

        // 端末のタイムゾーンにかかわらず、運行判定と同じ日本時間の暦で春とします。
        #expect(Season.current(date: date) == .spring)
        #expect(Season.current(date: date, calendar: utc) == .winter)

        // 背景の時計も、日本時間の時刻と季節で配色を作ります。
        let clock = SkyClock(nowProvider: { date })
        clock.setAutomaticUpdatesActive(false)
        #expect(clock.palette.season == .spring)
        #expect(clock.palette.hour == 1)
    }

    @Test
    func previewPalettesKeepTheSeasonOfTheBackground() {
        // 設定画面のプレビューは、背景本体の季節を引き継いで別の時刻を描きます。
        // 今日の季節を改めて求めると、-UITestNowで固定した日付とずれることがあるためです。
        let background = SkyPalette.at(hour: 12, season: .winter)
        let morning = SkyPalette.at(hour: 7, season: background.season)

        #expect(morning.season == .winter)
        #expect(morning == SkyPalette.at(hour: 7, season: .winter))
    }

    @Test
    func forcedSeasonChangesOnlyTheDateUsedForSeasons() {
        let defaults = makeIsolatedDefaults()
        let calendar = AppCalendar.japan
        let summerEvening = makeTestDate(hour: 17, minute: 45)

        // 指定がなければ、渡した日付をそのまま使います。
        #expect(SeasonalDate.forcedDate(for: summerEvening, calendar: calendar, defaults: defaults) == nil)

        // 季節を指定すると、時刻は残したまま月日だけをその季節の代表日へ移します。
        defaults.set("winter", forKey: SeasonalDate.forceSeasonKey)
        let forced = SeasonalDate.forcedDate(for: summerEvening, calendar: calendar, defaults: defaults)
        let components = forced.map { calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0) }
        #expect(components?.year == 2026)
        #expect(components?.month == 1)
        #expect(components?.day == 15)
        #expect(components?.hour == 17)
        #expect(components?.minute == 45)
        #expect(forced.map { Season.current(date: $0, calendar: calendar) } == .winter)

        // どの季節も、代表日がその季節に含まれます。
        for season in Season.allCases {
            #expect(Season.from(month: season.representativeMonthDay.month) == season)
        }
    }

    @Test
    func forcedDayOfYearPicksThatDayAndOutranksTheSeason() {
        let defaults = makeIsolatedDefaults()
        let calendar = AppCalendar.japan
        let date = makeTestDate(hour: 9, minute: 30)
        defaults.set("summer", forKey: SeasonalDate.forceSeasonKey)

        // 起動引数は文字列で届きます。2026年はうるう年ではないので、60日目は3月1日です。
        defaults.set("60", forKey: SeasonalDate.forceDayOfYearKey)
        let forced = SeasonalDate.forcedDate(for: date, calendar: calendar, defaults: defaults)
        let components = forced.map { calendar.dateComponents([.month, .day, .hour, .minute], from: $0) }
        #expect(components?.month == 3)
        #expect(components?.day == 1)
        #expect(components?.hour == 9)
        #expect(components?.minute == 30)

        // 年の日数を超える値は大晦日に丸めます。
        defaults.set(400, forKey: SeasonalDate.forceDayOfYearKey)
        let lastDay = SeasonalDate.forcedDate(for: date, calendar: calendar, defaults: defaults)
            .map { calendar.dateComponents([.month, .day], from: $0) }
        #expect(lastDay?.month == 12)
        #expect(lastDay?.day == 31)
    }

    @Test
    func seasonOverrideIgnoresUnknownValues() {
        let defaults = makeIsolatedDefaults()
        let calendar = AppCalendar.japan
        let date = makeTestDate(hour: 12)

        // 綴りを誤った指定や範囲外の日数では、日付を差し替えません。
        defaults.set("rainy", forKey: SeasonalDate.forceSeasonKey)
        #expect(SeasonalDate.forcedDate(for: date, calendar: calendar, defaults: defaults) == nil)
        defaults.set("0", forKey: SeasonalDate.forceDayOfYearKey)
        #expect(SeasonalDate.forcedDate(for: date, calendar: calendar, defaults: defaults) == nil)
        #expect(Season(launchArgument: "Autumn") == .autumn)
        #expect(Season(launchArgument: "fall") == .autumn)
    }

    @Test
    func skyChangesGraduallyFromDayToDay() {
        // 隣り合う日の同じ時刻で、空の色がほとんど変わらないことを確かめます。
        // 季節を月で切り替えていたころは、8月31日から9月1日のような境目で
        // 一晩のうちにΔEが8〜11も変わっていました。
        // 2.0は、並べて見比べても違いに気づきにくい大きさです。
        let threshold = 2.0
        var worst = (difference: 0.0, dayOfYear: 0, hour: 0.0)

        for dayOfYear in 1...365 {
            // 12月31日の次は、翌年の1月1日と比べます。
            let nextDayOfYear = dayOfYear == 365 ? 1 : dayOfYear + 1
            for hour in [7, 12, 17.75, 22] {
                let today = SkyPalette.at(hour: hour, day: SeasonalDay(dayOfYear: dayOfYear))
                let tomorrow = SkyPalette.at(hour: hour, day: SeasonalDay(dayOfYear: nextDayOfYear))
                let difference = skyColorDifference(today, tomorrow)
                if difference > worst.difference {
                    worst = (difference, dayOfYear, hour)
                }
            }
        }

        #expect(
            worst.difference <= threshold,
            "\(worst.dayOfYear)日目から翌日への\(worst.hour)時の空の色差が\(worst.difference)でした"
        )
    }

    @Test
    func seasonsBlendBetweenTheirRepresentativeDays() {
        // 季節の代表日は、その季節の色だけになります。
        for season in Season.allCases {
            #expect(SeasonalDay(season: season).seasonBlend.weight(of: season) == 1)
        }

        // 5月31日は春と夏のちょうど中間です。4月15日の春の色から、夏の色へ半分近づきます。
        let lateMay = SeasonalDay(dayOfYear: 151).seasonBlend
        #expect(lateMay.earlier == .spring)
        #expect(lateMay.later == .summer)
        #expect(abs(lateMay.ratio - 0.5) < 0.05)

        // 秋から冬へは年をまたいで移ります。1月1日はほぼ冬の色です。
        let newYear = SeasonalDay(dayOfYear: 1).seasonBlend
        #expect(newYear.earlier == .autumn)
        #expect(newYear.later == .winter)
        #expect(newYear.weight(of: .winter) > 0.9)
        // 1年を通して、2つの季節の割合の合計は1です。
        for dayOfYear in stride(from: 1, through: 365, by: 3) {
            let blend = SeasonalDay(dayOfYear: dayOfYear).seasonBlend
            let total = Season.allCases.map(blend.weight(of:)).reduce(0, +)
            #expect(abs(total - 1) < 0.000_001)
        }
    }

    @Test
    func seasonsLookDifferentAtNoon() {
        // 同じ正午の空を季節どうしで比べ、どの組み合わせも見分けられる色差があることを確かめます。
        // 色差はCIELABのΔE（CIE76）です。2.3前後が見分けられる最小の差で、10を超えると別の色に見えます。
        let threshold = 10.0

        withKnownIssue("季節ごとの空の基本色を設計し直すまでは、春・秋・冬の正午がほぼ同じ色です（#65）") {
            for (index, first) in Season.allCases.enumerated() {
                for second in Season.allCases.dropFirst(index + 1) {
                    let difference = skyColorDifference(
                        SkyPalette.at(hour: 12, season: first),
                        SkyPalette.at(hour: 12, season: second)
                    )
                    #expect(
                        difference >= threshold,
                        "正午の\(first)と\(second)の空の色差が\(difference)でした"
                    )
                }
            }
        }
    }

    // MARK: - ショートカット（Siri）

    @Test
    func shortcutAnswerNamesTheRouteAndTheNextDeparture() {
        // 声で聞く人には画面がないので、経路と時刻が1文に入っている必要があります。
        let answer = NextBusAnswer.text(at: makeTestDate(hour: 10))

        #expect(!answer.isEmpty)
        // 経路名（出発地と目的地）が入っています。
        #expect(answer.contains("コロンブスシティ") || answer.contains("海浜幕張駅"))
        // 時刻が入っています。
        #expect(answer.contains(":"))
        // 便が見つからないときの文ではありません。
        #expect(answer != L10n.Shortcut.noService)
    }

    // MARK: - ウィジェットのタップ先

    @Test
    func widgetLinkCarriesTheRouteBothWays() {
        // ウィジェットのタップでアプリを開いたとき、見ていた経路が伝わる必要があります。
        for route in BusRoute.allCases {
            let link = SharedAppData.routeLink(for: route)
            #expect(link != nil)
            #expect(SharedAppData.route(from: link!) == route)
        }
    }

    @Test
    func widgetLinkIgnoresOtherURLs() {
        // 別のアプリ宛のURLや、経路の名前が違うURLは受け取りません。
        #expect(SharedAppData.route(from: URL(string: "https://example.com/route/mansion-station")!) == nil)
        #expect(SharedAppData.route(from: URL(string: "bustimeapp://settings/mansion-station")!) == nil)
        #expect(SharedAppData.route(from: URL(string: "bustimeapp://route/unknown-stop")!) == nil)
    }

    @Test @MainActor
    func openingFromTheWidgetSwitchesTheRoute() {
        let viewModel = HomeViewModel(
            nowProvider: { makeTestDate(hour: 10) },
            defaults: makeIsolatedDefaults()
        )

        viewModel.selectRouteFromWidget(.yokadoToMansion)

        #expect(viewModel.selectedRoute == .yokadoToMansion)
        #expect(viewModel.selectedOrigin == .yokado)
        #expect(viewModel.selectedDestination == .mansion)
        // 自分で選んだのと同じ扱いなので、決め方は手動になります。
        #expect(viewModel.routeDecision == .manual)
    }

    // MARK: - 日時の表し方

    @Test
    func notificationDateFollowsTheDeviceLanguage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let date = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 17, hour: 18, minute: 30)
        )!

        let japanese = BusNotificationTimeCalculator.displayString(
            date,
            locale: Locale(identifier: "ja_JP")
        )
        let english = BusNotificationTimeCalculator.displayString(
            date,
            locale: Locale(identifier: "en_US")
        )

        // 言語ごとに書式が変わることを確かめます。
        // 日本語に固定していたころは、どの言語でも同じ文字列になっていました。
        #expect(japanese != english)
        // 日本語は「8月17日」のように月日を漢字で区切ります。
        #expect(japanese.contains("月"))
        // アメリカ英語は12時間制なので、午後を表す語が付きます。
        #expect(english.contains("PM"))
        // 日本語は24時間制なので、午後を表す語は付きません。
        #expect(!japanese.contains("PM"))
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
        #expect(SkyPalette.at(hour: 18, season: .spring).ink == SkyPalette.at(hour: 12, season: .spring).ink)
        #expect(SkyPalette.at(hour: 21, season: .spring).ink == SkyPalette.at(hour: 2, season: .spring).ink)
        #expect(SkyPalette.at(hour: 12, season: .spring).ink != SkyPalette.at(hour: 2, season: .spring).ink)
    }

    @Test
    func cardSurfaceSwitchesTogetherWithTheInk() {
        // 地と文字は同じ境界で入れ替わる必要があります。
        // 片方だけ先に変わると、その間だけ読みにくくなります。
        #expect(SkyPalette.at(hour: 18, season: .spring).isNight == false)
        #expect(SkyPalette.at(hour: 21, season: .spring).isNight == true)
        #expect(SkyPalette.at(hour: 18, season: .spring).surface == SkyPalette.at(hour: 12, season: .spring).surface)
        #expect(SkyPalette.at(hour: 21, season: .spring).surface == SkyPalette.at(hour: 2, season: .spring).surface)
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

private struct StoredNotificationsEnvelope: Codable {
    let version: Int
    let notifications: [ScheduledBusNotification]
}

private func makeFutureScheduledNotification() -> ScheduledBusNotification {
    let departureDate = Date().addingTimeInterval(24 * 60 * 60)
    return ScheduledBusNotification(
        id: "bus_notification_test",
        busID: "test",
        originName: "海浜幕張駅",
        destinationName: "コロンブスシティ",
        stopSummary: nil,
        departure: "12:00",
        routeName: "test-route",
        departureDate: departureDate,
        notificationDate: departureDate.addingTimeInterval(-5 * 60),
        minutesBefore: 5
    )
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
    private(set) var callCount = 0

    func fetchCurrentWeather() async throws -> SkyWeather {
        callCount += 1
        return try result.get()
    }
}


// MARK: - 色の測り方

/// 色を赤・緑・青と不透明度に分解します。
private func components(of color: Color, alpha: Double? = nil) -> (r: Double, g: Double, b: Double, a: Double) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var opacity: CGFloat = 0
    UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &opacity)
    return (Double(red), Double(green), Double(blue), alpha ?? Double(opacity))
}

/// 半透明の色を下地に重ねた結果の色です。
private func blend(
    _ top: (r: Double, g: Double, b: Double, a: Double),
    over bottom: (r: Double, g: Double, b: Double, a: Double)
) -> (r: Double, g: Double, b: Double, a: Double) {
    (
        r: bottom.r + (top.r - bottom.r) * top.a,
        g: bottom.g + (top.g - bottom.g) * top.a,
        b: bottom.b + (top.b - bottom.b) * top.a,
        a: 1
    )
}

/// 2つの配色の空の色差です。
///
/// 上端と下端のそれぞれで色差を測り、平均を返します。
/// 背景の空はこの2色のあいだを段階的に塗り分けるため、両端を比べれば空全体の違いが分かります。
private func skyColorDifference(_ first: SkyPalette, _ second: SkyPalette) -> Double {
    let top = colorDifference(components(of: first.skyColor(at: 0)), components(of: second.skyColor(at: 0)))
    let bottom = colorDifference(components(of: first.skyColor(at: 1)), components(of: second.skyColor(at: 1)))
    return (top + bottom) / 2
}

/// CIELAB色空間での色差（ΔE*ab、CIE76）です。人の目に見える違いの大きさに近い値になります。
private func colorDifference(
    _ first: (r: Double, g: Double, b: Double, a: Double),
    _ second: (r: Double, g: Double, b: Double, a: Double)
) -> Double {
    let a = cieLab(first)
    let b = cieLab(second)
    return ((a.l - b.l) * (a.l - b.l) + (a.a - b.a) * (a.a - b.a) + (a.b - b.b) * (a.b - b.b)).squareRoot()
}

/// sRGBの色をCIELAB（D65白色点）へ変換します。
private func cieLab(_ color: (r: Double, g: Double, b: Double, a: Double)) -> (l: Double, a: Double, b: Double) {
    func linear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    func f(_ value: Double) -> Double {
        let epsilon = pow(6.0 / 29.0, 3)
        return value > epsilon ? cbrt(value) : value / (3 * pow(6.0 / 29.0, 2)) + 4.0 / 29.0
    }
    let red = linear(color.r)
    let green = linear(color.g)
    let blue = linear(color.b)
    let x = (0.4124 * red + 0.3576 * green + 0.1805 * blue) / 0.95047
    let y = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    let z = (0.0193 * red + 0.1192 * green + 0.9505 * blue) / 1.08883
    return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))
}

/// WCAGの相対輝度です。
private func relativeLuminance(_ color: (r: Double, g: Double, b: Double, a: Double)) -> Double {
    func channel(_ value: Double) -> Double {
        value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b)
}

/// WCAGのコントラスト比です。1が同じ色、21が黒と白です。
private func contrastRatio(
    _ first: (r: Double, g: Double, b: Double, a: Double),
    _ second: (r: Double, g: Double, b: Double, a: Double)
) -> Double {
    let a = relativeLuminance(first)
    let b = relativeLuminance(second)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)
}
