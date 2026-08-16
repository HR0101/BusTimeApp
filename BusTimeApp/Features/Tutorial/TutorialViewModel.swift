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
        Page(id: 0, title: L10n.Tutorial.page1Title, description: L10n.Tutorial.page1Description, systemName: "bus.fill"),
        Page(id: 1, title: L10n.Tutorial.page2Title, description: L10n.Tutorial.page2Description, systemName: "clock.arrow.circlepath"),
        Page(id: 2, title: L10n.Tutorial.page3Title, description: L10n.Tutorial.page3Description, systemName: "bell.badge.fill")
    ]

    var isLastPage: Bool {
        currentPage == pages.index(before: pages.endIndex)
    }

    func nextPage() {
        guard !isLastPage else { return }
        currentPage += 1
    }
}
