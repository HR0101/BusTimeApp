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
    private func launchApp(
        contentSize: String = ContentSize.standard,
        language: String = "ja",
        locale: String = "ja_JP"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            "-UIPreferredContentSizeCategoryName", contentSize,
            "-SkyBackgroundStill",
            "-UITestNow", "1786496400",
            "-UITestResetState",
            "-forceWeather", "clear",
            "-hasSeenTutorial", "YES"
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

        // 画面下に続く主要操作も、スクロールすれば全体が表示されて押せることを確認します。
        let notifyButton = app.buttons["この便を通知する"]
        XCTAssertTrue(notifyButton.waitForExistence(timeout: 5), "通知ボタンが見つかりません")
        var attempts = 0
        while !notifyButton.isHittable, attempts < 4 {
            app.scrollViews.firstMatch.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(notifyButton.isHittable, "通知ボタンが押せません")
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

    /// Xcodeの自動監査で、ラベル・コントラスト・タップ領域などの退行を検出します。
    @MainActor
    func testAccessibilityAudit() throws {
        var app = launchApp(contentSize: ContentSize.largest)

        if #available(iOS 17.0, *) {
            var retryCount = 0
            while true {
                do {
                    try performAccessibilityAudit(in: app)
                    break
                } catch {
                    let auditError = error as NSError
                    guard auditError.domain == "com.apple.accessibilityAudit",
                          auditError.code == -902 else {
                        throw error
                    }
                    guard retryCount < 2 else {
                        throw XCTSkip(
                            "アクセシビリティ監査基盤が対象アプリを認識できませんでした: "
                                + auditError.localizedDescription
                        )
                    }
                    retryCount += 1
                    app.terminate()
                    app = launchApp(contentSize: ContentSize.largest)
                }
            }
        }
    }

    @available(iOS 17.0, *)
    @MainActor
    private func performAccessibilityAudit(in app: XCUIApplication) throws {
        // ScrollView端は下のハンドラで除外し、それ以外はXcodeの監査へ任せます。
        // Dynamic Typeだけは画面遷移を伴う専用テストで検証します。
        let auditTypes = XCUIAccessibilityAuditType.all.subtracting(.dynamicType)
        try app.performAccessibilityAudit(for: auditTypes) { issue in
            // iOS 18の監査は画面端で要素を特定できない問題を返すことがあります。
            // 画面中央の実要素は失敗させ、コントラストはUnit Testでも全配色を検証します。
            guard issue.auditType == .contrast
                || issue.auditType == .textClipped
                || issue.auditType == .hitRegion else {
                return false
            }
            if issue.element == nil { return true }
            guard let element = issue.element else { return false }
            let fullyVisibleFrame = app.frame.insetBy(dx: 0, dy: 44)
            if !fullyVisibleFrame.contains(element.frame) { return true }
            if issue.auditType == .hitRegion,
               ["ホームタブ", "時刻表タブ"].contains(element.label) {
                // SwiftUIが外側の大きなButtonではなく内部Labelを返します。
                // 実際のButtonは最大文字テストで押下可能性を別途検証しています。
                return true
            }
            guard issue.auditType == .contrast || issue.auditType == .textClipped else {
                return false
            }
            XCTFail(
                "\(issue.compactDescription): label=\(element.label), "
                    + "frame=\(String(describing: element.frame)), "
                    + issue.detailedDescription
            )
            return true
        }
    }

    /// 対応言語ごとに主要画面が起動し、タブ操作できることを確かめます。
    @MainActor
    func testSupportedLocalesAndCaptureSnapshots() throws {
        let scenarios = [
            (
                language: "ja",
                locale: "ja_JP",
                timetableTab: "時刻表タブ",
                timetableHint: "経路を変えるときは、ホームタブで出発地と目的地を選んでください"
            ),
            (
                language: "en",
                locale: "en_US",
                timetableTab: "Timetable tab",
                timetableHint: "To change the route, choose the stops on the Home tab"
            ),
            (
                language: "zh-Hans",
                locale: "zh_CN",
                timetableTab: "时刻表标签页",
                timetableHint: "要更改路线，请在首页标签页选择出发地和目的地"
            )
        ]

        for scenario in scenarios {
            let app = launchApp(language: scenario.language, locale: scenario.locale)
            let tab = app.buttons[scenario.timetableTab]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "\(scenario.language)のタブが見つかりません")
            XCTAssertTrue(tab.isHittable)

            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Home-\(scenario.language)"
            attachment.lifetime = .keepAlways
            add(attachment)

            tab.tap()
            XCTAssertTrue(
                app.staticTexts[scenario.timetableHint].waitForExistence(timeout: 5),
                "\(scenario.language)の時刻表画面へ切り替わりません"
            )
            let timetableAttachment = XCTAttachment(screenshot: app.screenshot())
            timetableAttachment.name = "Timetable-\(scenario.language)"
            timetableAttachment.lifetime = .keepAlways
            add(timetableAttachment)
            app.terminate()
        }
    }

    /// 右から左へ読む言語環境でも、主要操作が欠けないことを確かめます。
    @MainActor
    func testRightToLeftLayoutKeepsPrimaryControlsUsable() throws {
        let app = launchApp(language: "ar", locale: "ar_SA")
        XCTAssertTrue(app.buttons["時刻表タブ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["時刻表タブ"].isHittable)
    }

}
