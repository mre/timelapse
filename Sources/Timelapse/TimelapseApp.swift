import AppKit
import SwiftUI

@main
struct TimelapseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            RecorderView(engine: delegate.engine, permission: delegate.permission)
        } label: {
            RecordingMenuLabel(engine: delegate.engine)
        }
        .menuBarExtraStyle(.window)

        Window("Timelapse Settings", id: "recording-settings") {
            RecordingSettingsView(engine: delegate.engine)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Window("Screen Recording Access", id: "screen-recording-access") {
            PermissionSetupView(permission: delegate.permission, engine: delegate.engine)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
    }
}

private struct RecordingMenuLabel: View {
    @ObservedObject var engine: CaptureEngine

    var body: some View {
        Image(nsImage: engine.state == .recording ? MenuBarIcon.recording : MenuBarIcon.idle)
            .renderingMode(.template)
            .accessibilityLabel("Timelapse: \(engine.state.label)")
            .help("Timelapse: \(engine.state.label)")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let engine = CaptureEngine()
    let permission = ScreenRecordingPermission()
    private var terminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(pauseForPrivacy), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(pauseForPrivacy), name: NSWorkspace.willSleepNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(pauseForPrivacy), name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil)
    }

    @objc private func pauseForPrivacy(_ notification: Notification) {
        // Deliberately require a manual resume after wake or unlock.
        engine.pause()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard engine.state != .idle else { return .terminateNow }
        guard !terminating else { return .terminateLater }
        terminating = true
        Task {
            await engine.stop()
            if let message = engine.errorMessage {
                let alert = NSAlert()
                alert.messageText = "Recording stopped with an error"
                alert.informativeText = message
                alert.runModal()
            }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

extension CaptureEngine.State {
    var label: String {
        switch self {
        case .idle: "Ready when you are"
        case .starting: "Preparing recording…"
        case .recording: "Recording"
        case .paused: "Paused"
        case .finishing: "Finishing your movie…"
        }
    }
}
