import AppKit

/// Vector masks: macOS supplies the color for the menu bar's appearance and selection state.
@MainActor
enum MenuBarIcon {
    static let idle = makeImage(recording: false)
    static let recording = makeImage(recording: true)

    private static func makeImage(recording: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let center = NSPoint(x: 9, y: 9)
            let innerRadius: CGFloat = recording ? 5.6 : 6.6
            let ring = NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 16, height: 16))
            ring.appendOval(
                in: NSRect(
                    x: center.x - innerRadius, y: center.y - innerRadius,
                    width: innerRadius * 2, height: innerRadius * 2
                ))
            ring.windingRule = .evenOdd
            NSColor.black.setFill()
            ring.fill()

            let sector = NSBezierPath()
            sector.move(to: center)
            // Idle leaves a 45° gap at the upper left. Recording fills that wedge.
            sector.appendArc(
                withCenter: center,
                radius: recording ? innerRadius + 0.25 : 5.1,
                startAngle: recording ? 90 : 135,
                endAngle: recording ? 135 : 450,
                clockwise: false
            )
            sector.close()
            sector.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
