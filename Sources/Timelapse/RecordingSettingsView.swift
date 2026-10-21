import AppKit
import SwiftUI

struct RecordingSettingsView: View {
    @ObservedObject var engine: CaptureEngine
    @AppStorage("maxDimension") private var maxDimension = 1920
    @AppStorage("showsCursor") private var showsCursor = true
    @AppStorage("outputDirectory") private var outputPath = ""

    private var directory: URL { RecordingDestination.url(for: outputPath) }

    var body: some View {
        Form {
            Section {
                Picker("Resolution", selection: $maxDimension) {
                    Text("1280 px").tag(1280)
                    Text("1920 px (Recommended)").tag(1920)
                    Text("3840 px").tag(3840)
                }
                Toggle("Show pointer", isOn: $showsCursor)
            } header: {
                Text("Video")
            } footer: {
                Text(
                    "Resolution limits the longest edge. Smaller images use fewer resources. Movies use H.264 at 30 fps, without audio."
                )
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            }
            .disabled(engine.state != .idle)

            Section("Save Recordings") {
                LabeledContent("Folder") {
                    HStack {
                        Text(directory.lastPathComponent).lineLimit(1).truncationMode(.middle)
                        Button("Change…", action: chooseDirectory)
                    }
                }
                Text(directory.path(percentEncoded: false))
                    .font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(engine.state != .idle)

            Section {
                if engine.state != .idle {
                    Label("Stop recording to change these settings.", systemImage: "info.circle")
                }
                Text(
                    "Videos stay on your Mac. Everything visible on the selected display can appear in the movie, including notifications. Timelapse’s own windows are excluded."
                )
                Text("Sleep and screen lock pause capture. Resume manually when you’re ready.")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .tint(.gray)
        .frame(width: 440, height: 440)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose where to save your timelapses"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        if panel.runModal() == .OK, let url = panel.url { outputPath = url.path }
    }
}

enum RecordingDestination {
    static func url(for path: String) -> URL {
        if !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true) }
        let movies =
            FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
        return movies.appendingPathComponent("Timelapse", isDirectory: true)
    }
}
