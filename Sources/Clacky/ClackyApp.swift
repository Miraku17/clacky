import SwiftUI
import ClackyCore

@main
struct ClackyApp: App {
    var body: some Scene {
        MenuBarExtra("Clacky", systemImage: "keyboard") {
            Text("Clacky \(ClackyCoreVersion.string)")
        }
    }
}
