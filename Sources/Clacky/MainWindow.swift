import SwiftUI
import ClackyCore

struct MainWindow: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 20) {
                settingsColumn
                    .frame(width: 260)
                VStack(alignment: .leading, spacing: 10) {
                    KeyboardChassis(padding: 14) {
                        KeyboardView(pressed: state.pressed) { state.previewKey($0) }
                    }
                    .frame(maxWidth: .infinity)
                    Text("Keys light up as you type. Click a key to hear it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    MutedAppsSection(state: state)
                        .padding(.top, 8)
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
        .frame(minWidth: 760, minHeight: 520)
        .environment(\.keycapTheme, state.theme)
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
            ThemePicker(selection: $state.theme)
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
                Toggle("Stereo by key position", isOn: $state.stereo)
                    .help("Left-hand keys sound in your left ear, right-hand keys in your right")
                Toggle("Launch at login", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
            }
            .toggleStyle(.checkbox)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Circle().fill(state.statusColor).frame(width: 8, height: 8)
            Text(state.statusText).font(.callout)
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

/// Apps in which Clacky stays silent, plus the global shortcut.
private struct MutedAppsSection: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Muted apps").font(.headline)
                Spacer()
                if let other = state.lastOtherApp, let id = other.bundleIdentifier, !state.mutedApps.contains(id) {
                    Button("Mute in \(other.localizedName ?? id)") { state.muteApp(id) }
                        .controlSize(.small)
                }
                Menu("Add app") {
                    ForEach(state.mutableRunningApps, id: \.processIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "App") {
                            if let id = app.bundleIdentifier { state.muteApp(id) }
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .controlSize(.small)
            }
            if state.mutedApps.bundleIDs.isEmpty {
                Text("Clacky stays quiet while one of these apps is in front, for example during a video call.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                FlowRow(items: state.mutedApps.bundleIDs) { id in
                    HStack(spacing: 6) {
                        if let icon = state.appIcon(for: id) {
                            Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                        }
                        Text(state.appName(for: id)).font(.callout)
                        Button { state.unmuteApp(id) } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help("Unmute \(state.appName(for: id))")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.07)))
                }
            }
            Divider()
            HStack(spacing: 8) {
                Toggle("\(GlobalHotKey.Combo.clackyToggle.display) turns sounds on and off from any app", isOn: $state.hotkeyEnabled)
                    .toggleStyle(.checkbox)
                if state.hotkeyUnavailable {
                    Text("Another app is using this shortcut.").font(.caption).foregroundStyle(.red)
                }
            }
        }
    }
}

/// Lays chips out left to right, wrapping onto new lines.
private struct FlowRow<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, point) in zip(subviews, arrange(subviews, width: bounds.width).points) {
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), points)
    }
}

/// Four small keycap pairs, one per theme; the chosen one is ringed.
private struct ThemePicker: View {
    @Binding var selection: KeycapTheme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Keycaps").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(KeycapTheme.all) { theme in
                    Button { selection = theme } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 3) {
                                swatch(theme, tone: .alpha, label: "A")
                                swatch(theme, tone: .modifier, label: "⌘")
                            }
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(theme.id == selection.id ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            Text(theme.name).font(.caption2)
                                .foregroundStyle(theme.id == selection.id ? Color.primary : Color.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(theme.name) keycaps")
                    .accessibilityAddTraits(theme.id == selection.id ? .isSelected : [])
                }
            }
        }
    }

    private func swatch(_ theme: KeycapTheme, tone: KeyCap.Tone, label: String) -> some View {
        Keycap3D(palette: .resolve(theme, tone: tone, keyCode: nil, scheme: scheme),
                 pressed: false, depth: 2.5, cornerRadius: 4) {
            Text(label).font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .frame(width: 22, height: 22)
    }
}
