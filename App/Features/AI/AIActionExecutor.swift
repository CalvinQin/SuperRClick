import Foundation
import AppKit
import ImageIO
import PDFKit
import Shared

extension ContextSnapshot {
    var effectiveSelectionURLs: [URL] {
        itemPaths.map { URL(fileURLWithPath: $0) }
    }
}

@MainActor
public final class AIActionExecutor {
    private var resultWindows: [UUID: AIResultWindowController] = [:]
    
    public init() {}
    
    public func execute(
        actionID: ActionID,
        context: ContextSnapshot,
        aiConfig: AIConfig,
        progressReporter: ProgressReporting
    ) async throws {
        
        switch actionID {
        case AIActionCatalog.smartRename:
            try await executeSmartRename(context: context, config: aiConfig, reporter: progressReporter)
            

            
        case AIActionCatalog.autoTag:
            try await executeAutoTag(context: context, config: aiConfig, reporter: progressReporter)
            
        case AIActionCatalog.ocrExtract:
            try await executeLocalOCR(context: context, reporter: progressReporter)
            
        case AIActionCatalog.removeBackground:
            try await executeRemoveBackground(context: context, reporter: progressReporter)
            
        default:
            throw NSError(domain: "AIActionExecutor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown AI action."])
        }
    }
    
    // MARK: - Local AI (Vision)
    
    private func executeLocalOCR(context: ContextSnapshot, reporter: ProgressReporting) async throws {
        reporter.updateProgress(fractionCompleted: 0.1, message: L("准备提取文字...", "Preparing text extraction..."))
        
        guard let url = context.effectiveSelectionURLs.first else { return }
        let text = try await LocalVisionService.extractText(from: url, accurate: true)
        
        reporter.updateProgress(fractionCompleted: 1.0, message: L("提取完成", "Extraction complete"))
        
        showResult(title: L("OCR 提取结果", "OCR Extracted Text"), content: text)
    }
    
    private func executeRemoveBackground(context: ContextSnapshot, reporter: ProgressReporting) async throws {
        reporter.updateProgress(fractionCompleted: 0.1, message: L("处理图片中...", "Processing image..."))
        
        guard #available(macOS 14.0, *) else {
            throw LocalVisionService.VisionError.unsupportedOS
        }
        
        let total = Double(context.effectiveSelectionURLs.count)
        for (index, url) in context.effectiveSelectionURLs.enumerated() {
            reporter.updateProgress(
                fractionCompleted: Double(index) / total,
                message: L("正在处理: \(url.lastPathComponent)", "Processing: \(url.lastPathComponent)")
            )
            
            let pngData = try await LocalVisionService.removeBackground(from: url)
            
            let newURL = url.deletingPathExtension().appendingPathExtension("transparent.png")
            try pngData.write(to: newURL)
        }
        
        reporter.updateProgress(fractionCompleted: 1.0, message: L("处理完成", "Processing complete"))
        NSWorkspace.shared.activateFileViewerSelecting([context.effectiveSelectionURLs.first!])
    }
    
    // MARK: - LLM API Actions
    
    private func requireLLM(config: AIConfig) throws -> LLMServiceProtocol {
        guard let service = LLMServiceFactory.makeService(for: config) else {
            throw LLMError.apiError("AI configuration is missing or invalid.")
        }
        return service
    }
    
    private func extractTextContent(from url: URL) throws -> String {
        let ext = url.pathExtension.lowercased()
        
        // 1. Check for PDF
        if ext == "pdf", let pdfDoc = PDFDocument(url: url) {
            var text = ""
            for i in 0..<min(pdfDoc.pageCount, 10) { // Limit to 10 pages for safety
                if let page = pdfDoc.page(at: i), let pageString = page.string {
                    text += pageString + "\n"
                    if text.count > 10240 { break }
                }
            }
            if !text.isEmpty {
                return String(text.prefix(10240))
            }
        }
        
        // 2. Check for Rich Text / Word formats natively supported by NSAttributedString
        if ["rtf", "rtfd", "doc", "docx", "txt", "csv", "md"].contains(ext) {
            if let attrString = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                return String(attrString.string.prefix(10240))
            }
        }
        
        // 3. Fallback: UTF-8 plain text read
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }
        let data = try fileHandle.read(upToCount: 10240) ?? Data()
        
        if let utf8String = String(data: data, encoding: .utf8) {
            return utf8String
        } else if let macString = String(data: data, encoding: .macOSRoman) {
            return macString
        }
        
        return ""
    }
    

    
    private let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "bmp", "gif", "webp"]
    
    private func describeFile(at url: URL) async throws -> String {
        let ext = url.pathExtension.lowercased()
        
        if imageExtensions.contains(ext) {
            // For images: gather metadata + OCR text
            var parts: [String] = []
            
            // File name & basic info
            parts.append("Original filename: \(url.lastPathComponent)")
            
            // EXIF / metadata
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                if let width = props[kCGImagePropertyPixelWidth as String],
                   let height = props[kCGImagePropertyPixelHeight as String] {
                    parts.append("Dimensions: \(width)×\(height)")
                }
                if let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    if let dateStr = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                        parts.append("Date taken: \(dateStr)")
                    }
                    if let model = exif["LensModel"] as? String {
                        parts.append("Lens: \(model)")
                    }
                }
                if let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
                   let cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String {
                    parts.append("Camera: \(cameraModel)")
                }
                if let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
                   let lat = gps[kCGImagePropertyGPSLatitude as String],
                   let lon = gps[kCGImagePropertyGPSLongitude as String] {
                    parts.append("GPS: \(lat), \(lon)")
                }
            }
            
            // Try OCR for visible text in the image
            do {
                let ocrText = try await LocalVisionService.extractText(from: url, accurate: false)
                let trimmed = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    parts.append("Text in image: \(String(trimmed.prefix(500)))")
                }
            } catch {
                // OCR failure is non-fatal
            }
            
            return parts.joined(separator: "\n")
        } else {
            // For text-based files: read content
            return try extractTextContent(from: url)
        }
    }
    
    private func executeSmartRename(context: ContextSnapshot, config: AIConfig, reporter: ProgressReporting) async throws {
        let service = try requireLLM(config: config)
        let total = Double(context.effectiveSelectionURLs.count)
        
        for (index, url) in context.effectiveSelectionURLs.enumerated() {
            reporter.updateProgress(
                fractionCompleted: Double(index) / total,
                message: L("AI 分析中: \(url.lastPathComponent)", "AI Analyzing: \(url.lastPathComponent)")
            )
            
            let description = try await describeFile(at: url)
            
            if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Skip files with no extractable content
                continue
            }
            
            let langInstruction = SharedLocale.isChinese ? "Please generate the filename in Chinese." : "Please generate the filename in English."
            let prompt = "Based on the following file information, suggest exactly one short, descriptive filename (without extension). \(langInstruction) Use concise human-readable naming, avoid generic names like 'empty' or 'untitled'. Do not output anything else:\n\n\(description)"
            
            var suggestedName = try await service.sendMessage(prompt: prompt, systemPrompt: "You are a file renamer tool. Output ONLY the suggested filename without markdown quotes, backticks, or explanation. Use concise, meaningful names.")
            
            // Clean up potentially noisy output
            suggestedName = suggestedName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "```", with: "")
                .replacingOccurrences(of: "`", with: "")
            
            // Reject garbage names
            let lower = suggestedName.lowercased()
            if suggestedName.isEmpty || lower == "empty" || lower == "untitled" || lower == "file" {
                continue
            }
            
            let currentExt = url.pathExtension
            var newName = suggestedName
            if !currentExt.isEmpty {
                newName += ".\(currentExt)"
            }
            
            let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            if !FileManager.default.fileExists(atPath: newURL.path) {
                try FileManager.default.moveItem(at: url, to: newURL)
            }
        }
        
        reporter.updateProgress(fractionCompleted: 1.0, message: L("重命名完成", "Rename complete"))
    }
    
    private func executeAutoTag(context: ContextSnapshot, config: AIConfig, reporter: ProgressReporting) async throws {
        let service = try requireLLM(config: config)
        let total = Double(context.effectiveSelectionURLs.count)
        
        var generatedTags = [String]()
        
        for (index, url) in context.effectiveSelectionURLs.enumerated() {
            reporter.updateProgress(
                fractionCompleted: Double(index) / total,
                message: L("分析文件中: \(url.lastPathComponent)", "Analyzing: \(url.lastPathComponent)")
            )
            
            let description = try await describeFile(at: url)
            if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            
            let langInstruction = SharedLocale.isChinese ? "You MUST output 1-2 words in Chinese (e.g. 财务, 合同, 艺术, 简历, 代码)." : "You MUST output 1-2 words in English."
            let prompt = "Analyze this file conceptually and reply with EXACTLY ONE categorical tag. \(langInstruction) No explanations, punctuation, or wrapping quotes.\n\nFile Info:\n\(description)"
            
            let tagString = try await service.sendMessage(prompt: prompt, systemPrompt: "You are a macOS file tag generator. Output ONLY a single short relevant tag string without any other text.")
            
            var tag = tagString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "```", with: "")
                .replacingOccurrences(of: ".", with: "")
            
            if !tag.isEmpty && tag.lowercased() != "empty" && tag.lowercased() != "none" {
                var urlResource = url
                var tags = try urlResource.resourceValues(forKeys: [URLResourceKey.tagNamesKey]).tagNames ?? []
                if !tags.contains(tag) {
                    tags.append(tag)
                    var rv = URLResourceValues()
                    rv.tagNames = tags
                    try urlResource.setResourceValues(rv)
                    generatedTags.append("\(url.lastPathComponent) -> \(tag)")
                }
            }
        }
        
        reporter.updateProgress(fractionCompleted: 1.0, message: L("标签设置完成", "Tagging complete"))
        
        if !generatedTags.isEmpty {
            let resultMessage = generatedTags.joined(separator: "\n")
            showResult(title: L("AI 标签生成结果", "AI Tag Generation Result"), content: resultMessage)
        }
    }
    
    private func showResult(title: String, content: String) {
        let uuid = UUID()
        let controller = AIResultWindowController(title: title, content: content)
        resultWindows[uuid] = controller
        
        // Let UI loop clean it up on close, or just leave it for now.
        // It's a lightweight tool app.
        controller.show()
    }
}
