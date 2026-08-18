import SwiftUI

@main
struct BusTimeAppApp: App {
    init() {
        AppTestSupport.resetPersistentStateIfNeeded()
        AppDiagnostics.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
