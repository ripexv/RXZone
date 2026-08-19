//
//  Renders the RXZone app icon at every size macOS asks for.
//
//  Draws the same geometry as Design/icon-foreground.svg and
//  Design/icon-background.svg, so the SVGs stay the source of truth and this
//  file is only the exporter.
//

import AppKit
import CoreGraphics

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

/// Apple-style squircle: a superellipse, not a circular-corner rounded rect.
func squircle(in size: CGFloat, exponent: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let radius = size / 2
    let steps = 1440
    for step in 0...steps {
        let t = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = radius + radius * (c < 0 ? -1 : 1) * pow(abs(c), 2 / exponent)
        let y = radius + radius * (s < 0 ? -1 : 1) * pow(abs(s), 2 / exponent)
        step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

func renderIcon(size pixels: Int) -> CGImage? {
    let size = CGFloat(pixels)
    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high

    // The artwork is authored on a 1024 grid; everything below is in those
    // units, flipped so the maths matches the SVG's top-left origin.
    let scale = size / 1024
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: scale, y: -scale)

    // Background: clipped to the icon shape, then a diagonal gradient.
    context.saveGState()
    var shape = CGAffineTransform(scaleX: 1024 / size, y: 1024 / size)
    context.addPath(squircle(in: size).copy(using: &shape)!)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [
            CGColor(red: 0.231, green: 0.184, blue: 0.710, alpha: 1),  // #3B2FB5
            CGColor(red: 0.145, green: 0.388, blue: 0.851, alpha: 1),  // #2563D9
            CGColor(red: 0.133, green: 0.659, blue: 0.910, alpha: 1),  // #22A8E8
        ] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(
        gradient, start: .zero, end: CGPoint(x: 1024, y: 1024), options: [])
    context.restoreGState()

    context.setLineCap(.round)

    // Globe, held back so it never competes with the hands.
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
    context.setLineWidth(38)
    context.addEllipse(in: CGRect(x: 512 - 146, y: 512 - 318, width: 292, height: 636))
    context.strokePath()

    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.34))
    context.move(to: CGPoint(x: 268, y: 512))
    context.addLine(to: CGPoint(x: 756, y: 512))
    context.strokePath()

    // Bezel: the shape that carries the icon once it gets small.
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(56)
    context.addEllipse(in: CGRect(x: 512 - 318, y: 512 - 318, width: 636, height: 636))
    context.strokePath()

    // Hands at 10:10.
    context.setLineWidth(54)
    context.move(to: CGPoint(x: 512, y: 512))
    context.addLine(to: CGPoint(x: 365, y: 427))
    context.move(to: CGPoint(x: 512, y: 512))
    context.addLine(to: CGPoint(x: 711, y: 397))
    context.strokePath()

    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fillEllipse(in: CGRect(x: 512 - 40, y: 512 - 40, width: 80, height: 80))

    return context.makeImage()
}

// macOS asks for five logical sizes at 1x and 2x.
let variants: [(logical: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

for variant in variants {
    let pixels = variant.logical * variant.scale
    guard let image = renderIcon(size: pixels) else {
        FileHandle.standardError.write("failed at \(pixels)px\n".data(using: .utf8)!)
        exit(1)
    }
    let name = "icon_\(variant.logical)x\(variant.logical)" + (variant.scale == 2 ? "@2x" : "") + ".png"
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(name)
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: pixels, height: pixels)
    guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
    try! data.write(to: url)
    print("  \(name)  \(pixels)×\(pixels)")
}
