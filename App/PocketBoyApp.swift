import SwiftUI

@main
struct PocketBoyApp: App {
    @StateObject private var hub = Hub()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ShelfView()
                .environmentObject(hub)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { phase in
                    hub.scenePhaseChanged(phase)
                }
        }
    }
}
