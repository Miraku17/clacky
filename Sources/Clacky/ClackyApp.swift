import SwiftUI

@main
struct ClackyApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            Image(systemName: state.enabled ? "keyboard" : "speaker.slash")
        }
        .menuBarExtraStyle(.window)
    }
}
