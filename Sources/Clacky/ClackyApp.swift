import SwiftUI

@main
struct ClackyApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            MenuBarLabel(state: state)
        }
        .menuBarExtraStyle(.window)

        Window("Clacky", id: "main") {
            MainWindow(state: state)
        }
        .defaultSize(width: 900, height: 540)
        .commands {
            CommandGroup(replacing: .appSettings) {
                OpenWindowButton(title: "Settings…", shortcut: ",")
            }
        }
    }
}

/// The menu-bar icon. It is on screen from launch, so its onAppear is the
/// one reliable place to open the window when access is missing.
private struct MenuBarLabel: View {
    @ObservedObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: state.enabled ? "keyboard" : "speaker.slash")
            .onAppear {
                if state.opensWindowOnLaunch {
                    DispatchQueue.main.async { openWindow(id: "main") }
                }
            }
    }
}

struct OpenWindowButton: View {
    let title: String
    var shortcut: KeyEquivalent? = nil
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let button = Button(title) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        if let shortcut {
            button.keyboardShortcut(shortcut)
        } else {
            button
        }
    }
}
