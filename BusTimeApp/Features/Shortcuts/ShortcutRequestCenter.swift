import Combine
import Foundation

/// ショートカットからアプリ本体へ頼む操作です。
enum ShortcutAction: Equatable {
  /// 指定した経路のホームを開きます。
  case openRoute(BusRoute)
  /// 指定した経路の次の便に通知を設定し、必要ならLive Activityも開始します。
  case startBusAlert(route: BusRoute, minutesBefore: Int, startsLiveActivity: Bool)
}

/// 預けられた1件の依頼です。
struct ShortcutRequest: Equatable, Identifiable {
  let id: UUID
  let action: ShortcutAction
}

/// 依頼を処理した結果です。
enum ShortcutOutcome: Equatable {
  /// 成功です。ショートカットが返す文を持ちます。
  case succeeded(String)
  /// 失敗です。利用者へ伝える理由を持ちます。
  case failed(String)
  /// 画面が一定時間内に処理しませんでした。
  case noResponse
}

/// ショートカットの実行を失敗として終えるときのエラーです。
///
/// 自動化の途中で失敗に気づけるよう、成功を装った文を返さずエラーとして投げます。
enum ShortcutActionError: Error, CustomLocalizedStringResourceConvertible {
  case failed(String)

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case let .failed(message):
      // 文はすでに端末の言語へ翻訳済みなので、そのまま表示します。
      return LocalizedStringResource(stringLiteral: message)
    }
  }
}

extension ShortcutOutcome {
  /// 成功なら文を返し、失敗や無応答ならエラーとして投げます。
  func requireSuccessMessage() throws -> String {
    switch self {
    case let .succeeded(message):
      return message
    case let .failed(message):
      throw ShortcutActionError.failed(message)
    case .noResponse:
      throw ShortcutActionError.failed(L10n.Shortcut.noResponse)
    }
  }
}

/// ショートカットとアプリの画面のあいだで、依頼を受け渡します。
///
/// 通知やLive Activityの状態は、画面が持つViewModelの中にあります。
/// ショートカットが別の入れ物を作って同じ保存領域へ書くと、起動中のViewModelが
/// 古い内容で上書きして、OS側の通知と記録がずれてしまいます。
/// そこで、ショートカットは依頼をここへ預け、画面が既存の処理で実行して結果を返します。
@MainActor
final class ShortcutRequestCenter: ObservableObject {
  static let shared = ShortcutRequestCenter()

  /// 画面が依頼を処理するまで待つ時間の既定値です。
  nonisolated static let defaultResponseTimeout: Duration = .seconds(15)

  /// 画面がまだ受け取っていない依頼です。
  @Published private(set) var pendingRequest: ShortcutRequest?

  private let responseTimeout: Duration
  private var continuations: [UUID: CheckedContinuation<ShortcutOutcome, Never>] = [:]
  private var timeoutTasks: [UUID: Task<Void, Never>] = [:]

  init(responseTimeout: Duration = ShortcutRequestCenter.defaultResponseTimeout) {
    self.responseTimeout = responseTimeout
  }

  /// 依頼を預け、画面が処理を終えるまで待って結果を返します。
  func submit(_ action: ShortcutAction) async -> ShortcutOutcome {
    // まだ受け取られていない前の依頼は、この依頼に置き換えます。
    if let stale = pendingRequest {
      finish(stale.id, with: .noResponse)
    }

    let request = ShortcutRequest(id: UUID(), action: action)
    let timeout = responseTimeout

    return await withCheckedContinuation { continuation in
      continuations[request.id] = continuation
      pendingRequest = request
      // 画面が受け取れない状態が続いても、ショートカットが待ち続けないようにします。
      timeoutTasks[request.id] = Task { [weak self] in
        try? await Task.sleep(for: timeout)
        guard !Task.isCancelled else { return }
        self?.finish(request.id, with: .noResponse)
      }
    }
  }

  /// 画面が依頼を受け取ります。受け取った依頼は、預かり中ではなくなります。
  func takePendingRequest() -> ShortcutRequest? {
    guard let request = pendingRequest else { return nil }
    pendingRequest = nil
    return request
  }

  /// 依頼の結果を伝え、待っているショートカットを再開します。
  ///
  /// 同じ依頼に何度呼ばれても、再開は一度だけです。
  func finish(_ id: UUID, with outcome: ShortcutOutcome) {
    timeoutTasks.removeValue(forKey: id)?.cancel()
    if pendingRequest?.id == id {
      pendingRequest = nil
    }
    continuations.removeValue(forKey: id)?.resume(returning: outcome)
  }
}
