// Renders the DMG installer background at 1x and 2x.
// Design canvas is 660x400 pt; icon wells match Scripts/build-dmg.sh
// icon coordinates (app at 165,200 and Applications at 495,200).
// Usage: swift Scripts/RenderDMGBackground.swift <output-directory>

import AppKit

let designSize = NSSize(width: 660, height: 400)
let appWellCenter = NSPoint(x: 165, y: 200)
let dropWellCenter = NSPoint(x: 495, y: 200)
let wellRadius: CGFloat = 84

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func render(scale: CGFloat) -> NSBitmapImageRep {
    let width = Int(designSize.width * scale)
    let height = Int(designSize.height * scale)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Could not create drawing context")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    let canvas = NSRect(origin: .zero, size: designSize)

    // Deep studio backdrop with a faint indigo cast rising from the center.
    NSGradient(colors: [color(0x171C2A), color(0x0E1118)])?
        .draw(in: canvas, angle: -90)
    NSGradient(colors: [color(0x5E5CE6, 0.22), color(0x5E5CE6, 0)])?
        .draw(
            fromCenter: NSPoint(x: 330, y: 200), radius: 0,
            toCenter: NSPoint(x: 330, y: 200), radius: 300,
            options: []
        )

    // Icon wells: soft rings that frame the app icon and the Applications drop.
    for center in [appWellCenter, dropWellCenter] {
        let wellRect = NSRect(
            x: center.x - wellRadius, y: center.y - wellRadius,
            width: wellRadius * 2, height: wellRadius * 2
        )
        let well = NSBezierPath(ovalIn: wellRect)
        color(0xFFFFFF, 0.035).setFill()
        well.fill()
        color(0xFFFFFF, 0.10).setStroke()
        well.lineWidth = 1.5
        well.stroke()
    }

    // Dashed guide arrow between the wells.
    let arrowColor = color(0x8482FF, 0.9)
    let arrowY = appWellCenter.y
    let start = appWellCenter.x + wellRadius + 14
    let end = dropWellCenter.x - wellRadius - 26
    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: start, y: arrowY))
    shaft.line(to: NSPoint(x: end, y: arrowY))
    shaft.lineWidth = 4
    shaft.lineCapStyle = .round
    shaft.setLineDash([1, 12], count: 2, phase: 0)
    arrowColor.setStroke()
    shaft.stroke()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: end + 22, y: arrowY))
    head.line(to: NSPoint(x: end + 2, y: arrowY + 11))
    head.line(to: NSPoint(x: end + 6, y: arrowY))
    head.line(to: NSPoint(x: end + 2, y: arrowY - 11))
    head.close()
    arrowColor.setFill()
    head.fill()

    // Wordmark and install hint along the top.
    let titleFont = NSFont.systemFont(ofSize: 27, weight: .bold)
    let title = NSAttributedString(string: "Meetco", attributes: [
        .font: titleFont, .foregroundColor: color(0xF7F8FA)
    ])
    let titleSize = title.size()
    title.draw(at: NSPoint(x: (designSize.width - titleSize.width) / 2, y: 336))

    let hint = NSAttributedString(string: "Drag Meetco into Applications to install", attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: color(0x9AA5B5)
    ])
    let hintSize = hint.size()
    hint.draw(at: NSPoint(x: (designSize.width - hintSize.width) / 2, y: 314))

    // Quiet waveform signature along the bottom edge.
    let barHeights: [CGFloat] = [8, 16, 11, 24, 17, 30, 20, 13, 26, 18, 10, 22, 15, 9]
    let barWidth: CGFloat = 3
    let spacing: CGFloat = 7
    let waveWidth = CGFloat(barHeights.count) * (barWidth + spacing) - spacing
    var x = (designSize.width - waveWidth) / 2
    for (index, barHeight) in barHeights.enumerated() {
        let bar = NSBezierPath(
            roundedRect: NSRect(x: x, y: 42 - barHeight / 2, width: barWidth, height: barHeight),
            xRadius: barWidth / 2, yRadius: barWidth / 2
        )
        color(0x5E5CE6, index.isMultiple(of: 3) ? 0.55 : 0.28).setFill()
        bar.fill()
        x += barWidth + spacing
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

guard CommandLine.arguments.count > 1 else {
    fatalError("Usage: swift Scripts/RenderDMGBackground.swift <output-directory>")
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for (suffix, scale) in [("", CGFloat(1)), ("@2x", CGFloat(2))] {
    let rep = render(scale: scale)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encoding failed")
    }
    let url = outputDirectory.appendingPathComponent("dmg-background\(suffix).png")
    try data.write(to: url)
    print(url.path)
}
