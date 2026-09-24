import SwiftUI

struct MenuContent: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enabled", isOn: $state.enabled)
                .keyboardShortcut("e")

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                Slider(value: $state.volume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
            }

            Picker("Sound Pack", selection: Binding(get: { state.selectedPack }, set: { state.selectPack($0) })) {
                ForEach(state.availablePacks, id: \.self) { Text($0).tag($0) }
            }

            Button("Open Packs Folder") { state.openPacksFolder() }

            Divider()

            if !state.hasPermission {
                Button("Grant Input Monitoring…") { state.requestPermission() }
                    .foregroundStyle(.red)
            }

            if let error = state.lastError {
                Text(error).font(.caption).foregroundStyle(.red).lineLimit(3)
            }

            Toggle("Launch at Login", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))

            Divider()

            Button("Quit Clacky") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 280)
        .onAppear { state.refresh() }
    }
}
