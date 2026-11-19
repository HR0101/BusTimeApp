import AppIntents
import Foundation

/// 指定した経路のホームをアプリで開くショートカットです。
///
/// ウィジェットをタップしたときと同じく、選んだ経路を「自分で選んだ経路」として
/// 扱います。位置情報が後から届いても、この経路は上書きされません。
@available(iOS 16.0, *)
struct OpenRouteIntent: AppIntent {
  static var title: LocalizedStringResource { "shortcut.openRouteTitle" }
  static var description: IntentDescription {
    IntentDescription(LocalizedStringResource("shortcut.openRouteDescription"))
  }

  /// 画面を見せるのが目的なので、アプリを開きます。
  static var openAppWhenRun: Bool { true }

  @Parameter(title: "shortcut.routeParameter")
  var route: BusRouteOption

  @MainActor
  func perform() async throws -> some IntentResult {
    let outcome = await ShortcutRequestCenter.shared.submit(.openRoute(route.route))
    // 開けなかったときは、成功を装わずショートカットを失敗として終えます。
    _ = try outcome.requireSuccessMessage()
    return .result()
  }
}
