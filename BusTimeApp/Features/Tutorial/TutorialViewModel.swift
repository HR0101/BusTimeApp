import Foundation
import Combine

@MainActor
final class TutorialViewModel: ObservableObject {
    struct Page: Identifiable {
        let id: Int
        let title: String
        let description: String
        let systemName: String
    }

    @Published var currentPage = 0

    let pages: [Page] = [
        Page(id: 0, title: "バスの時間を、\nもっと気持ちよく", description: "必要な便だけを、見やすいカードで確認できます。", systemName: "bus.fill"),
        Page(id: 1, title: "今すぐ乗れる便を\nすばやく検索", description: "ルートと時刻を選んで、次のバスを見つけましょう。", systemName: "clock.arrow.circlepath"),
        Page(id: 2, title: "乗り遅れを\nそっと防止", description: "ベルから通知やLive Activityを設定できます。", systemName: "bell.badge.fill")
    ]

    var isLastPage: Bool {
        currentPage == pages.index(before: pages.endIndex)
    }

    func nextPage() {
        guard !isLastPage else { return }
        currentPage += 1
    }
}
