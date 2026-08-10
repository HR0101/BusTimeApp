import Foundation

enum HomeState: Equatable {
    case idle
    case searching
    case ready
    case empty
    case serviceUnavailable(String)
    case failed(String)
}

enum HomeEvent {
    case searchStarted
    case searchSucceeded(hasResults: Bool)
    case serviceUnavailable(String)
    case failed(String)
    case reset
}

/// ホーム画面の検索状態を管理する小さなReducerです。
/// 検索ロジックそのものはViewModelに残し、状態遷移だけをここへ分離します。
struct HomeStateMachine {
    private(set) var state: HomeState = .idle

    mutating func send(_ event: HomeEvent) {
        switch event {
        case .searchStarted:
            state = .searching
        case let .searchSucceeded(hasResults):
            state = hasResults ? .ready : .empty
        case let .serviceUnavailable(message):
            state = .serviceUnavailable(message)
        case let .failed(message):
            state = .failed(message)
        case .reset:
            state = .idle
        }
    }
}
