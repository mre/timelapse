import AppKit
import ScreenCaptureKit
import SwiftUI

struct RecorderView: View {
    @ObservedObject var engine: CaptureEngine
    @ObservedObject var permission: ScreenRecordingPermission
    @Environment(\.openWindow) private var openWindow
    @AppStorage("captureInterval") private var interval = 5.0
    @AppStorage("maxDimension") private var maxDimension = 1920
    @AppStorage("showsCursor") private var showsCursor = true
    @AppStorage("outputDirectory") private var outputPath = ""
    @State private var selectedDisplay: CGDirectDisplayID = 0
    @State private var loadingDisplays = false

    private var isIdle: Bool { engine.state == .idle }

    var body: some View {
        VStack(spacing: 12) {
            header
            if isIdle && !permission.isGranted {
                permissionAction
            } else {
                if let error = engine.errorMessage {
                    DisclosureGroup {
                        Text(error).font(.caption).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                    } label: {
                        Text("Recording needs attention").font(.caption)
                    }
                }
                if isIdle { setup } else { recordingStatus }
                controls
            }
            if let url = engine.lastRecording, isIdle {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    HStack {
                        Text("Movie saved")
                        Spacer()
                        Text("Show in Finder").foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 288)
        .tint(.gray)
        .task {
            permission.checkAccess()
            if permission.isGranted { await loadDisplays() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permission.checkAccess()
        }
        .onChange(of: permission.isGranted) { _, granted in
            if granted { Task { await loadDisplays() } }
        }
        .onChange(of: engine.state) { _, state in
            if state == .idle { permission.checkAccess() }
        }
        .onChange(of: engine.errorMessage) { _, _ in
            permission.checkAccess()
        }
    }

    private var header: some View {
        HStack {
            Text("Timelapse").font(.headline)
            Spacer()
            Menu {
                Button("Settings…") {
                    openWindow(id: "recording-settings")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",")
                Divider()
                Button("Quit Timelapse") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More options")
            .help("Settings and Quit")
        }
    }

    private var permissionAction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Screen Recording access is needed to get started.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                openWindow(id: "screen-recording-access")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                Text("Allow Screen Recording…")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    private var setup: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                if engine.displays.isEmpty {
                    Text(loadingDisplays ? "Finding displays…" : "No displays found")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await loadDisplays() }
                    } label: {
                        Text("Refresh")
                    }
                    .buttonStyle(.borderless)
                    .disabled(loadingDisplays)
                    .accessibilityLabel("Refresh displays")
                } else {
                    Picker("Display", selection: $selectedDisplay) {
                        ForEach(engine.displays, id: \.displayID) { display in
                            Text(displayName(display)).tag(display.displayID)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 8) {
                Picker("Capture every", selection: $interval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                }
                .help("One hour makes approximately \(String(format: "%.0f", 3600 / interval / 30)) seconds of video.")
            }
        }
        .controlSize(.regular)
    }

    private var recordingStatus: some View {
        HStack(spacing: 8) {
            if engine.state == .recording {
                Circle().fill(.red).frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(engine.state.label).font(.callout)
                Text("\(engine.frameCount.formatted()) frames captured")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(String(format: "%.1f s", Double(engine.frameCount) / 30))
                .font(.system(.title3, design: .rounded).monospacedDigit())
                .accessibilityLabel("\(String(format: "%.1f", Double(engine.frameCount) / 30)) seconds of video")
                .help("Movie duration")
        }
        .padding(.vertical, 4)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            switch engine.state {
            case .idle:
                Button {
                    Task {
                        await engine.start(
                            displayID: selectedDisplay,
                            configuration: RecordingConfiguration(
                                interval: interval, maxDimension: maxDimension, showsCursor: showsCursor),
                            directory: RecordingDestination.url(for: outputPath)
                        )
                    }
                } label: {
                    Text("Start Recording")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(loadingDisplays || !engine.displays.contains(where: { $0.displayID == selectedDisplay }))
                .keyboardShortcut(.return, modifiers: [])
            case .recording, .paused:
                Button {
                    if engine.state == .paused { engine.resume() } else { engine.pause() }
                } label: {
                    Text(engine.state == .paused ? "Resume" : "Pause")
                        .frame(maxWidth: .infinity)
                }
                Button {
                    Task { await engine.stop() }
                } label: {
                    Text("Stop & Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            case .starting, .finishing:
                ProgressView().controlSize(.small)
                Text(engine.state == .starting ? "Getting ready…" : "Saving movie…")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    @MainActor private func loadDisplays() async {
        permission.checkAccess()
        guard permission.isGranted, isIdle, !loadingDisplays else { return }
        loadingDisplays = true
        defer { loadingDisplays = false }
        await engine.refreshDisplays()
        if !engine.displays.contains(where: { $0.displayID == selectedDisplay }) {
            selectedDisplay = engine.displays.first?.displayID ?? 0
        }
    }

    private func displayName(_ display: SCDisplay) -> String {
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
                == display.displayID
        }
        return screen?.localizedName ?? "Display \(display.displayID)"
    }
}
