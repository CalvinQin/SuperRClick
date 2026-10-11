// Compile with Shared/Design/RClickIcon.swift; no downloaded tools or icon inputs.
// xcrun swiftc -swift-version 6 -parse-as-library -module-cache-path /tmp/superrclick-icons-cache \
//   Shared/Design/RClickIcon.swift scripts/render_original_icons.swift -o /tmp/superrclick-render-icons
// /tmp/superrclick-render-icons /absolute/path/to/Super\ RClick
import AppKit
import ImageIO
import UniformTypeIdentifiers

@main
@MainActor
struct OriginalIconRenderer {
    private static let sizes = [16, 20, 24, 32]
    private static let specs: [(String, Int, String, String)] = [
        ("icon_16x16.png", 16, "16x16", "1x"),
        ("icon_16x16@2x.png", 32, "16x16", "2x"),
        ("icon_32x32.png", 32, "32x32", "1x"),
        ("icon_32x32@2x.png", 64, "32x32", "2x"),
        ("icon_128x128.png", 128, "128x128", "1x"),
        ("icon_128x128@2x.png", 256, "128x128", "2x"),
        ("icon_256x256.png", 256, "256x256", "1x"),
        ("icon_256x256@2x.png", 512, "256x256", "2x"),
        ("icon_512x512.png", 512, "512x512", "1x"),
        ("icon_512x512@2x.png", 1024, "512x512", "2x")
    ]

    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw RenderError.message("Pass the repository root as the only argument.")
        }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let review = root.appendingPathComponent("docs/review", isDirectory: true)
        try FileManager.default.createDirectory(at: review, withIntermediateDirectories: true)
        let assetRoots = ["App/Assets.xcassets/AppIcon.appiconset", "Extensions/FinderSync/Assets.xcassets/AppIcon.appiconset"]
        for assetRoot in assetRoots {
            let directory = root.appendingPathComponent(assetRoot, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for spec in specs {
                try render(width: spec.1, height: spec.1, to: directory.appendingPathComponent(spec.0)) { context in
                    drawBrandAppIcon(context: context, side: CGFloat(spec.1))
                }
            }
            let images = specs.map { ["filename": $0.0, "idiom": "mac", "size": $0.2, "scale": $0.3] }
            let catalog: [String: Any] = ["images": images, "info": ["author": "Super RClick", "version": 1]]
            try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("Contents.json"))
        }
        try render(width: 1024, height: 1024, to: review.appendingPathComponent("icons-app-master.png")) { context in
            drawBrandAppIcon(context: context, side: 1024)
        }
        let masterData = try Data(contentsOf: review.appendingPathComponent("icons-app-master.png"))
        for path in ["assets/icon.png", "Support/Assets/SuperRClick-icon-master.png", "Support/Assets/icon-source/master-logo.png"] {
            let target = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try masterData.write(to: target, options: .atomic)
        }
        let iconset = root.appendingPathComponent("Support/Assets/SuperRClick.iconset", isDirectory: true)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for spec in specs {
            let image = try Data(contentsOf: root.appendingPathComponent(assetRoots[0]).appendingPathComponent(spec.0))
            try image.write(to: iconset.appendingPathComponent(spec.0), options: .atomic)
        }
        try writeICNS(from: iconset, to: root.appendingPathComponent("Support/Assets/SuperRClick.icns"))
        let svgURL = root.appendingPathComponent("docs/release/SuperRClick-logo.svg")
        try FileManager.default.createDirectory(at: svgURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try appIconSVG.write(to: svgURL, atomically: true, encoding: .utf8)
        try contactSheet(dark: false, to: review.appendingPathComponent("icons-light.png"))
        try contactSheet(dark: true, to: review.appendingPathComponent("icons-dark.png"))
        try stateSheet(to: review.appendingPathComponent("icons-states.png"))
        let mapping = Dictionary(uniqueKeysWithValues: RClickIcon.supportedNames.map { ($0, RClickIcon.glyph(named: $0).rawValue) })
        let manifest: [String: Any] = [
            "design": "Original folded document and pointer cutout",
            "canvas": 24, "stroke": 1.8, "glyphCount": RClickIcon.Glyph.allCases.count,
            "legacyAndCanonicalKeys": mapping,
            "renderedSizes": sizes,
            "fallback": "action; only for unknown persisted user values",
            "externalIconInputs": [], "systemSymbolCalls": 0,
            "appIconSizes": specs.map { $0.1 }
        ]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: review.appendingPathComponent("icons-manifest.json"))
        print("Rendered \(RClickIcon.Glyph.allCases.count) original glyphs, \(RClickIcon.supportedNames.count) keys, two AppIcon catalogs, and light/dark/state contact sheets.")
    }

    private static func render(width: Int, height: Int, to url: URL, draw: (CGContext) -> Void) throws {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw RenderError.message("Could not create bitmap context.")
        }
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        draw(context)
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw RenderError.message("Could not create PNG output.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw RenderError.message("PNG output failed.") }
    }

    /// Original hand-authored paths, on a 100-unit top-left canvas.
    private static func drawBrandAppIcon(context c: CGContext, side: CGFloat) {
        c.saveGState()
        c.translateBy(x: 0, y: side)
        c.scaleBy(x: side / 100, y: -side / 100)
        let tile = CGPath(roundedRect: CGRect(x: 7, y: 7, width: 86, height: 86), cornerWidth: 19, cornerHeight: 19, transform: nil)
        c.addPath(tile); c.saveGState(); c.clip()
        let colors = [color(0x183E51).cgColor, color(0x102739).cgColor, color(0x0C182A).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!
        c.drawLinearGradient(gradient, start: CGPoint(x: 13, y: 10), end: CGPoint(x: 86, y: 91), options: [])
        c.restoreGState()
        c.setLineWidth(0.7); c.setStrokeColor(color(0x3C6976).withAlphaComponent(0.7).cgColor); c.addPath(tile); c.strokePath()

        // The fold is formed by the file's own silhouette, not a system document symbol.
        let page = CGMutablePath()
        page.move(to: CGPoint(x: 29, y: 21))
        page.addLine(to: CGPoint(x: 56, y: 21))
        page.addLine(to: CGPoint(x: 74, y: 39))
        page.addLine(to: CGPoint(x: 74, y: 69))
        page.addQuadCurve(to: CGPoint(x: 69, y: 74), control: CGPoint(x: 74, y: 74))
        page.addLine(to: CGPoint(x: 29, y: 74))
        page.addQuadCurve(to: CGPoint(x: 24, y: 69), control: CGPoint(x: 24, y: 74))
        page.addLine(to: CGPoint(x: 24, y: 26))
        page.addQuadCurve(to: CGPoint(x: 29, y: 21), control: CGPoint(x: 24, y: 21))
        page.closeSubpath()
        c.addPath(page); c.saveGState(); c.clip()
        let paperGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0x96E0D7).cgColor, color(0x3D9FAB).cgColor] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(paperGradient, start: CGPoint(x: 28, y: 23), end: CGPoint(x: 68, y: 76), options: [])
        c.restoreGState()
        fillPolygon([(56, 21), (56, 36), (59, 39), (74, 39)], color: color(0xD0F1E5), context: c)

        // Two quiet lines establish the document at large sizes; omitted at 16 px.
        if side >= 32 {
            c.setLineCap(.round); c.setLineWidth(2.8); c.setStrokeColor(color(0x24586A).withAlphaComponent(0.7).cgColor)
            c.move(to: CGPoint(x: 34, y: 39)); c.addLine(to: CGPoint(x: 45, y: 39)); c.strokePath()
            c.move(to: CGPoint(x: 34, y: 47)); c.addLine(to: CGPoint(x: 41, y: 47)); c.strokePath()
        }
        // Dark outline makes the warm pointer read as a cutout in the folded file.
        let pointer: [(CGFloat, CGFloat)] = [(47, 46), (47, 79), (56, 72), (64, 85), (74, 79), (65, 66), (77, 64), (47, 46)]
        let path = CGMutablePath()
        path.move(to: CGPoint(x: pointer[0].0, y: pointer[0].1))
        for p in pointer.dropFirst() { path.addLine(to: CGPoint(x: p.0, y: p.1)) }
        path.closeSubpath()
        c.setLineJoin(.round); c.setLineWidth(5.5); c.setStrokeColor(color(0x102738).cgColor); c.addPath(path); c.strokePath()
        c.setFillColor(color(0xF2AD78).cgColor); c.addPath(path); c.fillPath()
        c.restoreGState()
    }

    private static func contactSheet(dark: Bool, to url: URL) throws {
        let columns = 7, cellWidth = 180, cellHeight = 88, header = 94
        let glyphs = RClickIcon.Glyph.allCases
        let rows = (glyphs.count + columns - 1) / columns
        let width = columns * cellWidth + 40, height = rows * cellHeight + header + 20
        try render(width: width, height: height, to: url) { c in
            let background = color(dark ? 0x121B28 : 0xF7F8FA)
            let foreground = color(dark ? 0xEAF1F5 : 0x192B38)
            c.setFillColor(background.cgColor); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
            text("SUPER RCLICK / ORIGINAL ICONS", x: 28, top: 25, canvasHeight: height, font: 20, color: foreground, context: c)
            text("\(glyphs.count) hand-authored vector glyphs · 16 / 20 / 24 / 32 pixels · \(dark ? "dark" : "light")", x: 28, top: 55, canvasHeight: height, font: 12, color: foreground.withAlphaComponent(0.72), context: c)
            for (index, glyph) in glyphs.enumerated() {
                let x = 20 + (index % columns) * cellWidth, top = header + (index / columns) * cellHeight
                c.setStrokeColor(foreground.withAlphaComponent(0.12).cgColor); c.setLineWidth(0.5)
                c.stroke(CGRect(x: x + 2, y: height - top - cellHeight + 3, width: cellWidth - 7, height: cellHeight - 6))
                text(glyph.rawValue, x: x + 11, top: top + 10, canvasHeight: height, font: 11, color: foreground, context: c)
                var iconX = x + 11
                for size in sizes {
                    let rect = CGRect(x: iconX, y: height - top - 67 + (32 - size) / 2, width: size, height: size)
                    RClickIcon.draw(named: glyph.rawValue, in: rect, context: c, color: foreground)
                    iconX += size + 12
                }
            }
        }
    }

    private static func stateSheet(to url: URL) throws {
        let keys = ["brand", "pin", "pinned", "folder", "settings", "copy", "terminal", "rename", "image", "success", "warning", "ocr"]
        let states: [(String, NSColor, NSColor)] = [
            ("Light", color(0xF7F8FA), color(0x192B38)),
            ("Dark", color(0x121B28), color(0xEAF1F5)),
            ("Selected", color(0x155E75), .white),
            ("Disabled / light", color(0xF7F8FA), color(0x192B38).withAlphaComponent(0.38)),
            ("Disabled / dark", color(0x121B28), color(0xEAF1F5).withAlphaComponent(0.38)),
            ("High contrast / light", .white, .black),
            ("High contrast / dark", .black, .white)
        ]
        let width = 1244, rowHeight = 138, height = states.count * rowHeight + 76
        try render(width: width, height: height, to: url) { c in
            c.setFillColor(color(0xE7EBEF).cgColor); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
            text("TEMPLATE STATES / 16 · 20 · 24 · 32 px", x: 22, top: 25, canvasHeight: height, font: 20, color: color(0x192B38), context: c)
            for (stateIndex, state) in states.enumerated() {
                let top = 76 + stateIndex * rowHeight
                c.setFillColor(state.1.cgColor); c.fill(CGRect(x: 0, y: height - top - rowHeight, width: width, height: rowHeight))
                text(state.0, x: 20, top: top + 12, canvasHeight: height, font: 12, color: state.2, context: c)
                for (keyIndex, key) in keys.enumerated() {
                    let x = 20 + keyIndex * 100
                    text(key, x: x, top: top + 36, canvasHeight: height, font: 9, color: state.2, context: c)
                    var iconX = x
                    for size in sizes {
                        let rect = CGRect(x: iconX, y: height - top - 103 + (32 - size) / 2, width: size, height: size)
                        RClickIcon.draw(named: key, in: rect, context: c, color: state.2)
                        iconX += size + 2
                    }
                }
            }
        }
    }

    private static func text(_ string: String, x: Int, top: Int, canvasHeight: Int, font: CGFloat, color: NSColor, context: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let value = NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: font, weight: .medium), .foregroundColor: color])
        value.draw(at: CGPoint(x: x, y: canvasHeight - top - Int(font * 1.25)))
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func writeICNS(from iconset: URL, to url: URL) throws {
        // ICNS is a length-prefixed container. Modern records contain the PNG
        // payload directly. Explicit records retain every 1x/2x slot, including
        // ic10 (1024 px), which this host's ImageIO ICNS encoder otherwise omits.
        let recordTypes = ["icp4", "ic11", "icp5", "ic12", "ic07", "ic13", "ic08", "ic14", "ic09", "ic10"]
        var records = Data()
        for (spec, type) in zip(specs, recordTypes) {
            let png = try Data(contentsOf: iconset.appendingPathComponent(spec.0))
            records.append(Data(type.utf8))
            records.append(bigEndian: UInt32(png.count + 8))
            records.append(png)
        }
        var output = Data("icns".utf8)
        output.append(bigEndian: UInt32(records.count + 8))
        output.append(records)
        try output.write(to: url, options: .atomic)
        // Ask the native decoder to validate that the packaged master survives.
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              (0..<CGImageSourceGetCount(source)).contains(where: { index in
                  guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { return false }
                  return image.width == 1024 && image.height == 1024
              }) else { throw RenderError.message("ICNS decoding lost the 1024-pixel master.") }
    }

    private static func fillPolygon(_ points: [(CGFloat, CGFloat)], color: NSColor, context: CGContext) {
        context.beginPath(); context.move(to: CGPoint(x: points[0].0, y: points[0].1))
        for point in points.dropFirst() { context.addLine(to: CGPoint(x: point.0, y: point.1)) }
        context.closePath(); context.setFillColor(color.cgColor); context.fillPath()
    }

    private static func color(_ rgb: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }

    /// The same authored geometry as drawBrandAppIcon, preserved as editable SVG.
    private static let appIconSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 100 100" role="img" aria-labelledby="title desc">
      <title id="title">Super RClick original app icon</title>
      <desc id="desc">A teal folded document with a warm pointer cutout on a deep ink tile.</desc>
      <defs>
        <linearGradient id="tile" gradientUnits="userSpaceOnUse" x1="13" y1="10" x2="86" y2="91">
          <stop offset="0" stop-color="#183E51"/><stop offset=".55" stop-color="#102739"/><stop offset="1" stop-color="#0C182A"/>
        </linearGradient>
        <linearGradient id="paper" gradientUnits="userSpaceOnUse" x1="28" y1="23" x2="68" y2="76">
          <stop offset="0" stop-color="#96E0D7"/><stop offset="1" stop-color="#3D9FAB"/>
        </linearGradient>
      </defs>
      <rect x="7" y="7" width="86" height="86" rx="19" fill="url(#tile)" stroke="#3C6976" stroke-opacity=".7" stroke-width=".7"/>
      <path d="M29 21H56L74 39V69Q74 74 69 74H29Q24 74 24 69V26Q24 21 29 21Z" fill="url(#paper)"/>
      <path d="M56 21V36L59 39H74Z" fill="#D0F1E5"/>
      <path d="M34 39H45M34 47H41" fill="none" stroke="#24586A" stroke-opacity=".7" stroke-width="2.8" stroke-linecap="round"/>
      <path d="M47 46V79L56 72L64 85L74 79L65 66L77 64Z" fill="#F2AD78" stroke="#102738" stroke-width="5.5" stroke-linejoin="round" paint-order="stroke fill"/>
    </svg>
    """

    private enum RenderError: Error { case message(String) }
}

private extension Data {
    mutating func append(bigEndian value: UInt32) {
        var encoded = value.bigEndian
        Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
    }
}
