import AVFoundation
import Combine
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class CaptureEngine: ObservableObject {
    enum State: Equatable {
        case idle, starting, recording, paused, finishing
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var frameCount = 0
    @Published private(set) var lastRecording: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var displays: [SCDisplay] = []

    private var writer: TimelapseWriter?
    private var startupTask: Task<Void, Never>?
    private var captureTask: Task<Void, Never>?
    private var finishTask: Task<Void, Never>?
    private var delayTask: Task<Void, Never>?
    private var pauseWaiter: CheckedContinuation<Void, Never>?
    // Invalidates a screenshot when pause/resume occurs while its request is in flight.
    private var captureGeneration = 0
    private var pauseOnStart = false

    func refreshDisplays() async {
        guard CGPreflightScreenCaptureAccess() else {
            displays = []
            return
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            displays = content.displays.sorted { $0.displayID < $1.displayID }
            errorMessage = nil
        } catch {
            errorMessage = captureErrorMessage(error)
        }
    }

    func start(displayID: CGDirectDisplayID, configuration: RecordingConfiguration, directory: URL) async {
        guard state == .idle else { return }
        guard CGPreflightScreenCaptureAccess() else {
            displays = []
            errorMessage = "Screen Recording access is needed. Continue setup to enable it."
            return
        }
        state = .starting
        pauseOnStart = false
        frameCount = 0
        lastRecording = nil
        errorMessage = nil
        let task = Task { [self] in
            do {
                try configuration.validate()
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard state == .starting else { return }
                displays = content.displays.sorted { $0.displayID < $1.displayID }
                guard let display = displays.first(where: { $0.displayID == displayID }) else {
                    throw RecordingError.message(
                        "The selected display is no longer connected. Select another display and try again.")
                }
                let excluded = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
                let filter = SCContentFilter(display: display, excludingApplications: excluded, exceptingWindows: [])
                let scale = CGFloat(filter.pointPixelScale)
                let dimensions = try configuration.outputDimensions(
                    width: Int(filter.contentRect.width * scale),
                    height: Int(filter.contentRect.height * scale)
                )
                let settings = SCStreamConfiguration()
                settings.width = dimensions.width
                settings.height = dimensions.height
                settings.pixelFormat = kCVPixelFormatType_32BGRA
                settings.showsCursor = configuration.showsCursor
                settings.scalesToFit = true
                settings.captureDynamicRange = .SDR
                settings.colorSpaceName = CGColorSpace.sRGB
                let newWriter = TimelapseWriter()
                writer = newWriter
                try await newWriter.prepare(
                    directory: directory, width: dimensions.width, height: dimensions.height,
                    configuration: configuration)
                guard state == .starting else { return }
                state = pauseOnStart ? .paused : .recording
                captureTask = Task { [self] in
                    await captureLoop(
                        displayID: displayID, filter: filter, settings: settings, configuration: configuration,
                        writer: newWriter)
                }
            } catch {
                errorMessage = captureErrorMessage(error)
                if state == .starting {
                    await writer?.discard()
                    writer = nil
                    state = .idle
                }
            }
        }
        startupTask = task
        await task.value
    }

    func pause() {
        if state == .starting {
            pauseOnStart = true
            return
        }
        guard state == .recording else { return }
        state = .paused
        captureGeneration += 1
        delayTask?.cancel()
    }

    func resume() {
        guard state == .paused else { return }
        state = .recording
        wakePausedLoop()
    }

    func stop() async {
        if state == .finishing {
            await finishTask?.value
            return
        }
        guard state != .idle else { return }
        state = .finishing
        captureGeneration += 1
        delayTask?.cancel()
        wakePausedLoop()
        let task = Task { [self] in
            await startupTask?.value
            // SCScreenshotManager has no cancellation API. Drain its single request
            // before closing the writer; the loop discards the late screenshot.
            await captureTask?.value
            do {
                if let url = try await writer?.finish() {
                    lastRecording = url
                }
            } catch {
                errorMessage = error.localizedDescription
                await writer?.discard()
            }
            writer = nil
            startupTask = nil
            captureTask = nil
            delayTask = nil
            state = .idle
        }
        finishTask = task
        await task.value
    }

    private func wakePausedLoop() {
        pauseWaiter?.resume()
        pauseWaiter = nil
    }

    private func captureLoop(
        displayID: CGDirectDisplayID, filter: SCContentFilter, settings: SCStreamConfiguration,
        configuration: RecordingConfiguration, writer: TimelapseWriter
    ) async {
        while state == .recording || state == .paused {
            if state == .paused {
                await withCheckedContinuation { pauseWaiter = $0 }
                continue
            }
            let generation = captureGeneration
            let started = ContinuousClock.now
            do {
                guard CGDisplayIsOnline(displayID) != 0 else {
                    throw RecordingError.message("The recorded display was disconnected. Recording has stopped.")
                }
                let sample = try await SCScreenshotManager.captureSampleBuffer(
                    contentFilter: filter, configuration: settings)
                guard state == .recording, generation == captureGeneration else { continue }
                guard let image = CMSampleBufferGetImageBuffer(sample) else {
                    throw RecordingError.message("Screen capture returned no image. Recording has stopped.")
                }
                let count = try await writer.append(image)
                frameCount = count
            } catch {
                guard state == .recording || state == .paused else { return }
                errorMessage = captureErrorMessage(error)
                // Do not await stop here: stop drains this task before finalizing.
                Task { await self.stop() }
                return
            }
            guard state == .recording else { continue }
            let deadline = started.advanced(by: .seconds(configuration.interval))
            let delay = Task<Void, Never> {
                try? await ContinuousClock().sleep(until: deadline)
            }
            delayTask = delay
            await delay.value
            delayTask = nil
        }
    }

    private func captureErrorMessage(_ error: Error) -> String {
        if !CGPreflightScreenCaptureAccess() {
            return "Screen Recording access is needed. Continue setup to enable it."
        }
        return error.localizedDescription
    }
}

/// Serial actor executor keeps compression, writer calls, and file I/O off MainActor.
/// The caller awaits every append, so there is never a queue of pending screenshots.
actor TimelapseWriter {
    private var assetWriter: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var partialURL: URL?
    private var destinationURL: URL?
    private var configuration = RecordingConfiguration()
    private var count = 0

    func prepare(directory: URL, width: Int, height: Int, configuration: RecordingConfiguration) throws {
        try configuration.validate()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "Timelapse-\(UUID().uuidString)"
        let destination = directory.appendingPathComponent(name + ".mp4")
        let partial = directory.appendingPathComponent(name + ".partial.mp4")
        partialURL = partial
        destinationURL = destination
        self.configuration = configuration
        let writer = try AVAssetWriter(outputURL: partial, fileType: .mp4)
        assetWriter = writer
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: min(40_000_000, max(1_000_000, width * height * 4)),
                    AVVideoExpectedSourceFrameRateKey: configuration.framesPerSecond,
                    AVVideoMaxKeyFrameIntervalKey: configuration.framesPerSecond * 2,
                    AVVideoAllowFrameReorderingKey: false,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ],
            ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ])
        guard writer.canAdd(input) else {
            throw RecordingError.message("H.264 encoding is unavailable for these video dimensions.")
        }
        writer.add(input)
        self.input = input
        self.adaptor = adaptor
        guard writer.startWriting() else { throw failure("Could not start the video encoder.") }
        writer.startSession(atSourceTime: .zero)
    }

    func append(_ buffer: CVPixelBuffer) async throws -> Int {
        guard let writer = assetWriter, let input, let adaptor else {
            throw RecordingError.message("The video encoder is not initialized.")
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw failure("The video encoder stopped unexpectedly.") }
            guard ContinuousClock.now < deadline else {
                throw RecordingError.message("The video encoder stalled for more than five seconds.")
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard writer.status == .writing,
            adaptor.append(buffer, withPresentationTime: configuration.presentationTime(forFrame: count))
        else {
            throw failure("Could not encode the captured frame.")
        }
        count += 1
        return count
    }

    func finish() async throws -> URL? {
        guard count > 0 else {
            discard()
            return nil
        }
        guard let writer = assetWriter, let input, let partialURL, let destinationURL else {
            throw RecordingError.message("The video encoder is not initialized.")
        }
        guard writer.status == .writing else { throw failure("The video encoder failed before finishing.") }
        // Include the final frame's full duration, even for a one-frame recording.
        writer.endSession(atSourceTime: configuration.presentationTime(forFrame: count))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw failure("Could not finalize the video.") }
        do {
            try FileManager.default.moveItem(at: partialURL, to: destinationURL)
        } catch {
            // The movie is complete. Never delete it because its final rename failed.
            self.partialURL = nil
            throw RecordingError.message(
                "Your movie was encoded but could not be renamed. It is saved at \(partialURL.path). \(error.localizedDescription)"
            )
        }
        self.partialURL = nil
        return destinationURL
    }

    func discard() {
        if let assetWriter, assetWriter.status == .writing { assetWriter.cancelWriting() }
        if let partialURL { try? FileManager.default.removeItem(at: partialURL) }
        self.partialURL = nil
        adaptor = nil
        input = nil
        assetWriter = nil
    }

    private func failure(_ fallback: String) -> Error {
        assetWriter?.error ?? RecordingError.message(fallback)
    }
}
