import UIKit

/// 操作に触覚で返事をするための入り口です。
///
/// 画面の変化だけでは、押したことが伝わりにくい操作があります。
/// 経路の入れ替えのように結果が一瞬で終わるものや、通知の登録のように
/// 成否がある操作に、軽い手応えを添えます。
///
/// 鳴らしすぎると煩わしくなるため、使うのは「利用者が自分で押した操作」だけにし、
/// 画面が自動で更新される場面では鳴らしません。
enum SkyHaptics {
  /// 押した手応えです。切り替えや入れ替えのように、その場で終わる操作に使います。
  static func tap() {
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
  }

  /// うまくいったことを伝える手応えです。
  static func success() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }

  /// うまくいかなかったことを伝える手応えです。
  static func failure() {
    UINotificationFeedbackGenerator().notificationOccurred(.error)
  }
}
