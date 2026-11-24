import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum VaultIconGenerator {
    static func generateIconSet(iconsetURL: URL, docsIconURL: URL) throws {
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: docsIconURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let sizes: [(String, Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024)
        ]

        for (name, px) in sizes {
            try writePNG(renderIcon(size: px), to: iconsetURL.appendingPathComponent(name))
        }
        try writePNG(renderIcon(size: 256), to: docsIconURL)
    }

    static func renderIcon(size: Int) -> CGImage {
        let s = CGFloat(size)
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        let inset = s * 0.08
        let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let radius = rect.width * 0.225
        let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        ctx.saveGState()
        ctx.addPath(squircle)
        ctx.clip()

        let bgGrad = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.075, green: 0.082, blue: 0.165, alpha: 1.0),
                CGColor(red: 0.036, green: 0.042, blue: 0.088, alpha: 1.0),
                CGColor(red: 0.016, green: 0.020, blue: 0.045, alpha: 1.0)
            ] as CFArray,
            locations: [0.0, 0.5, 1.0]
        )!
        ctx.drawLinearGradient(bgGrad, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])

        // Indigo top-left glow
        let indigoGlow = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.37, green: 0.36, blue: 0.90, alpha: 0.42),
                CGColor(red: 0.37, green: 0.36, blue: 0.90, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawRadialGradient(indigoGlow, startCenter: CGPoint(x: s * 0.32, y: s * 0.68), startRadius: 0, endCenter: CGPoint(x: s * 0.32, y: s * 0.68), endRadius: s * 0.5, options: [])

        // Mint bottom-right glow
        let mintGlow = CGGradient(
            colorsSpace: cs,
            colors: [
                CGColor(red: 0.40, green: 0.83, blue: 0.81, alpha: 0.34),
                CGColor(red: 0.40, green: 0.83, blue: 0.81, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawRadialGradient(mintGlow, startCenter: CGPoint(x: s * 0.72, y: s * 0.30), startRadius: 0, endCenter: CGPoint(x: s * 0.72, y: s * 0.30), endRadius: s * 0.48, options: [])

        // Glass sheen
        let sheen = CGGradient(
            colorsSpace: cs,
            colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.14), CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawLinearGradient(sheen, start: CGPoint(x: s * 0.5, y: rect.maxY), end: CGPoint(x: s * 0.5, y: rect.midY), options: [])

        // Hexagonal Knowledge Vault Prism
        let center = CGPoint(x: s * 0.5, y: s * 0.5)
        let hexR = s * 0.27
        let hexPoints: [CGPoint] = (0..<6).map { i in
            let angle = CGFloat(i) * (.pi / 3.0) - (.pi / 2.0)
            return CGPoint(x: center.x + cos(angle) * hexR, y: center.y + sin(angle) * hexR)
        }

        // Internal neural citation spokes
        ctx.setLineWidth(max(1.2, s * 0.020))
        ctx.setStrokeColor(CGColor(red: 0.40, green: 0.83, blue: 0.81, alpha: 0.72))
        for pt in hexPoints {
            ctx.move(to: center)
            ctx.addLine(to: pt)
            ctx.strokePath()
        }

        // Outer luminous hexagon stroke
        ctx.setLineWidth(max(1.5, s * 0.028))
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(CGColor(red: 0.55, green: 0.58, blue: 1.0, alpha: 0.95))
        ctx.move(to: hexPoints[0])
        for pt in hexPoints.dropFirst() { ctx.addLine(to: pt) }
        ctx.closePath()
        ctx.strokePath()

        // Vertex citation nodes
        for (i, pt) in hexPoints.enumerated() {
            let nr = s * 0.042
            ctx.setFillColor(i % 2 == 0
                ? CGColor(red: 0.40, green: 0.83, blue: 0.81, alpha: 1.0)
                : CGColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1.0))
            ctx.fillEllipse(in: CGRect(x: pt.x - nr, y: pt.y - nr, width: nr * 2, height: nr * 2))
        }

        // Luminous center prism core
        let coreR = s * 0.082
        ctx.setFillColor(CGColor(red: 0.92, green: 0.98, blue: 1.0, alpha: 0.98))
        ctx.fillEllipse(in: CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2))

        ctx.restoreGState()

        ctx.addPath(squircle)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.24))
        ctx.setLineWidth(max(1.0, s * 0.012))
        ctx.strokePath()

        return ctx.makeImage()!
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "VaultMindTools.PNG", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG destination"])
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "VaultMindTools.PNG", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG"])
        }
    }
}
