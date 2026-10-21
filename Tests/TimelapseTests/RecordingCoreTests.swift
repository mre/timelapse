import AVFoundation
import XCTest
@testable import Timelapse

final class RecordingCoreTests: XCTestCase {
    func testDefaultsAndValidation() throws {
        let configuration = RecordingConfiguration()
        XCTAssertEqual(configuration.interval, 5)
        XCTAssertEqual(configuration.framesPerSecond, 30)
        XCTAssertEqual(configuration.maxDimension, 1920)
        XCTAssertTrue(configuration.showsCursor)
        try configuration.validate()
        for interval in [Double.nan, .infinity, -1, 0, 0.01, 86_401] {
            XCTAssertThrowsError(try RecordingConfiguration(interval: interval).validate())
        }
        XCTAssertThrowsError(try RecordingConfiguration(framesPerSecond: 0).validate())
        XCTAssertThrowsError(try RecordingConfiguration(framesPerSecond: 121).validate())
        XCTAssertThrowsError(try RecordingConfiguration(maxDimension: 1).validate())
        XCTAssertThrowsError(try RecordingConfiguration(maxDimension: 8193).validate())
    }

    func testEvenAspectPreservingDimensionsWithoutUpscaling() throws {
        let configuration = RecordingConfiguration()
        let landscape = try configuration.outputDimensions(width: 3840, height: 2160)
        XCTAssertEqual(landscape.width, 1920)
        XCTAssertEqual(landscape.height, 1080)
        let portrait = try configuration.outputDimensions(width: 2160, height: 3840)
        XCTAssertEqual(portrait.width, 1080)
        XCTAssertEqual(portrait.height, 1920)
        let small = try configuration.outputDimensions(width: 801, height: 601)
        XCTAssertEqual(small.width, 800)
        XCTAssertEqual(small.height, 600)
        XCTAssertThrowsError(try configuration.outputDimensions(width: 0, height: 1080))
    }

    func testFrameTimeIsIndependentOfCaptureInterval() {
        let fast = RecordingConfiguration(interval: 1, framesPerSecond: 24)
        let slow = RecordingConfiguration(interval: 60, framesPerSecond: 24)
        XCTAssertEqual(fast.presentationTime(forFrame: 48), slow.presentationTime(forFrame: 48))
        XCTAssertEqual(CMTimeGetSeconds(slow.presentationTime(forFrame: 48)), 2)
    }

    func testEmptyRecordingRemovesPartialFile() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = TimelapseWriter()
        try await writer.prepare(directory: directory, width: 64, height: 64, configuration: RecordingConfiguration())
        let url = try await writer.finish()
        XCTAssertNil(url)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }

    func testSyntheticFramesProduceFinalMP4WithExpectedDuration() async throws {
        for frameCount in [1, 6] {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let writer = TimelapseWriter()
            let configuration = RecordingConfiguration(framesPerSecond: 30)
            try await writer.prepare(directory: directory, width: 64, height: 64, configuration: configuration)
            do {
                for index in 0..<frameCount {
                    let count = try await writer.append(makePixelBuffer(value: UInt8(index * 30)))
                    XCTAssertEqual(count, index + 1)
                }
                let result = try await writer.finish()
                let url = try XCTUnwrap(result)
                XCTAssertFalse(url.lastPathComponent.contains("partial"))
                XCTAssertEqual(
                    try FileManager.default.contentsOfDirectory(atPath: directory.path), [url.lastPathComponent])
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration)
                XCTAssertEqual(CMTimeGetSeconds(duration), Double(frameCount) / 30, accuracy: 0.001)
                let tracks = try await asset.loadTracks(withMediaType: .video)
                let track = try XCTUnwrap(tracks.first)
                let reader = try AVAssetReader(asset: asset)
                let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
                reader.add(output)
                XCTAssertTrue(reader.startReading())
                var encodedCount = 0
                // Readers can emit zero-sample marker buffers as well as video frames.
                while let sample = output.copyNextSampleBuffer() {
                    encodedCount += CMSampleBufferGetNumSamples(sample)
                }
                XCTAssertEqual(reader.status, .completed)
                XCTAssertEqual(encodedCount, frameCount)
            } catch {
                await writer.discard()
                throw error
            }
        }
    }

    func testRenameFailurePreservesCompletedMovie() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = TimelapseWriter()
        try await writer.prepare(directory: directory, width: 64, height: 64, configuration: RecordingConfiguration())
        _ = try await writer.append(makePixelBuffer(value: 100))
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let partial = try XCTUnwrap(files.first { $0.lastPathComponent.hasSuffix(".partial.mp4") })
        let destination = directory.appendingPathComponent(
            partial.lastPathComponent.replacingOccurrences(of: ".partial.mp4", with: ".mp4"))
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        do {
            _ = try await writer.finish()
            XCTFail("The conflicting destination should prevent renaming")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains(partial.lastPathComponent), error.localizedDescription)
        }
        await writer.discard()
        XCTAssertTrue(FileManager.default.fileExists(atPath: partial.path))
        let duration = try await AVURLAsset(url: partial).load(.duration)
        XCTAssertEqual(CMTimeGetSeconds(duration), 1.0 / 30, accuracy: 0.001)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TimelapseTests-\(UUID().uuidString)")
    }

    private func makePixelBuffer(value: UInt8) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(
            kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &buffer)
        XCTAssertEqual(result, kCVReturnSuccess)
        let image = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(image, [])
        defer { CVPixelBufferUnlockBaseAddress(image, []) }
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(image))
        memset(base, Int32(value), CVPixelBufferGetBytesPerRow(image) * CVPixelBufferGetHeight(image))
        return image
    }
}
