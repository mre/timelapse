import CoreMedia
import Foundation

struct RecordingConfiguration: Equatable, Sendable {
    var interval: Double
    var framesPerSecond: Int
    var maxDimension: Int
    var showsCursor: Bool

    init(interval: Double = 5, framesPerSecond: Int = 30, maxDimension: Int = 1920, showsCursor: Bool = true) {
        self.interval = interval
        self.framesPerSecond = framesPerSecond
        self.maxDimension = maxDimension
        self.showsCursor = showsCursor
    }

    func validate() throws {
        guard interval.isFinite, (0.1...86_400).contains(interval) else {
            throw RecordingError.message("Capture interval must be between 0.1 seconds and 24 hours.")
        }
        guard (1...120).contains(framesPerSecond) else {
            throw RecordingError.message("Playback frame rate must be between 1 and 120 fps.")
        }
        guard (2...8192).contains(maxDimension) else {
            throw RecordingError.message("Maximum video dimension must be between 2 and 8192 pixels.")
        }
    }

    /// H.264 needs even dimensions. Never upscale the source display.
    func outputDimensions(width: Int, height: Int) throws -> (width: Int, height: Int) {
        try validate()
        guard width >= 2, height >= 2 else {
            throw RecordingError.message("The selected display has invalid dimensions.")
        }
        let scale = min(1, Double(maxDimension) / Double(max(width, height)))
        return (
            max(2, Int(Double(width) * scale) / 2 * 2),
            max(2, Int(Double(height) * scale) / 2 * 2)
        )
    }

    func presentationTime(forFrame frame: Int) -> CMTime {
        CMTime(value: Int64(frame), timescale: Int32(clamping: max(1, framesPerSecond)))
    }
}

enum RecordingError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): return message
        }
    }
}
