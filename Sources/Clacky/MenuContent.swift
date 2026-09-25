import SwiftUI

struct MenuContent: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            if !state.hasPermission {
                permissionBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            packList
                .padding(.horizontal, 16)

            volumeRow
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

            if let error = state.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            Divider()

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 300)
        .environment(\.keycapTheme, state.theme)
        .onAppear { state.refresh() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(state.statusColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Clacky")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Text(state.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Enabled", isOn: $state.enabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .keyboardShortcut("e")
                .help("Turn sounds on or off (⌘E)")
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clacky can't hear your keys yet. Allow it under Input Monitoring, then come back here.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Input Monitoring settings") { state.requestPermission() }
                .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    // MARK: Packs as keycaps

    private var packList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sound pack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    state.preview()
                } label: {
                    Label("Preview", systemImage: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(state.isLoadingPack || state.selectedPack.isEmpty)
                .help("Play a sample from the selected pack")
            }
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 6) {
                    ForEach(state.packInfos) { info in
                        PackRow(title: info.displayName,
                                  selected: info.folderName == state.selectedPack,
                                  loading: state.isLoadingPack && info.folderName == state.selectedPack)
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.12)) {
                                    state.selectPack(info.folderName, preview: true)
                                }
                            }
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 3)
            }
            .frame(maxHeight: 208)
        }
    }

    // MARK: Volume

    private var volumeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Slider(value: $state.volume, in: 0...1)
            Text("\(Int((state.volume * 100).rounded()))%")
                .font(.system(.caption, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .accessibilityLabel("Volume")
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Toggle("Release sounds", isOn: $state.releaseSounds)
                Toggle("Pitch variation", isOn: $state.pitchVariation)
            }
            .toggleStyle(.checkbox)
            .font(.callout)
            HStack {
                Button("Open packs folder") { state.openPacksFolder() }
                    .buttonStyle(.link)
                    .font(.callout)
                Spacer()
                Toggle("Launch at login", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
                    .toggleStyle(.checkbox)
                    .font(.callout)
            }
            HStack {
                OpenWindowButton(title: "Open Clacky…")
                    .controlSize(.small)
                Spacer()
                Button("Quit Clacky") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
                    .controlSize(.small)
            }
        }
    }
}
