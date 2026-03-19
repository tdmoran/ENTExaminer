#!/usr/bin/env swift

import AppKit
import CoreGraphics

// MARK: - Icon Generator for ENTExaminer

struct IconGenerator {

    // Medical blue gradient colors
    static let gradientStartColor = NSColor(
        calibratedRed: 0x14 / 255.0,
        green: 0x4D / 255.0,
        blue: 0xD4 / 255.0,
        alpha: 1.0
    ) // #144DD4 - deeper blue

    static let gradientEndColor = NSColor(
        calibratedRed: 0x3B / 255.0,
        green: 0x82 / 255.0,
        blue: 0xF6 / 255.0,
        alpha: 1.0
    ) // #3B82F6 - lighter blue

    static func generateIcon(size: Int) -> NSImage {
        let cgSize = CGSize(width: size, height: size)
        let image = NSImage(size: cgSize)

        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let rect = CGRect(origin: .zero, size: cgSize)
        let s = CGFloat(size)

        // --- Rounded square background ---
        let cornerRadius = s * 0.22
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Clip to rounded rect
        context.saveGState()
        bgPath.addClip()

        // Draw gradient background
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradientColors = [
            gradientStartColor.cgColor,
            gradientEndColor.cgColor
        ] as CFArray
        let gradientLocations: [CGFloat] = [0.0, 1.0]

        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: gradientColors,
            locations: gradientLocations
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: s),
                end: CGPoint(x: s, y: 0),
                options: []
            )
        }

        // --- Subtle inner shadow / border glow ---
        context.saveGState()
        let innerRect = rect.insetBy(dx: s * 0.01, dy: s * 0.01)
        let innerRadius = cornerRadius - s * 0.01
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: innerRadius, yRadius: innerRadius)
        NSColor(white: 1.0, alpha: 0.08).setStroke()
        innerPath.lineWidth = s * 0.015
        innerPath.stroke()
        context.restoreGState()

        // --- Sound waveform pattern ---
        drawWaveform(in: context, size: s)

        // --- Small stethoscope circle accent at bottom ---
        drawStethoscopeAccent(in: context, size: s)

        context.restoreGState()
        image.unlockFocus()

        return image
    }

    static func drawWaveform(in context: CGContext, size s: CGFloat) {
        context.saveGState()

        // Waveform: 7 vertical bars with varying heights, centered
        let barCount = 7
        let barWidth = s * 0.055
        let barSpacing = s * 0.035
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (s - totalWidth) / 2.0
        let centerY = s * 0.45 // slightly above center

        // Heights as fraction of icon size (symmetric pattern, taller in middle)
        let barHeights: [CGFloat] = [0.10, 0.18, 0.28, 0.38, 0.28, 0.18, 0.10]

        NSColor.white.withAlphaComponent(0.95).setFill()

        for i in 0..<barCount {
            let h = barHeights[i] * s
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let y = centerY - h / 2.0
            let barRadius = barWidth / 2.0
            let barRect = CGRect(x: x, y: y, width: barWidth, height: h)
            let barPath = NSBezierPath(roundedRect: barRect, xRadius: barRadius, yRadius: barRadius)
            barPath.fill()
        }

        // Add a subtle glow behind waveform
        context.restoreGState()
    }

    static func drawStethoscopeAccent(in context: CGContext, size s: CGFloat) {
        context.saveGState()

        // Small circle below waveform suggesting stethoscope head
        let circleRadius = s * 0.055
        let centerX = s * 0.5
        let centerY = s * 0.17 // bottom area (CoreGraphics y is from bottom)

        let circlePath = NSBezierPath(
            ovalIn: CGRect(
                x: centerX - circleRadius,
                y: centerY - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            )
        )

        NSColor.white.withAlphaComponent(0.7).setStroke()
        circlePath.lineWidth = s * 0.018
        circlePath.stroke()

        // Small dot in center
        let dotRadius = s * 0.015
        let dotPath = NSBezierPath(
            ovalIn: CGRect(
                x: centerX - dotRadius,
                y: centerY - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
        )
        NSColor.white.withAlphaComponent(0.7).setFill()
        dotPath.fill()

        // Short line from circle up to waveform area
        let linePath = NSBezierPath()
        linePath.move(to: CGPoint(x: centerX, y: centerY + circleRadius))
        linePath.line(to: CGPoint(x: centerX, y: centerY + circleRadius + s * 0.06))
        NSColor.white.withAlphaComponent(0.5).setStroke()
        linePath.lineWidth = s * 0.015
        linePath.stroke()

        context.restoreGState()
    }

    static func savePNG(image: NSImage, size: Int, to path: String) -> Bool {
        // Create a bitmap at exact pixel dimensions (avoid Retina 2x scaling)
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        bitmap.size = NSSize(width: size, height: size)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(
            in: NSRect(x: 0, y: 0, width: size, height: size),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("ERROR: Failed to create PNG data for \(path)")
            return false
        }

        do {
            try pngData.write(to: URL(fileURLWithPath: path))
            let fileSize = pngData.count
            print("OK: \(path) (\(fileSize) bytes, \(size)x\(size)px)")
            return true
        } catch {
            print("ERROR: Failed to write \(path): \(error)")
            return false
        }
    }
}

// MARK: - Main

let outputDir = "/private/tmp/ENTExaminer-iOS/ENTExaminer/Resources/Assets.xcassets/AppIcon.appiconset"
let sizes = [16, 32, 64, 128, 256, 512, 1024]

// Ensure output directory exists
let fileManager = FileManager.default
if !fileManager.fileExists(atPath: outputDir) {
    try! fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
}

print("Generating ENTExaminer app icons...")
print("Output: \(outputDir)\n")

var allSucceeded = true

for size in sizes {
    let icon = IconGenerator.generateIcon(size: size)
    let filename = "icon_\(size).png"
    let path = "\(outputDir)/\(filename)"

    if !IconGenerator.savePNG(image: icon, size: size, to: path) {
        allSucceeded = false
    }
}

print("")
if allSucceeded {
    print("All icons generated successfully.")
} else {
    print("Some icons failed to generate.")
    exit(1)
}
