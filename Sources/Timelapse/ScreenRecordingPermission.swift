import AppKit
import Combine
import CoreGraphics
import SwiftUI

@MainActor
final class ScreenRecordingPermission: ObservableObject {
    @Published private(set) var isGranted: Bool
    @Published private(set) var hasRequested: Bool
    @Published private(set) var actionError: String?
    private let defaults: UserDefaults
    private let preflight: () -> Bool
    private let request: () -> Bool

    init(
        defaults: UserDefaults = .standard,
        preflight: @escaping () -> Bool = { CGPreflightScreenCaptureAccess() },
        request: @escaping () -> Bool = { CGRequestScreenCaptureAccess() }
    ) {
        self.defaults = defaults
        self.preflight = preflight
        self.request = request
        isGranted = preflight()
        hasRequested = defaults.bool(forKey: "hasRequestedScreenRecording")
    }

    func checkAccess() {
        isGranted = preflight()
    }

    func requestAccess() {
        checkAccess()
        guard !isGranted else { return }
        hasRequested = true
        defaults.set(true, forKey: "hasRequestedScreenRecording")
        isGranted = request()
    }

    func openSettings() {
        actionError = nil
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"),
            NSWorkspace.shared.open(url)
        else {
            actionError = "Open System Settings → Privacy & Security → Screen & System Audio Recording."
            return
        }
    }

    func restart() {
        actionError = nil
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            actionError = "Quit and reopen the Timelapse app from Applications."
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    self.actionError = "Could not reopen Timelapse: \(error.localizedDescription)"
                } else {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}

struct PermissionSetupView: View {
    @ObservedObject var permission: ScreenRecordingPermission
    @ObservedObject var engine: CaptureEngine
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 20) {

            VStack(spacing: 8) {
                Text(permission.isGranted ? "You’re Ready to Record" : "Allow Screen Recording")
                    .font(.title2.weight(.semibold))
                Text(
                    permission.isGranted
                        ? "Choose a display from the Timelapse menu bar icon to start your first recording."
                        : "Timelapse needs access to your screen to make a video. Nothing is recorded until you click Start Recording."
                )
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            if permission.isGranted {
                Button("Done") { dismissWindow(id: "screen-recording-access") }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
            } else {
                if permission.hasRequested {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Open Screen & System Audio Recording.", systemImage: "1.circle")
                        Label("Turn on the switch next to Timelapse.", systemImage: "2.circle")
                        Label("If macOS asks, choose Quit & Reopen.", systemImage: "3.circle")
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                    Button("Open System Settings…") { permission.openSettings() }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.defaultAction)
                    Text("This window checks for access automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                    DisclosureGroup("Already enabled, but still waiting?") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(
                                "macOS may need the app to restart before access becomes available. If Timelapse isn’t listed, request access again."
                            )
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Button("Restart Timelapse") { permission.restart() }
                                    .disabled(engine.state != .idle)
                                Button("Request Again") { permission.requestAccess() }
                            }
                            .controlSize(.small)
                        }
                        .padding(.top, 8)
                    }
                    .font(.caption)
                } else {
                    Button("Allow Screen Recording…") { permission.requestAccess() }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.defaultAction)
                    Text("macOS will ask you to approve access.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error = permission.actionError {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Videos stay on your Mac. No audio is recorded.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .fixedSize(horizontal: false, vertical: true)
        .controlSize(.regular)
        .tint(.gray)
        .task {
            // Only the open setup window polls, never a background recording session.
            while !Task.isCancelled {
                permission.checkAccess()
                if permission.isGranted { break }
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
            }
        }
    }
}
