//
//  BusTimeAppUITests.swift
//  BusTimeAppUITests
//
//  Created by hara ryuto   on 2025/06/13.
//

import XCTest

final class BusTimeAppUITests: XCTestCase {

    /// 文字サイズの指定です。iOSが受け付ける名前をそのまま使います。
    private enum ContentSize {
        static let standard = "UICTContentSizeCategoryLarge"
        static let largest = "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - 起動の共通処理

    /// 条件を明示してアプリを起動します。
    ///
    /// 端末の言語や文字サイズをそのまま使うと、実行する環境によって結果が変わります。
    /// テストでは日本語と指定の文字サイズに固定し、どこで動かしても同じ判定になるようにします。
    ///
    /// 背景も静止させます。動き続ける層があるとアプリが静止状態にならず、
    /// 画面の問い合わせが応答を待ち続けて時間切れになることがあるためです。
    @MainActor
    private func launchApp(contentSize: String = ContentSize.standard) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP",
            "-UIPreferredContentSizeCategoryName", contentSize,
            "-SkyBackgroundStill"
        ]
        app.launch()
        dismissTutorialIfNeeded(in: app)
        return app
    }

    /// 初回起動時だけ出るチュートリアルを閉じます。
    @MainActor
    private func dismissTutorialIfNeeded(in app: XCUIApplication) {
        guard app.buttons["次へ"].waitForExistence(timeout: 3) else { return }

        while app.buttons["次へ"].exists {
            app.buttons["次へ"].tap()
        }
        if app.buttons["はじめる"].waitForExistence(timeout: 3) {
            app.buttons["はじめる"].tap()
        }
    }

    // MARK: - 画面の切り替え

    @MainActor
    func testMainTabsSwitchBetweenHomeAndTimetable() throws {
        let app = launchApp()

        let timetableTab = app.buttons["時刻表タブ"]
        XCTAssertTrue(timetableTab.waitForExistence(timeout: 5))
        timetableTab.tap()

        // 時刻表タブだけに出る案内文で、画面が切り替わったことを確かめます。
        let timetableGuidance = app.staticTexts["経路を変えるときは、ホームタブで出発地と目的地を選んでください"]
        XCTAssertTrue(timetableGuidance.waitForExistence(timeout: 5))

        app.buttons["ホームタブ"].tap()
        // ホームタブだけに出る見出しで、戻れたことを確かめます。
        XCTAssertTrue(app.staticTexts["いつのバス"].waitForExistence(timeout: 5))
    }

    // MARK: - 文字サイズ

    /// 文字を最大にしても、主要な操作が画面から消えたり押せなくなったりしないことを確かめます。
    ///
    /// 文字が大きくなると枠から溢れて隠れることがあります。
    /// 見た目の崩れは目視でしか気づけないことが多いため、
    /// 少なくとも「そこにあって押せる」ことは自動で守ります。
    @MainActor
    func testKeyControlsRemainUsableAtLargestTextSize() throws {
        let app = launchApp(contentSize: ContentSize.largest)

        // 運行日の選択
        let today = app.buttons["今日"]
        XCTAssertTrue(today.waitForExistence(timeout: 5), "運行日の選択が見つかりません")
        XCTAssertTrue(today.isHittable, "運行日の選択が押せません")

        // 出発地と目的地の入れ替え
        let swap = app.buttons["出発地と目的地を入れ替える"]
        XCTAssertTrue(swap.exists, "入れ替えボタンが見つかりません")

        // タブ
        XCTAssertTrue(app.buttons["時刻表タブ"].isHittable, "時刻表タブが押せません")
        XCTAssertTrue(app.buttons["ホームタブ"].isHittable, "ホームタブが押せません")
    }

    /// 文字を最大にしても、時刻表のマスが押せることを確かめます。
    @MainActor
    func testTimetableCellsRemainTappableAtLargestTextSize() throws {
        let app = launchApp(contentSize: ContentSize.largest)

        app.buttons["時刻表タブ"].tap()

        // 時刻のマスは「◯◯発、◯◯着」という読み上げ文を持ちます。
        let cell = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "発、")
        ).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "時刻のマスが見つかりません")
        XCTAssertTrue(cell.isHittable, "時刻のマスが押せません")
    }

    // MARK: - 読み上げ

    /// 主要な操作に読み上げ用の説明が付いていることを確かめます。
    @MainActor
    func testPrimaryControlsHaveAccessibilityLabels() throws {
        let app = launchApp()

        for label in ["設定した通知を確認", "設定を開く", "使い方を開く", "出発地と目的地を入れ替える"] {
            XCTAssertTrue(
                app.buttons[label].waitForExistence(timeout: 5),
                "\(label) の読み上げ説明が見つかりません"
            )
        }
    }

    // MARK: - 起動時間

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
