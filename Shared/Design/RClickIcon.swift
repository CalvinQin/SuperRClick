import AppKit
import SwiftUI

/// Super RClick's original 24-unit icon vocabulary. Legacy strings are semantic
/// aliases only: this renderer never asks the operating system for a symbol.
@MainActor
public enum RClickIcon {
    public enum Glyph: String, CaseIterable, Sendable {
        case brand, action, library, sidebar, pin, pinned, unpin, recent, tools, folder, workspace
        case settings, sliders, refresh, plus, add, more, search, close
        case copy, clipboard, terminal, archive, rename, image, text, document, newDocument
        case richText, table, presentation, code, script, language, web, braces, data, application
        case run, right, jump, download, update, save, dock, desktop, setup, link, hammer
        case info, success, warning, error, blocked, unknown, minus, trash, shield
        case accessibility, keyboard, tip, tag, ocr, cutout
        case intelligence, sparkle, chip, star, cube, cloud, moon, server
    }

    /// All supported persisted keys, useful for migrations and coverage checks.
    public static var supportedNames: [String] {
        Array(Set(aliases.keys).union(Glyph.allCases.map(\.rawValue))).sorted()
    }

    public static func glyph(named name: String) -> Glyph {
        aliases[name] ?? Glyph(rawValue: name) ?? .action
    }

    /// A resolution-independent PDF-backed template, tinted by AppKit/SwiftUI.
    public static func image(named name: String, size: CGFloat = 20) -> NSImage {
        let side = max(1, size)
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: side, height: side)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            let empty = NSImage(size: NSSize(width: side, height: side))
            empty.isTemplate = true
            return empty
        }
        context.beginPDFPage(nil)
        draw(named: name, in: mediaBox, context: context, color: .black)
        context.endPDFPage()
        context.closePDF()
        let result = NSImage(data: data as Data) ?? NSImage(size: mediaBox.size)
        result.size = mediaBox.size
        result.isTemplate = true
        result.accessibilityDescription = nil // The enclosing control owns its label.
        return result
    }

    /// Draws into an ordinary (bottom-left origin) Core Graphics context.
    public static func draw(named name: String, in rect: CGRect, context: CGContext, color: NSColor) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: rect.width / 24, y: -rect.height / 24)
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(1.8)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        draw(glyph: glyph(named: name), pen: Pen(context))
        context.restoreGState()
    }

    private static let aliases: [String: Glyph] = [
        "bolt": .action, "bolt.fill": .action,
        "square.grid.2x2.fill": .library,
        "pin": .pin, "pin.fill": .pinned, "pin.slash.fill": .unpin,
        "clock.arrow.circlepath": .recent,
        "wrench.and.screwdriver.fill": .tools,
        "folder": .folder, "folder.fill": .folder,
        "folder.badge.gearshape": .workspace, "square.stack.3d.up.fill": .workspace,
        "gear": .settings, "gearshape": .settings, "gearshape.fill": .settings,
        "gearshape.2": .settings, "gearshape.arrow.triangle.2.circlepath": .settings,
        "slider.horizontal.3": .sliders,
        "arrow.clockwise": .refresh,
        "plus.circle.fill": .add, "doc.badge.plus": .newDocument,
        "ellipsis": .more, "magnifyingglass": .search,
        "xmark": .close, "xmark.circle.fill": .error, "xmark.octagon.fill": .error,
        "doc.on.doc": .copy, "doc.on.doc.fill": .copy,
        "doc.on.clipboard": .clipboard,
        "terminal.fill": .terminal,
        "archivebox": .archive, "archivebox.fill": .archive,
        "pencil.and.list.clipboard": .rename, "character.cursor.ibeam": .rename,
        "photo": .image, "photo.on.rectangle.angled": .image,
        "doc.text": .text, "doc.text.fill": .text, "doc.plaintext": .text,
        "doc": .document, "doc.fill": .document, "doc.richtext": .richText,
        "tablecells": .table, "play.rectangle": .presentation,
        "chevron.left.forwardslash.chevron.right": .code,
        "applescript": .script, "swift": .language, "cup.and.saucer": .language,
        "c.square": .language, "safari": .web, "paintbrush": .web,
        "curlybraces.square": .braces,
        "app.badge.fill": .application, "play.fill": .run,
        "arrow.right": .right, "arrow.right.circle": .jump,
        "arrow.down.circle": .download, "arrow.down.circle.fill": .download,
        "arrow.down.app": .update, "square.and.arrow.down": .save, "dock.rectangle": .dock,
        "desktopcomputer": .desktop, "wand.and.stars": .setup,
        "info.circle": .info, "info.circle.fill": .info,
        "checkmark": .success, "checkmark.circle.fill": .success, "checkmark.seal.fill": .success,
        "exclamationmark.triangle.fill": .warning, "exclamationmark.applepodcasts": .warning,
        "exclamationmark.shield.fill": .blocked, "questionmark.folder.fill": .unknown,
        "minus.circle.fill": .minus, "lock.shield": .shield,
        "lightbulb.fill": .tip, "tag.fill": .tag,
        "text.viewfinder": .ocr, "person.crop.circle.badge.minus": .cutout,
        "brain.head.profile": .intelligence, "sparkles": .sparkle,
        "cpu": .chip, "star.fill": .star, "cube.transparent": .cube,
        "cloud.fill": .cloud, "moon.stars.fill": .moon, "server.rack": .server,
        "globe": .web, "globe.europe.africa.fill": .web,
        "cursorarrow.and.square.on.square.dashed": .brand
    ]

    private static func draw(glyph: Glyph, pen p: Pen) {
        switch glyph {
        case .brand:
            p.poly([(5, 21), (5, 3), (14, 3), (19, 8), (19, 12)])
            p.poly([(14, 3), (14, 8), (19, 8)])
            p.poly([(10, 12), (10, 21), (13.3, 18), (16.5, 22), (19, 20), (15.7, 16), (20, 15), (10, 12)], fill: true)
        case .action:
            p.poly([(13, 3), (5, 13), (10, 13), (9, 21), (19, 10), (13, 10), (13, 3)], fill: true)
        case .library:
            p.round(3, 3, 7, 8, 1.8); p.round(14, 3, 7, 5, 1.8)
            p.round(3, 15, 7, 6, 1.8); p.round(14, 12, 7, 9, 1.8)
        case .sidebar:
            p.round(2.5, 3.5, 19, 17, 2); p.line(9, 3.5, 9, 20.5)
            p.line(5, 8, 6.5, 8); p.line(5, 12, 6.5, 12); p.line(5, 16, 6.5, 16)
            p.line(13, 8, 18, 8); p.line(13, 12, 16, 12)
        case .pin, .pinned, .unpin:
            p.poly([(8, 3), (16, 3), (15, 10), (18, 14), (6, 14), (9, 10), (8, 3)], fill: glyph == .pinned)
            p.line(12, 14, 12, 21)
            if glyph == .unpin { p.line(3, 4, 21, 22) }
        case .recent:
            p.arc(12, 12, 8.2, -110, 170)
            p.poly([(3, 6), (3, 12), (8, 12)])
            p.poly([(12, 7), (12, 12), (16, 14)])
        case .tools:
            p.poly([(4, 4), (7, 4), (10, 7), (8, 9), (5, 6), (4, 4)])
            p.line(9, 9, 19, 20)
            p.poly([(17, 3), (15, 7), (17, 10), (21, 8)])
            p.line(15, 9, 5, 20)
        case .folder, .workspace, .unknown:
            p.poly([(3, 19), (3, 5), (9, 5), (12, 8), (21, 8), (21, 19), (3, 19)])
            if glyph == .workspace { p.round(8, 11, 8, 5, 1); p.line(12, 11, 12, 16) }
            if glyph == .unknown { p.curve((10, 12), (10, 10), (15, 10), (14, 13)); p.line(14, 13, 12, 14); p.dot(12, 17, 0.8) }
        case .settings:
            p.poly([(9, 3), (15, 3), (16, 6), (20, 7), (21, 12), (19, 14), (19, 18), (14, 21), (11, 19), (7, 20), (3, 16), (5, 12), (3, 8), (7, 5), (9, 3)])
            p.circle(12, 12, 3.2)
        case .sliders:
            p.line(3, 6, 21, 6); p.line(3, 12, 21, 12); p.line(3, 18, 21, 18)
            p.round(6, 3.5, 3, 5, 1, fill: true); p.round(15, 9.5, 3, 5, 1, fill: true); p.round(8, 15.5, 3, 5, 1, fill: true)
        case .refresh:
            p.arc(12, 12, 8, 15, 300); p.poly([(15, 3), (20, 5), (19, 10)])
        case .plus, .add:
            if glyph == .add { p.circle(12, 12, 9) }
            p.line(7, 12, 17, 12); p.line(12, 7, 12, 17)
        case .more:
            for x in [CGFloat(5), 12, 19] { p.dot(x, 12, 1.5) }
        case .search:
            p.circle(10, 10, 6.5); p.line(15, 15, 21, 21)
        case .close:
            p.line(6, 6, 18, 18); p.line(18, 6, 6, 18)
        case .copy:
            p.poly([(8, 5), (8, 3), (20, 3), (20, 16), (18, 16)])
            p.round(3, 8, 12, 13, 2); p.line(7, 12, 11, 12); p.line(7, 16, 11, 16)
        case .clipboard:
            p.round(5, 5, 14, 16, 2); p.round(8, 2.5, 8, 5, 1.5)
            p.line(9, 12, 15, 12); p.line(9, 16, 13, 16)
        case .terminal:
            p.round(2.5, 4.5, 19, 15, 2.5); p.poly([(6, 9), (9, 12), (6, 15)]); p.line(12, 15, 17, 15)
        case .archive:
            p.round(3, 4, 18, 5, 1.3); p.poly([(5, 9), (5, 20), (19, 20), (19, 9)])
            p.round(9, 12, 6, 3, 0.5)
        case .rename:
            p.poly([(4, 4), (4, 20), (12, 20)]); p.line(8, 5, 14, 5); p.line(8, 9, 12, 9)
            p.poly([(11, 17), (18, 7), (21, 10), (14, 20), (10, 21), (11, 17)])
            p.line(16.5, 9, 19.5, 12)
        case .image:
            p.round(3, 3, 18, 18, 2.5); p.circle(8, 8, 1.6)
            p.poly([(4, 18), (10, 12), (14, 16), (17, 12), (21, 16)])
        case .text, .document, .richText, .newDocument:
            p.document()
            if glyph == .text || glyph == .richText { p.line(8, 12, 16, 12); p.line(8, 16, 13, 16) }
            if glyph == .richText { p.line(8, 9, 10, 9) }
            if glyph == .newDocument { p.line(8, 15, 16, 15); p.line(12, 11, 12, 19) }
        case .table:
            p.round(3, 4, 18, 16, 2); p.line(3, 9, 21, 9); p.line(3, 14, 21, 14)
            p.line(9, 4, 9, 20); p.line(15, 4, 15, 20)
        case .presentation:
            p.round(3, 3, 18, 14, 2); p.poly([(10, 7), (15, 10), (10, 13), (10, 7)], fill: true)
            p.line(12, 17, 12, 21); p.line(7, 21, 17, 21)
        case .code:
            p.poly([(8, 5), (3, 12), (8, 19)]); p.poly([(16, 5), (21, 12), (16, 19)]); p.line(14, 4, 10, 20)
        case .script:
            p.poly([(8, 3), (20, 3), (20, 17), (17, 21), (5, 21), (5, 7), (8, 3)])
            p.poly([(9, 9), (12, 12), (9, 15)]); p.line(14, 15, 17, 15)
        case .language:
            p.poly([(5, 20), (5, 5), (8, 3), (18, 3), (18, 20), (5, 20)])
            p.poly([(10, 8), (8, 11), (10, 14)]); p.poly([(14, 8), (16, 11), (14, 14)]); p.line(9, 17, 14, 17)
        case .web:
            p.circle(12, 12, 9); p.line(3, 12, 21, 12)
            p.curve((12, 3), (6, 8), (6, 16), (12, 21)); p.curve((12, 3), (18, 8), (18, 16), (12, 21))
        case .braces:
            p.poly([(9, 3), (6, 3), (6, 10), (3, 12), (6, 14), (6, 21), (9, 21)])
            p.poly([(15, 3), (18, 3), (18, 10), (21, 12), (18, 14), (18, 21), (15, 21)])
            p.dot(12, 9, 0.9); p.dot(12, 15, 0.9)
        case .data:
            p.round(4, 3, 16, 18, 2); p.line(8, 8, 16, 8); p.line(8, 12, 13, 12); p.line(8, 16, 16, 16)
        case .application:
            p.round(3, 3, 18, 18, 3); p.line(3, 8, 21, 8); p.dot(6, 5.5, 0.7)
            p.poly([(10, 12), (16, 15), (10, 18), (10, 12)], fill: true)
        case .run:
            p.poly([(7, 4), (20, 12), (7, 20), (7, 4)], fill: true)
        case .right, .jump:
            if glyph == .jump { p.round(3, 3, 18, 18, 5) }
            p.line(6, 12, 18, 12); p.poly([(13, 7), (18, 12), (13, 17)])
        case .download, .update:
            p.line(12, 3, 12, 15); p.poly([(7, 10), (12, 15), (17, 10)])
            if glyph == .update { p.round(3, 3, 18, 18, 3) }
            else { p.poly([(4, 16), (4, 21), (20, 21), (20, 16)]) }
        case .save:
            p.document(); p.line(12, 10, 12, 17); p.poly([(9, 14), (12, 17), (15, 14)])
        case .dock:
            p.round(3, 5, 18, 15, 2.5); p.line(3, 15, 21, 15)
            for x in [CGFloat(7), 12, 17] { p.dot(x, 17.5, 1) }
        case .desktop:
            p.round(2.5, 3.5, 19, 13, 2); p.line(12, 16.5, 12, 21); p.line(7, 21, 17, 21)
        case .setup:
            p.poly([(4, 20), (15, 5), (18, 8), (7, 23), (4, 20)])
            p.line(17, 2, 17, 4); p.line(20, 6, 22, 6); p.line(8, 3, 8, 6); p.line(6.5, 4.5, 9.5, 4.5)
        case .link:
            p.curve((10, 7), (16, -1), (26, 7), (17, 14))
            p.curve((14, 17), (8, 25), (-2, 17), (7, 10))
            p.line(8, 16, 16, 8)
        case .hammer:
            p.poly([(8, 4), (17, 4), (21, 8), (17, 11), (13, 8), (10, 10), (6, 6), (8, 4)])
            p.poly([(12, 10), (6, 21), (3, 19), (10, 8)])
        case .info:
            p.circle(12, 12, 9); p.dot(12, 7.5, 1); p.poly([(10, 11), (12, 11), (12, 17)]); p.line(10, 17, 14, 17)
        case .success:
            p.circle(12, 12, 9); p.poly([(7, 12), (10.5, 15.5), (17, 8.5)])
        case .warning:
            p.poly([(12, 3), (22, 20), (2, 20), (12, 3)]); p.line(12, 9, 12, 13.5); p.dot(12, 17, 0.85)
        case .error:
            p.round(3, 3, 18, 18, 5); p.line(8, 8, 16, 16); p.line(16, 8, 8, 16)
        case .blocked, .shield:
            p.poly([(12, 2.5), (21, 6), (19, 15), (12, 22), (5, 15), (3, 6), (12, 2.5)])
            if glyph == .blocked { p.line(12, 7, 12, 12.5); p.dot(12, 16, 0.8) }
            else { p.round(8, 10, 8, 7, 1); p.arc(12, 10, 3, 180, 360) }
        case .minus:
            p.circle(12, 12, 9); p.line(7, 12, 17, 12)
        case .trash:
            p.poly([(5, 7), (6, 21), (18, 21), (19, 7)]); p.line(3, 7, 21, 7)
            p.round(8, 3, 8, 4, 1); p.line(10, 11, 10, 17); p.line(14, 11, 14, 17)
        case .accessibility:
            p.circle(12, 4, 2); p.poly([(4, 9), (12, 11), (20, 9)]); p.line(12, 11, 12, 15)
            p.line(12, 15, 7, 22); p.line(12, 15, 17, 22)
        case .keyboard:
            p.round(2, 5, 20, 14, 2)
            for x in [CGFloat(6), 10, 14, 18] { p.dot(x, 9, 0.8); p.dot(x, 12.5, 0.8) }
            p.line(8, 16, 16, 16)
        case .tip:
            p.curve((8, 15), (-1, 5), (12, -2), (17, 6)); p.curve((17, 6), (22, 12), (14, 13), (16, 17))
            p.poly([(8, 15), (8, 18), (16, 18)]); p.line(9, 21, 15, 21); p.poly([(9, 9), (12, 12), (15, 9)]); p.line(12, 12, 12, 17)
        case .tag:
            p.poly([(3, 4), (13, 4), (22, 13), (13, 22), (3, 12), (3, 4)]); p.circle(8, 8, 1.4)
        case .ocr:
            p.poly([(3, 8), (3, 3), (8, 3)]); p.poly([(16, 3), (21, 3), (21, 8)])
            p.poly([(3, 16), (3, 21), (8, 21)]); p.poly([(16, 21), (21, 21), (21, 16)])
            p.line(8, 8, 16, 8); p.line(12, 8, 12, 16); p.line(9, 16, 15, 16)
        case .cutout:
            p.poly([(3, 8), (3, 3), (8, 3)]); p.poly([(16, 3), (21, 3), (21, 8)])
            p.poly([(3, 16), (3, 21), (8, 21)]); p.poly([(16, 21), (21, 21), (21, 16)])
            p.circle(12, 9, 2.5); p.curve((7, 18), (7, 12), (17, 12), (17, 18)); p.line(7, 18, 17, 18)
        case .intelligence:
            p.poly([(6, 20), (6, 15), (3, 12), (5, 6), (10, 3), (17, 4), (21, 9), (19, 15), (15, 17), (15, 21)])
            p.circle(12, 10, 2); p.line(12, 6, 12, 8); p.line(8, 10, 10, 10); p.line(14, 10, 16, 10)
        case .sparkle:
            p.poly([(10, 3), (12, 10), (19, 12), (12, 14), (10, 21), (8, 14), (1, 12), (8, 10), (10, 3)])
            p.line(19, 2, 19, 7); p.line(16.5, 4.5, 21.5, 4.5)
        case .chip:
            p.round(6, 6, 12, 12, 2); p.round(9, 9, 6, 6, 1)
            for v in [CGFloat(8), 12, 16] { p.line(v, 2, v, 6); p.line(v, 18, v, 22); p.line(2, v, 6, v); p.line(18, v, 22, v) }
        case .star:
            p.poly([(12, 2), (15, 8.5), (22, 10), (17, 15), (18, 22), (12, 18), (6, 22), (7, 15), (2, 10), (9, 8.5), (12, 2)])
        case .cube:
            p.poly([(12, 2.5), (21, 7.5), (21, 17), (12, 22), (3, 17), (3, 7.5), (12, 2.5)])
            p.poly([(3, 7.5), (12, 12.5), (21, 7.5)]); p.line(12, 12.5, 12, 22)
        case .cloud:
            p.curve((6, 19), (-2, 18), (0, 9), (7, 10)); p.curve((7, 10), (6, 1), (19, 1), (19, 10))
            p.curve((19, 10), (26, 11), (23, 19), (18, 19)); p.line(6, 19, 18, 19)
        case .moon:
            p.curve((13, 3), (-2, 3), (2, 25), (19, 19)); p.curve((19, 19), (9, 18), (7, 10), (13, 3))
            p.line(19, 4, 19, 10); p.line(16, 7, 22, 7)
        case .server:
            p.round(3, 3, 18, 8, 2); p.round(3, 14, 18, 7, 2)
            p.dot(7, 7, 1); p.dot(7, 17.5, 1); p.line(12, 7, 17, 7); p.line(12, 17.5, 17, 17.5)
        }
    }

    private struct Pen {
        let c: CGContext
        init(_ context: CGContext) { c = context }
        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            c.beginPath(); c.move(to: CGPoint(x: x1, y: y1)); c.addLine(to: CGPoint(x: x2, y: y2)); c.strokePath()
        }
        func poly(_ points: [(CGFloat, CGFloat)], fill: Bool = false) {
            guard let first = points.first else { return }
            c.beginPath(); c.move(to: CGPoint(x: first.0, y: first.1))
            for point in points.dropFirst() { c.addLine(to: CGPoint(x: point.0, y: point.1)) }
            if fill { c.closePath(); c.fillPath() } else { c.strokePath() }
        }
        func round(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, fill: Bool = false) {
            c.beginPath(); c.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil))
            if fill { c.fillPath() } else { c.strokePath() }
        }
        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            c.strokeEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        func arc(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ start: CGFloat, _ end: CGFloat) {
            c.beginPath(); c.addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: start * .pi / 180, endAngle: end * .pi / 180, clockwise: false); c.strokePath()
        }
        func curve(_ start: (CGFloat, CGFloat), _ control1: (CGFloat, CGFloat), _ control2: (CGFloat, CGFloat), _ end: (CGFloat, CGFloat)) {
            c.beginPath(); c.move(to: CGPoint(x: start.0, y: start.1))
            c.addCurve(to: CGPoint(x: end.0, y: end.1), control1: CGPoint(x: control1.0, y: control1.1), control2: CGPoint(x: control2.0, y: control2.1)); c.strokePath()
        }
        func document() {
            poly([(5, 21), (5, 3), (14, 3), (19, 8), (19, 21), (5, 21)])
            poly([(14, 3), (14, 8), (19, 8)])
        }
    }
}

public extension Image {
    @MainActor init(rclick name: String) {
        self.init(nsImage: RClickIcon.image(named: name))
    }
}

/// A native Label with the original icon; system label styles remain available.
@MainActor
public struct RClickLabel: View {
    private let title: String
    private let icon: String

    public init(_ title: String, icon: String) {
        self.title = title
        self.icon = icon
    }

    public var body: some View {
        Label { Text(title) } icon: { Image(rclick: icon) }
    }
}
