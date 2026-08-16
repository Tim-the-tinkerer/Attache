#!/usr/bin/env swift
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

func loadSourceImage() -> CGImage? {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let png = root.appendingPathComponent("Assets/AppIcon-1024.png")
    guard let source = CGImageSourceCreateWithURL(png as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func drawFallback(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    let margin = s * 0.06
    let corner = s * 0.22
    let rect = CGRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let colors = [
        CGColor(srgbRed: 0.16, green: 0.28, blue: 0.48, alpha: 1),
        CGColor(srgbRed: 0.10, green: 0.18, blue: 0.32, alpha: 1),
        CGColor(srgbRed: 0.07, green: 0.11, blue: 0.20, alpha: 1),
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.5, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )
    }

    if let sheen = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.18),
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0),
        ] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawLinearGradient(
            sheen,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.midY),
            options: []
        )
    }

    let center = CGPoint(x: rect.midX, y: rect.midY - s * 0.02)
    let radius = rect.width * 0.34

    if let shadow = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.28),
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0),
        ] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawRadialGradient(
            shadow,
            startCenter: CGPoint(x: center.x, y: center.y - radius * 0.08),
            startRadius: radius * 0.7,
            endCenter: CGPoint(x: center.x, y: center.y - radius * 0.08),
            endRadius: radius * 1.18,
            options: []
        )
    }

    if let metal = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(srgbRed: 0.86, green: 0.89, blue: 0.93, alpha: 1),
            CGColor(srgbRed: 0.62, green: 0.67, blue: 0.74, alpha: 1),
            CGColor(srgbRed: 0.78, green: 0.82, blue: 0.87, alpha: 1),
        ] as CFArray,
        locations: [0, 0.55, 1]
    ) {
        ctx.drawRadialGradient(
            metal,
            startCenter: CGPoint(x: center.x - radius * 0.25, y: center.y + radius * 0.28),
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: []
        )
    }

    ctx.setStrokeColor(CGColor(srgbRed: 0.45, green: 0.50, blue: 0.56, alpha: 0.35))
    ctx.setLineWidth(max(0.6, s * 0.004))
    for i in 1...7 {
        let t = CGFloat(i) / 8.0
        let r = radius * (0.22 + t * 0.72)
        ctx.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }

    ctx.setStrokeColor(CGColor(srgbRed: 0.92, green: 0.94, blue: 0.97, alpha: 0.9))
    ctx.setLineWidth(max(1.2, s * 0.012))
    ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

    let hub = radius * 0.18
    if let gold = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(srgbRed: 0.93, green: 0.74, blue: 0.38, alpha: 1),
            CGColor(srgbRed: 0.62, green: 0.40, blue: 0.16, alpha: 1),
        ] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawRadialGradient(
            gold,
            startCenter: CGPoint(x: center.x - hub * 0.25, y: center.y + hub * 0.3),
            startRadius: 0,
            endCenter: center,
            endRadius: hub,
            options: []
        )
    }

    let hole = hub * 0.28
    ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.09, blue: 0.12, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: center.x - hole, y: center.y - hole, width: hole * 2, height: hole * 2))

    ctx.restoreGState()

    ctx.setStrokeColor(CGColor(srgbRed: 0.85, green: 0.90, blue: 0.96, alpha: 0.28))
    ctx.setLineWidth(max(1.0, s * 0.012))
    ctx.addPath(path)
    ctx.strokePath()

    return ctx.makeImage()
}

func scaled(_ image: CGImage, to size: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()
}

func renderIcon(size: Int, source: CGImage?) -> CGImage? {
    if let source {
        return scaled(source, to: size)
    }
    return drawFallback(size: size)
}

func savePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create image destination for \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("Could not write \(url.path)")
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")
let iconset = assets.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let source = loadSourceImage()
if source == nil {
    fputs("No Assets/AppIcon-1024.png — drawing fallback platter icon.\n", stderr)
}

// Apple iconset names only. Do not invent @2x aliases.
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]
let legalNames = Set(sizes.map(\.1))

for (size, name) in sizes {
    guard let image = renderIcon(size: size, source: source) else {
        fatalError("Failed to render icon at \(size)")
    }
    savePNG(image, to: iconset.appendingPathComponent(name))
}

if let leftovers = try? FileManager.default.contentsOfDirectory(
    at: iconset,
    includingPropertiesForKeys: nil
) {
    for url in leftovers where !legalNames.contains(url.lastPathComponent) {
        try? FileManager.default.removeItem(at: url)
    }
}

if source == nil, let master = drawFallback(size: 1024) {
    savePNG(master, to: assets.appendingPathComponent("AppIcon-1024.png"))
}

let icns = assets.appendingPathComponent("AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    fputs("iconutil failed with status \(process.terminationStatus)\n", stderr)
    exit(1)
}
print("Generated \(icns.path)")
