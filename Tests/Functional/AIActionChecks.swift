import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Shared
import UniformTypeIdentifiers

// The production executor is compiled verbatim. Only external services, window presentation,
// and Finder reveal are injected. All actual file mutations happen in this run's temp folder.
private struct CheckFailure: Error, CustomStringConvertible { let description: String }
private struct StubLLM: LLMServiceProtocol {
    let config = AIConfig()
    let response: String
    func sendMessage(prompt: String, systemPrompt: String?) async throws -> String { response }
    func testConnection() async throws -> Bool { true }
}

private final class ProgressLog: ProgressReporting, @unchecked Sendable {
    private let lock = NSLock()
    private var fractions: [Double] = []
    func updateProgress(fractionCompleted: Double, message: String?) {
        lock.withLock { fractions.append(fractionCompleted) }
    }
    var completed: Bool { lock.withLock { fractions.last == 1 } }
}

// Never constructs a real window, even if a test forgets to inject presentation.
@MainActor
final class AIResultWindowController {
    init(title: String, content: String) { fatalError("Test must inject result presentation") }
    func show() { fatalError("Test must inject result presentation") }
}

@MainActor
private final class Checks {
    let root: URL
    let fm = FileManager.default
    let progress = ProgressLog()
    var presentations: [(String, String)] = []
    var revealed: [URL] = []
    init(root: URL) { self.root = root }

    func require(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !value() { throw CheckFailure(description: message) }
    }
    func context(_ urls: [URL]) -> ContextSnapshot { .init(kind: .finderSelection, itemPaths: urls.map(\.path)) }
    func execute(_ executor: AIActionExecutor, _ action: ActionID, _ urls: [URL]) async throws {
        try await executor.execute(actionID: action, context: context(urls), aiConfig: AIConfig(), progressReporter: progress)
    }
    func executor(response: String = "safe name", png: Data = Data("stub PNG data".utf8)) -> AIActionExecutor {
        AIActionExecutor(
            makeLLMService: { _ in StubLLM(response: response) },
            extractText: { url, _ in "TEXT FROM \(url.lastPathComponent)" },
            removeBackground: { _ in png },
            presentResult: { [weak self] title, content in self?.presentations.append((title, content)) },
            revealFiles: { [weak self] urls in self?.revealed = urls }
        )
    }
    func fixture(_ name: String, text: String = "SUPER RCLICK 2026", foreground: Bool = false) throws -> URL {
        let url = root.appendingPathComponent(name)
        let width = 1200, height = 700
        guard let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                     bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CheckFailure(description: "Fixture context unavailable")
        }
        bitmap.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if foreground {
            // A synthetic red apple-like foreground with stem, leaf, highlight, and soft shadow.
            bitmap.setFillColor(CGColor(gray: 0.85, alpha: 1))
            bitmap.fillEllipse(in: CGRect(x: 365, y: 90, width: 500, height: 80))
            bitmap.setFillColor(CGColor(red: 0.75, green: 0.04, blue: 0.06, alpha: 1))
            bitmap.fillEllipse(in: CGRect(x: 385, y: 145, width: 300, height: 360))
            bitmap.fillEllipse(in: CGRect(x: 515, y: 145, width: 300, height: 360))
            bitmap.setFillColor(CGColor(red: 0.3, green: 0.13, blue: 0.04, alpha: 1))
            bitmap.fill(CGRect(x: 586, y: 460, width: 22, height: 100))
            bitmap.setFillColor(CGColor(red: 0.05, green: 0.42, blue: 0.08, alpha: 1))
            bitmap.fillEllipse(in: CGRect(x: 600, y: 510, width: 120, height: 55))
            bitmap.setFillColor(CGColor(red: 1, green: 0.65, blue: 0.65, alpha: 1))
            bitmap.fillEllipse(in: CGRect(x: 438, y: 353, width: 55, height: 80))
        } else {
            let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 66, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            bitmap.textPosition = CGPoint(x: 70, y: 340)
            CTLineDraw(line, bitmap)
        }
        guard let image = bitmap.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CheckFailure(description: "Cannot encode PNG fixture")
        }
        CGImageDestinationAddImage(destination, image, nil)
        try require(CGImageDestinationFinalize(destination), "PNG fixture encoding failed")
        return url
    }

    func check(_ name: String) async throws -> String {
        if name.hasPrefix("empty-") {
            let action: ActionID
            switch name {
            case "empty-rename": action = AIActionCatalog.smartRename
            case "empty-tag": action = AIActionCatalog.autoTag
            case "empty-ocr": action = AIActionCatalog.ocrExtract
            default: action = AIActionCatalog.removeBackground
            }
            var rejected = false
            do { try await execute(executor(), action, []) } catch { rejected = true }
            try require(rejected, "Empty selection returned success instead of an error")
            try require(!progress.completed && presentations.isEmpty && revealed.isEmpty, "Empty selection caused success side effects")
            return "Empty selection rejected without success progress, window, or Finder reveal (injected services)"
        }
        switch name {
        case "rename-parent-traversal", "rename-nested-path", "rename-invalid-names":
            let selected = root.appendingPathComponent("selected", isDirectory: true)
            try fm.createDirectory(at: selected, withIntermediateDirectories: true)
            try fm.createDirectory(at: selected.appendingPathComponent("nested"), withIntermediateDirectories: true)
            let suggestions = name == "rename-parent-traversal" ? ["../escaped"] :
                name == "rename-nested-path" ? ["nested/escaped"] : [".", "..", "bad\\name", "bad:name", "bad\nname", "bad\0name", "/absolute"]
            for (index, suggestion) in suggestions.enumerated() {
                let input = try fixture("input-\(index).png")
                let source = selected.appendingPathComponent(input.lastPathComponent)
                try fm.moveItem(at: input, to: source)
                let original = try Data(contentsOf: source)
                var rejected = false
                do { try await execute(executor(response: suggestion), AIActionCatalog.smartRename, [source]) } catch { rejected = true }
                try require(fm.fileExists(atPath: source.path), "Unsafe model filename moved source: \(String(reflecting: suggestion))")
                try require(try Data(contentsOf: source) == original, "Original contents changed")
                try require(rejected, "Unsafe model filename accepted: \(String(reflecting: suggestion))")
            }
            try require(!fm.fileExists(atPath: root.appendingPathComponent("escaped.png").path), "File escaped selected directory")
            return "Rejected unsafe model filenames; original PNG bytes and directory boundary preserved (fake LLM)"
        case "rename-valid":
            let source = try fixture("original.PNG")
            let payload = try Data(contentsOf: source)
            try await execute(executor(response: "project notes"), AIActionCatalog.smartRename, [source])
            let output = root.appendingPathComponent("project notes.PNG")
            try require(try Data(contentsOf: output) == payload, "Valid rename changed data or extension")
            try require(!fm.fileExists(atPath: source.path), "Original was not renamed")
            return "Real file move preserves PNG data and .PNG extension (fake LLM)"
        case "rename-existing-output":
            let source = try fixture("original.png")
            let original = try Data(contentsOf: source)
            let existing = root.appendingPathComponent("occupied.png")
            try Data("existing file must survive".utf8).write(to: existing)
            var rejected = false
            do { try await execute(executor(response: "occupied"), AIActionCatalog.smartRename, [source]) } catch { rejected = true }
            try require(rejected, "Conflicting rename silently reported success")
            try require(try Data(contentsOf: source) == original, "Source contents changed")
            try require(try Data(contentsOf: existing) == Data("existing file must survive".utf8), "Existing destination overwritten")
            return "Conflict reported without overwriting either file (fake LLM)"
        case "background-output-collision", "background-output-symlink":
            let source = try fixture("photo.png")
            let png = try Data(contentsOf: source)
            let existing = root.appendingPathComponent("photo.transparent.png")
            if name == "background-output-symlink" {
                try fm.createSymbolicLink(at: existing, withDestinationURL: root.appendingPathComponent("must-not-be-created.png"))
            } else {
                try Data("existing output must survive".utf8).write(to: existing)
            }
            try await execute(executor(png: png), AIActionCatalog.removeBackground, [source])
            if name == "background-output-symlink" {
                try require(try fm.destinationOfSymbolicLink(atPath: existing.path).hasSuffix("must-not-be-created.png"), "Existing symlink replaced")
                try require(!fm.fileExists(atPath: root.appendingPathComponent("must-not-be-created.png").path), "Wrote through existing symlink")
            } else {
                try require(try Data(contentsOf: existing) == Data("existing output must survive".utf8), "Existing background output overwritten")
            }
            try require(revealed.count == 1 && revealed.first != source && revealed.first != existing, "Reveal must select newly written output")
            try require(try Data(contentsOf: revealed[0]) == png, "Generated PNG payload incorrect")
            try await execute(executor(png: png), AIActionCatalog.removeBackground, [source])
            let generated = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter {
                $0.lastPathComponent.hasPrefix("photo.transparent-")
            }
            try require(generated.count == 2, "Repeated action must create a second unique output")
            return "Existing file/symlink preserved; repeated action writes two new PNGs and reveals output (fake Vision)"
        case "ocr-multiple-images":
            let first = try fixture("first.png"), second = try fixture("second.png")
            try await execute(executor(), AIActionCatalog.ocrExtract, [first, second])
            try require(presentations.count == 1, "Expected one combined OCR result")
            try require(presentations[0].1.contains("TEXT FROM first.png") && presentations[0].1.contains("TEXT FROM second.png"),
                        "OCR result omitted selected image(s): \(presentations[0].1)")
            try require(progress.completed, "OCR progress never completed")
            return "Both images processed into one labeled result (fake Vision, real executor)"
        case "vision-real-ocr":
            let first = try fixture("ocr-one.png"), second = try fixture("ocr-two.png", text: "SECOND IMAGE 42")
            let realExecutor = AIActionExecutor(
                makeLLMService: { _ in nil },
                presentResult: { [weak self] title, content in self?.presentations.append((title, content)) },
                revealFiles: { _ in }
            )
            try await execute(realExecutor, AIActionCatalog.ocrExtract, [first, second])
            let text = presentations.map(\.1).joined(separator: "\n")
            try text.write(to: root.appendingPathComponent("recognized-text.txt"), atomically: true, encoding: .utf8)
            try require(text.contains("SUPER RCLICK 2026") && text.contains("SECOND IMAGE 42"), "Real OCR text missing: \(text)")
            return "REAL Vision recognized both synthetic images: \(text.replacingOccurrences(of: "\n", with: " | "))"
        case "vision-real-background":
            let source = try fixture("synthetic-apple.png", foreground: true)
            let data = try await LocalVisionService.removeBackground(from: source)
            let output = root.appendingPathComponent("real-transparent.png")
            try data.write(to: output)
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw CheckFailure(description: "Real Vision output is not a decodable PNG")
            }
            try require(image.width == 1200 && image.height == 700, "Real Vision output dimensions changed")
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let alphaRange: (UInt8, UInt8)? = pixels.withUnsafeMutableBytes { buffer in
                guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                              bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                let bytes = buffer.bindMemory(to: UInt8.self)
                let alpha = stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
                return (alpha.min() ?? 255, alpha.max() ?? 0)
            }
            try require(alphaRange != nil && alphaRange!.0 < 20 && alphaRange!.1 > 230,
                        "Real mask did not contain transparent background and opaque foreground: \(String(describing: alphaRange))")
            return "REAL Vision created 1200x700 PNG with transparent background and opaque subject"
        default: throw CheckFailure(description: "Unknown case: \(name)")
        }
    }
}

@main
private enum Main {
    @MainActor static func main() async {
        guard CommandLine.arguments.count == 3 else { fatalError("Usage: ai-checks <case> <fresh-case-directory>") }
        let name = CommandLine.arguments[1]
        let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let detail = try await Checks(root: root).check(name)
            print("PASS | \(name) | \(detail)")
        } catch {
            let nsError = error as NSError
            print("FAIL | \(name) | \(error) | \(nsError.domain) \(nsError.code): \(nsError.localizedDescription)")
            exit(1)
        }
    }
}
