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

}
