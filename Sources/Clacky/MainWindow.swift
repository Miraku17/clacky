import SwiftUI

struct MainWindow: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                settingsColumn
                    .frame(width: 260)
                VStack(alignment: .leading, spacing: 10) {
                    KeyboardView(pressed: state.pressed) { state.previewKey($0) }
                        .frame(maxWidth: .infinity)
                    Text("Keys light up as you type. Click a key to hear it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(20)
            Spacer(minLength: 0)
            Divider()
            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
        .frame(minWidth: 760, minHeight: 460)
        .onAppear { state.windowDidAppear(); state.refresh() }
    }

    private var settingsColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Clacky").font(.system(.title2, design: .rounded, weight: .semibold))
                Spacer()
                Toggle("Enabled", isOn: $state.enabled).toggleStyle(.switch).labelsHidden()
            }
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: $state.volume, in: 0...1)
                Text("\(Int((state.volume * 100).rounded()))%")
                    .font(.system(.caption, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
            Text("Sound pack").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(state.packInfos) { info in
                        PackRow(title: info.displayName,
                                selected: info.folderName == state.selectedPack,
                                loading: state.isLoadingPack && info.folderName == state.selectedPack)
                            .onTapGesture { withAnimation(.easeOut(duration: 0.12)) { state.selectPack(info.folderName, preview: true) } }
                    }
                }
                .padding(3)
            }
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Key release sounds", isOn: $state.releaseSounds)
                if !state.packHasReleaseSounds {
                    Text("This pack has no release sounds.").font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Pitch variation", isOn: $state.pitchVariation)
                Toggle("Launch at login", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
            }
            .toggleStyle(.checkbox)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Circle().fill(state.isListening ? Color.green : Color.orange).frame(width: 8, height: 8)
            Text(state.isListening ? "Listening" : "Needs keyboard access").font(.callout)
            if !state.hasPermission {
                Button("Open Input Monitoring settings") { state.requestPermission() }.controlSize(.small)
            }
            if let error = state.lastError {
                Text(error).font(.caption).foregroundStyle(.red).lineLimit(1)
            }
            Spacer()
            Button("Open packs folder") { state.openPacksFolder() }.buttonStyle(.link)
        }
    }
}
