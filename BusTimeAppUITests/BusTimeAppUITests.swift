//
//  BusTimeAppUITests.swift
//  BusTimeAppUITests
//
//  Created by hara ryuto   on 2025/06/13.
//

import XCTest

final class BusTimeAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testMainTabsSwitchBetweenHomeAndTimetable() throws {
        let app = XCUIApplication()
        app.launch()

        // 初回起動時だけチュートリアルが表示されるため、完了してからタブを確認します。
        if app.buttons["次へ"].waitForExistence(timeout: 3) {
            for _ in 0..<2 {
                XCTAssertTrue(app.buttons["次へ"].waitForExistence(timeout: 3))
                app.buttons["次へ"].tap()
            }
            XCTAssertTrue(app.buttons["はじめる"].waitForExistence(timeout: 3))
            app.buttons["はじめる"].tap()
        }

        let timetableTab = app.buttons["時刻表タブ"]
        XCTAssertTrue(timetableTab.waitForExistence(timeout: 5))
        timetableTab.tap()

        // 時刻表タブだけに表示される案内文で、画面が切り替わったことを確かめます。
        let timetableGuidance = app.staticTexts["経路を変えるときは、ホームタブで出発地と目的地を選んでください"]
        XCTAssertTrue(timetableGuidance.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ホームタブ"].exists)

        app.buttons["ホームタブ"].tap()
        // ホームタブだけに表示される検索パネルの見出しを確かめます。
        XCTAssertTrue(app.staticTexts["どこからどこへ"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
