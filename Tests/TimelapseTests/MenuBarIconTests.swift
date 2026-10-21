import AppKit
import XCTest
@testable import Timelapse

final class MenuBarIconTests: XCTestCase {
    @MainActor
    func testIconsAreCachedMenuBarSizedTemplates() {
        for image in [MenuBarIcon.idle, MenuBarIcon.recording] {
            XCTAssertTrue(image.isTemplate)
            XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        }
        XCTAssertTrue(MenuBarIcon.idle === MenuBarIcon.idle)
        XCTAssertFalse(MenuBarIcon.idle === MenuBarIcon.recording)
    }

    @MainActor
    func testBothVariantsRenderDistinctTransparentMasksAtRetinaScale() throws {
        let idle = try rasterize(MenuBarIcon.idle)
        let recording = try rasterize(MenuBarIcon.recording)
        for bitmap in [idle, recording] {
            XCTAssertEqual(bitmap.colorAt(x: 0, y: 0)?.alphaComponent, 0)
            var opaquePixels = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    if let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.9 {
                        opaquePixels += 1
                    }
                }
            }
            XCTAssertGreaterThan(opaquePixels, 100)
            XCTAssertLessThan(opaquePixels, bitmap.pixelsWide * bitmap.pixelsHigh / 2)
        }
        XCTAssertNotEqual(
            idle.representation(using: .png, properties: [:]), recording.representation(using: .png, properties: [:]))
    }

    @MainActor
    private func rasterize(_ image: NSImage) throws -> NSBitmapImageRep {
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: 36, height: 36))
        return bitmap
    }
}
