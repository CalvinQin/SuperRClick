import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Shared
import UniformTypeIdentifiers

// Compiled together with the production PlatformActionExecutor. Only the Finder reveal is injected.
// Every file read/write in these checks is confined to the fresh directory supplied by the runner.
private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

private struct CheckResult: Codable {
    let name: String
    let status: String
    let detail: String
}

@MainActor
private final class CoreFileChecks {
    let root: URL
    let executor = PlatformActionExecutor(revealCreatedFile: { _ in })
    let fm = FileManager.default
    var results: [CheckResult] = []
    var archives: [[String: String]] = []

    init(root: URL) { self.root = root }

    func check(_ name: String, _ body: () async throws -> String) async {
        do {
            let detail = try await body()
            results.append(CheckResult(name: name, status: "PASS", detail: detail))
            print("PASS | \(name) | \(detail)")
        } catch {
            let detail = String(describing: error)
            results.append(CheckResult(name: name, status: "FAIL", detail: detail))
            print("FAIL | \(name) | \(detail)")
        }
    }

    func require(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !value() { throw CheckFailure(description: message) }
    }

    func directory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func file(_ directory: URL, _ name: String, _ contents: String = "Original payload — 保留内容\n") throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func context(_ urls: [URL], metadata: [String: String] = [:]) -> ActionContext {
        .finderSelection(urls.map { ActionItem(url: $0, isDirectory: $0.hasDirectoryPath) }, metadata: metadata)
    }

    func completed(_ result: ActionExecutionResult) throws {
        guard case .completed = result else { throw CheckFailure(description: "Expected completed, got \(result)") }
    }

    func blocked(_ result: ActionExecutionResult) throws {
        guard case .blocked = result else { throw CheckFailure(description: "Expected blocked, got \(result)") }
    }

    func failed(_ result: ActionExecutionResult) throws {
        guard case .failed = result else { throw CheckFailure(description: "Expected failed, got \(result)") }
    }

    func contents(_ directory: URL, extension ext: String) throws -> [URL] {
        try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == ext }
    }

    func makePNG(_ url: URL) throws {
        let pixels = [UInt8](repeating: 0xA0, count: 64 * 48 * 4)
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: 64, height: 48, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: 64 * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CheckFailure(description: "Unable to create PNG fixture")
        }
        CGImageDestinationAddImage(destination, image, nil)
        try require(CGImageDestinationFinalize(destination), "PNG fixture encoding failed")
    }

    func verifyImage(_ url: URL, type: UTType) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let actualType = CGImageSourceGetType(source),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CheckFailure(description: "Cannot decode image: \(url.path)")
        }
        try require(actualType as String == type.identifier, "Expected \(type.identifier), got \(actualType)")
        try require(image.width == 64 && image.height == 48, "Image dimensions changed")
    }

    func plan(_ urls: [URL], token: String, mode: BatchRenameMode = .prefix,
              numbering: BatchRenameNumberingOptions = .init()) -> BatchRenamePlan {
        BatchRenamePlanner().makePlan(items: urls.map { BatchRenameItemInput(url: $0, isDirectory: $0.hasDirectoryPath) },
                                      mode: mode, token: token, numbering: numbering)
    }

    func run() async throws {
        for template in NewFileCatalog.templates {
            await check("template-create-\(template.fileExtension)") {
                let dir = try directory("templates/\(template.fileExtension)")
                let result = await executor.execute(actionID: ActionID(rawValue: template.id), context: context([dir]))
                try completed(result)
                let target = dir.appendingPathComponent("Untitled.\(template.fileExtension)")
                let data = try Data(contentsOf: target)
                if let encoded = NewFileData.base64Templates[template.fileExtension] {
                    try require(data == Data(base64Encoded: encoded), "Template bytes changed during file creation")
                } else if template.fileExtension == "rtf" {
                    _ = try NSAttributedString(url: target, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
                } else {
                    try require(data.isEmpty, "Expected an empty plain-text template")
                }
                return "Created and read \(target.path); \(data.count) bytes"
            }
        }

        await check("template-repeat-does-not-overwrite") {
            let dir = try directory("template-repeat")
            let first = try file(dir, "Untitled.txt", "KEEP EXISTING")
            try completed(await executor.execute(actionID: "new-txt", context: context([dir])))
            try completed(await executor.execute(actionID: "new-txt", context: context([dir])))
            try require(try String(contentsOf: first, encoding: .utf8) == "KEEP EXISTING", "Existing file overwritten")
            try require(fm.fileExists(atPath: dir.appendingPathComponent("Untitled 1.txt").path), "Missing first numbered file")
            try require(fm.fileExists(atPath: dir.appendingPathComponent("Untitled 2.txt").path), "Missing second numbered file")
            return "Original bytes preserved; distinct Untitled 1.txt and Untitled 2.txt created"
        }
        await check("template-selected-file-uses-parent") {
            let dir = try directory("template-parent")
            let selected = try file(dir, "selected.txt")
            try completed(await executor.execute(actionID: "new-md", context: context([selected])))
            try require(fm.fileExists(atPath: dir.appendingPathComponent("Untitled.md").path), "File not created in selection parent")
            return "New Markdown file exists beside selected.txt"
        }
        await check("template-preserves-dangling-symlink") {
            let dir = try directory("template-symlink")
            let link = dir.appendingPathComponent("Untitled.txt")
            try fm.createSymbolicLink(atPath: link.path, withDestinationPath: "missing-target.txt")
            try completed(await executor.execute(actionID: "new-txt", context: context([dir])))
            try require(try fm.destinationOfSymbolicLink(atPath: link.path) == "missing-target.txt", "Existing symlink changed")
            try require(!fm.fileExists(atPath: dir.appendingPathComponent("missing-target.txt").path), "Symlink target was created")
            try require(fm.fileExists(atPath: dir.appendingPathComponent("Untitled 1.txt").path), "New file did not use a safe alternate name")
            return "Dangling symlink preserved; new file published at Untitled 1.txt"
        }
        await check("template-concurrent-independent-executors") {
            let dir = try directory("template-concurrent")
            let selection = context([dir])
            let responses = await withTaskGroup(of: ActionExecutionResult.self) { group in
                for _ in 0..<8 {
                    group.addTask {
                        let worker = PlatformActionExecutor(revealCreatedFile: { _ in })
                        return await worker.execute(actionID: "new-txt", context: selection)
                    }
                }
                var values: [ActionExecutionResult] = []
                for await value in group { values.append(value) }
                return values
            }
            for response in responses { try completed(response) }
            try require(try contents(dir, extension: "txt").count == 8, "Concurrent creation reused an existing output")
            return "Eight independent executors created eight distinct files concurrently"
        }
        await check("template-missing-directory-and-empty-selection") {
            try blocked(await executor.execute(actionID: "new-txt", context: context([])))
            let missing = root.appendingPathComponent("missing-parent", isDirectory: true)
            try failed(await executor.execute(actionID: "new-txt", context: context([missing])))
            return "Empty context blocked; missing destination failed without creating a different file"
        }

        for (format, ext, type) in [("jpeg", "jpg", UTType.jpeg), ("png", "png", .png), ("tiff", "tiff", .tiff), ("heic", "heic", .heic)] {
            await check("image-convert-\(format)") {
                let dir = try directory("image-\(format)")
                let source = dir.appendingPathComponent("input.png")
                try makePNG(source)
                let original = try Data(contentsOf: source)
                try completed(await executor.execute(actionID: BuiltInActionCatalog.convertImage.id,
                                                      context: context([source], metadata: ["convertImage.format": format])))
                let output = dir.appendingPathComponent(format == "png" ? "input-1.png" : "input.\(ext)")
                try verifyImage(output, type: type)
                try require(try Data(contentsOf: source) == original, "Source image changed")
                return "Decoded \(output.path), type=\(type.identifier), 64×48; source preserved"
            }
        }
        await check("image-repeat-and-existing-output") {
            let dir = try directory("image-repeat")
            let source = dir.appendingPathComponent("source.png")
            try makePNG(source)
            let existing = try file(dir, "source.jpg", "DO NOT REPLACE")
            for _ in 0..<2 {
                try completed(await executor.execute(actionID: BuiltInActionCatalog.convertImage.id,
                                                      context: context([source], metadata: ["convertImage.format": "jpeg"])))
            }
            try verifyImage(dir.appendingPathComponent("source-1.jpg"), type: .jpeg)
            try verifyImage(dir.appendingPathComponent("source-2.jpg"), type: .jpeg)
            try require(try String(contentsOf: existing, encoding: .utf8) == "DO NOT REPLACE", "Existing destination overwritten")
            return "Repeated conversions decoded and existing destination preserved"
        }
        await check("image-invalid-and-unsupported-input") {
            let dir = try directory("image-invalid")
            let corrupt = try file(dir, "broken.png", "not an image")
            try failed(await executor.execute(actionID: BuiltInActionCatalog.convertImage.id,
                                               context: context([corrupt], metadata: ["convertImage.format": "jpeg"])))
            try blocked(await executor.execute(actionID: BuiltInActionCatalog.convertImage.id,
                                                context: context([corrupt], metadata: ["convertImage.format": "webp"])))
            try blocked(await executor.execute(actionID: BuiltInActionCatalog.convertImage.id, context: context([])))
            try require(try contents(dir, extension: "jpg").isEmpty, "Failed conversion left an output image")
            return "Corrupt image failed, WebP export/empty input blocked, no output artifact"
        }
        await check("image-partial-failure-is-not-success") {
            let dir = try directory("image-partial")
            let source = dir.appendingPathComponent("good.png")
            try makePNG(source)
            let broken = try file(dir, "broken.png", "broken")
            let result = await executor.execute(actionID: BuiltInActionCatalog.convertImage.id,
                                                 context: context([source, broken], metadata: ["convertImage.format": "jpeg"]))
            try verifyImage(dir.appendingPathComponent("good.jpg"), type: .jpeg)
            try failed(result)
            return "Valid output decoded; mixed success/failure correctly reported: \(result)"
        }
        await check("image-failure-preserves-dangling-symlink") {
            let dir = try directory("image-symlink-failure")
            let source = try file(dir, "broken.png", "not an image")
            let link = dir.appendingPathComponent("broken.jpg")
            try fm.createSymbolicLink(atPath: link.path, withDestinationPath: "missing-target.jpg")
            try failed(await executor.execute(actionID: BuiltInActionCatalog.convertImage.id,
                                               context: context([source], metadata: ["convertImage.format": "jpeg"])))
            try require(try fm.destinationOfSymbolicLink(atPath: link.path) == "missing-target.jpg", "Failure deleted or changed pre-existing symlink")
            try require(!fm.fileExists(atPath: dir.appendingPathComponent("missing-target.jpg").path), "Failure created symlink target")
            try require(try fm.contentsOfDirectory(atPath: dir.path).sorted() == ["broken.jpg", "broken.png"], "Failure left staging/output artifacts")
            return "Corrupt conversion failed; dangling symlink survived and private staging was cleaned"
        }
        await check("image-success-preserves-dangling-symlink") {
            let dir = try directory("image-symlink-success")
            let source = dir.appendingPathComponent("input.png")
            try makePNG(source)
            let link = dir.appendingPathComponent("input.jpg")
            try fm.createSymbolicLink(atPath: link.path, withDestinationPath: "missing-target.jpg")
            try completed(await executor.execute(actionID: BuiltInActionCatalog.convertImage.id,
                                                  context: context([source], metadata: ["convertImage.format": "jpeg"])))
            try require(try fm.destinationOfSymbolicLink(atPath: link.path) == "missing-target.jpg", "Success changed pre-existing symlink")
            try require(!fm.fileExists(atPath: dir.appendingPathComponent("missing-target.jpg").path), "Success followed pre-existing symlink")
            try verifyImage(dir.appendingPathComponent("input-1.jpg"), type: .jpeg)
            return "Valid image published at input-1.jpg; symlink and its absent target left untouched"
        }
        await check("exclusive-publish-preserves-late-arrival") {
            let dir = try directory("publish-late-arrival")
            let preferred = dir.appendingPathComponent("result.txt")
            let output = try ExclusiveFileOutput(preferredURL: preferred)
            defer { output.cleanup() }
            try Data("GENERATED".utf8).write(to: output.temporaryURL)
            _ = try file(dir, "result.txt", "LATE ARRIVAL")
            let published = try output.publish()
            try require(published.lastPathComponent == "result-1.txt", "Publisher reused the occupied destination")
            try require(try String(contentsOf: preferred, encoding: .utf8) == "LATE ARRIVAL", "Publisher overwrote late arrival")
            try require(try String(contentsOf: published, encoding: .utf8) == "GENERATED", "Published contents changed")
            return "Destination created after staging was preserved atomically; generated output moved to result-1.txt"
        }
        await check("exclusive-publish-concurrent-payloads") {
            let dir = try directory("publish-concurrent")
            let preferred = dir.appendingPathComponent("result.txt")
            let published = try await withThrowingTaskGroup(of: URL.self) { group in
                for index in 0..<12 {
                    group.addTask {
                        try ExclusiveFileOutput.write(Data("PAYLOAD-\(index)".utf8), preferredURL: preferred)
                    }
                }
                var values: [URL] = []
                for try await value in group { values.append(value) }
                return values
            }
            try require(Set(published).count == 12, "Concurrent publishers reused output URLs")
            let payloads = try Set(published.map { try String(contentsOf: $0, encoding: .utf8) })
            try require(payloads == Set((0..<12).map { "PAYLOAD-\($0)" }), "Concurrent publish lost/overwrote a payload")
            try require(try fm.contentsOfDirectory(atPath: dir.path).count == 12, "Publishers left staging directories")
            return "Twelve concurrent publications preserve twelve distinct payloads; no staging directories remain"
        }
        await check("exclusive-publish-preserves-existing-directory") {
            let dir = try directory("publish-directory")
            let existing = dir.appendingPathComponent("result.txt", isDirectory: true)
            try fm.createDirectory(at: existing, withIntermediateDirectories: false)
            _ = try file(existing, "keep.txt", "KEEP")
            let published = try ExclusiveFileOutput.write(Data("GENERATED".utf8), preferredURL: dir.appendingPathComponent("result.txt"))
            try require(published.lastPathComponent == "result-1.txt", "Existing directory was not skipped")
            try require(try String(contentsOf: existing.appendingPathComponent("keep.txt"), encoding: .utf8) == "KEEP", "Existing directory contents changed")
            return "Existing destination directory and child preserved; separate file published"
        }

        await check("compress-files-with-spaces-and-unicode") {
            let dir = try directory("compress-files")
            let first = try file(dir, "hello world.txt")
            let second = try file(dir, "中文.txt", "Unicode content")
            try completed(await executor.execute(actionID: BuiltInActionCatalog.compressItems.id, context: context([first, second])))
            let outputs = try contents(dir, extension: "zip")
            try require(outputs.count == 1, "Expected one archive, found \(outputs.count)")
            archives.append(["archive": outputs[0].path, "sourceDirectory": dir.path,
                             "members": "hello world.txt\n中文.txt"])
            return "Created \(outputs[0].path); ZIP integrity and payloads independently checked by Python"
        }
        await check("compress-single-folder") {
            let dir = try directory("compress-folder")
            let folder = dir.appendingPathComponent("Folder with space", isDirectory: true)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            _ = try file(folder, "nested.txt")
            try completed(await executor.execute(actionID: BuiltInActionCatalog.compressItems.id, context: context([folder])))
            let outputs = try contents(dir, extension: "zip")
            try require(outputs.count == 1, "Archive should be created beside selected folder")
            archives.append(["archive": outputs[0].path, "sourceDirectory": dir.path,
                             "members": "Folder with space/nested.txt"])
            return "Archive beside folder; nested payload will be validated"
        }
        await check("compress-file-and-folder-same-parent") {
            let dir = try directory("compress-mixed")
            let folder = dir.appendingPathComponent("Directory", isDirectory: true)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            _ = try file(folder, "inside.txt")
            let source = try file(dir, "outside.txt")
            try completed(await executor.execute(actionID: BuiltInActionCatalog.compressItems.id, context: context([source, folder])))
            let outputs = try contents(dir, extension: "zip")
            try require(outputs.count == 1, "Expected one mixed-selection archive")
            archives.append(["archive": outputs[0].path, "sourceDirectory": dir.path,
                             "members": "outside.txt\nDirectory/inside.txt"])
            return "Same-parent file and folder archived together"
        }
        await check("compress-leading-hyphen-filename") {
            let dir = try directory("compress-hyphen")
            let source = try file(dir, "-payload.txt")
            try completed(await executor.execute(actionID: BuiltInActionCatalog.compressItems.id, context: context([source])))
            let outputs = try contents(dir, extension: "zip")
            try require(outputs.count == 1, "Expected archive for leading-hyphen filename")
            archives.append(["archive": outputs[0].path, "sourceDirectory": dir.path, "members": "-payload.txt"])
            return "Leading-hyphen filename handled as an input path"
        }
        await check("compress-repeat-keeps-both-results") {
            let dir = try directory("compress-repeat")
            let source = try file(dir, "first.txt")
            try completed(await executor.execute(actionID: BuiltInActionCatalog.compressItems.id, context: context([source])))
            try completed(await executor.execute(actionID: BuiltInActionCatalog.compressItems.id, context: context([source])))
            let outputs = try contents(dir, extension: "zip")
            try require(outputs.count == 2, "Repeated action produced only \(outputs.count) archive(s), so prior output was reused")
            for output in outputs { archives.append(["archive": output.path, "sourceDirectory": dir.path, "members": "first.txt"]) }
            return "Two independent archives preserved after immediate repeated execution"
        }
        await check("compress-literal-wildcard-filename") {
            let dir = try directory("compress-wildcard")
            let source = try file(dir, "part[1].txt", "LITERAL")
            _ = try file(dir, "part1.txt", "NOT SELECTED")
            try completed(await executor.execute(actionID: BuiltInActionCatalog.compressItems.id, context: context([source])))
            let outputs = try contents(dir, extension: "zip")
            try require(outputs.count == 1, "Expected one archive")
            archives.append(["archive": outputs[0].path, "sourceDirectory": dir.path, "members": "part[1].txt"])
            return "Literal brackets preserved; archive membership excludes unselected matching filename"
        }
        await check("compress-empty-and-cross-directory") {
            try blocked(await executor.execute(actionID: BuiltInActionCatalog.compressItems.id, context: context([])))
            let first = try file(directory("compress-cross-a"), "first.txt")
            let second = try file(directory("compress-cross-b"), "second.txt")
            try blocked(await executor.execute(actionID: BuiltInActionCatalog.compressItems.id, context: context([first, second])))
            return "Empty selection and items from different parents blocked"
        }
        await check("compress-missing-input-no-partial-artifact") {
            let dir = try directory("compress-missing")
            let source = try file(dir, "present.txt")
            let missing = dir.appendingPathComponent("missing.txt")
            let result = await executor.execute(actionID: BuiltInActionCatalog.compressItems.id, context: context([source, missing]))
            try failed(result)
            try require(try contents(dir, extension: "zip").isEmpty, "Failed compression left a partial archive")
            return "Missing input reported as failure with no partial archive"
        }
        await check("compress-disappearing-input-cleans-partial-archive") {
            let dir = try directory("compress-disappearing")
            let source = try file(dir, "first.txt")
            let disappearing = try file(dir, "second.txt")
            let result = await executor.execute(actionID: BuiltInActionCatalog.compressItems.id,
                                                 context: context([source, disappearing])) { completed, _, _ in
                if completed == 0 { try? FileManager.default.removeItem(at: disappearing) }
            }
            try failed(result)
            try require(try contents(dir, extension: "zip").isEmpty, "zip failure left a partial archive")
            try require(fm.fileExists(atPath: source.path), "Remaining input changed")
            return "Input removed after planning; zip fails and its incomplete archive is removed"
        }

        await check("rename-prefix-numbering-files-and-folder") {
            let dir = try directory("rename-prefix")
            let first = try file(dir, "alpha.txt", "alpha bytes")
            let folder = dir.appendingPathComponent("folder.v1", isDirectory: true)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            _ = try file(folder, "child.txt", "child bytes")
            let renamePlan = plan([first, folder], token: "IMG", numbering: .init(isEnabled: true, start: 1, step: 2, padding: 3))
            try require(renamePlan.canApply, renamePlan.summary)
            try completed(await executor.applyBatchRename(plan: renamePlan))
            try require(try String(contentsOf: dir.appendingPathComponent("IMG-001-alpha.txt"), encoding: .utf8) == "alpha bytes", "Renamed file payload changed")
            try require(try String(contentsOf: dir.appendingPathComponent("IMG-003-folder.v1/child.txt"), encoding: .utf8) == "child bytes", "Renamed directory payload changed")
            try require(!fm.fileExists(atPath: first.path) && !fm.fileExists(atPath: folder.path), "Old names still exist")
            return "File and folder moved to planned names; nested contents and extension preserved"
        }
        await check("rename-suffix-and-unchanged") {
            let dir = try directory("rename-suffix")
            let source = try file(dir, "README")
            try completed(await executor.applyBatchRename(plan: plan([source], token: "final", mode: .suffix)))
            let renamed = dir.appendingPathComponent("README-final")
            let before = try Data(contentsOf: renamed)
            let unchanged = plan([renamed], token: "")
            try require(unchanged.previews.first?.status == .unchanged, "Unchanged name not recognized")
            try completed(await executor.applyBatchRename(plan: unchanged))
            try require(try Data(contentsOf: renamed) == before, "Unchanged operation modified file")
            return "Extensionless suffix rename executed; unchanged follow-up preserves bytes"
        }
        await check("rename-existing-and-duplicate-conflicts") {
            let dir = try directory("rename-conflicts")
            let source = try file(dir, "file.txt", "ORIGINAL")
            let existing = try file(dir, "prefix-file.txt", "EXISTING")
            let collision = plan([source], token: "prefix")
            try require(collision.hasConflicts, "Existing file conflict missed")
            try blocked(await executor.applyBatchRename(plan: collision))
            try require(try String(contentsOf: source, encoding: .utf8) == "ORIGINAL", "Source changed despite conflict")
            try require(try String(contentsOf: existing, encoding: .utf8) == "EXISTING", "Existing file overwritten")
            let other = try file(dir, "file.md", "OTHER")
            let duplicate = BatchRenamePlanner().makePlan(items: [source, other].map { .init(url: $0) }, mode: .prefix,
                                                         token: "", preserveFileExtension: false)
            try require(duplicate.hasConflicts, "Duplicate proposed names were not detected")
            try blocked(await executor.applyBatchRename(plan: duplicate))
            return "Existing-file and duplicate-name conflicts block all mutation"
        }
        await check("rename-late-failure-restores-earlier-files") {
            let dir = try directory("rename-rollback")
            let first = try file(dir, "first.txt", "FIRST")
            let second = try file(dir, "second.txt", "SECOND")
            let renamePlan = plan([first, second], token: "renamed")
            try require(renamePlan.canApply, "Setup plan unexpectedly conflicted")
            try fm.removeItem(at: second)
            let result = await executor.applyBatchRename(plan: renamePlan)
            try failed(result)
            try require(fm.fileExists(atPath: first.path), "Earlier file remains renamed after later failure; rollback missing")
            try require(try String(contentsOf: first, encoding: .utf8) == "FIRST", "Rollback failed to preserve original bytes")
            try require(!fm.fileExists(atPath: dir.appendingPathComponent("renamed-first.txt").path), "Renamed first file remains")
            return "Later missing input returned failure; earlier file and original bytes restored"
        }
        await check("rename-path-component-input-blocked") {
            let dir = try directory("rename-path/inner")
            let source = try file(dir, "file.txt", "SAFE")
            let invalidPlan = plan([source], token: "../escaped")
            let result = await executor.applyBatchRename(plan: invalidPlan)
            try blocked(result)
            try require(try String(contentsOf: source, encoding: .utf8) == "SAFE", "Path-like input moved source")
            return "Path separators rejected without moving source outside its parent"
        }
        await check("rename-conflict-created-mid-batch-rolls-back") {
            let dir = try directory("rename-mid-batch")
            let first = try file(dir, "first.txt", "FIRST")
            let second = try file(dir, "second.txt", "SECOND")
            let renamePlan = plan([first, second], token: "renamed")
            let lateConflict = dir.appendingPathComponent("renamed-second.txt")
            let result = await executor.applyBatchRename(plan: renamePlan) { completed, _, _ in
                if completed == 1 { try? Data("LATE ARRIVAL".utf8).write(to: lateConflict, options: .withoutOverwriting) }
            }
            try failed(result)
            try require(try String(contentsOf: first, encoding: .utf8) == "FIRST", "Already-renamed file was not restored")
            try require(try String(contentsOf: second, encoding: .utf8) == "SECOND", "Second source was changed")
            try require(try String(contentsOf: lateConflict, encoding: .utf8) == "LATE ARRIVAL", "Late destination overwritten")
            return "Destination appeared after first rename; first source restored, both original payloads and late arrival preserved"
        }
        await check("rename-rollback-conflict-reports-retained-file") {
            let dir = try directory("rename-rollback-conflict")
            let first = try file(dir, "first.txt", "FIRST")
            let second = try file(dir, "second.txt", "SECOND")
            let renamePlan = plan([first, second], token: "renamed")
            let lateConflict = dir.appendingPathComponent("renamed-second.txt")
            let retained = dir.appendingPathComponent("renamed-first.txt")
            let result = await executor.applyBatchRename(plan: renamePlan) { completed, _, _ in
                if completed == 1 {
                    try? Data("NEW SOURCE".utf8).write(to: first, options: .withoutOverwriting)
                    try? Data("LATE DESTINATION".utf8).write(to: lateConflict, options: .withoutOverwriting)
                }
            }
            guard case let .failed(reason, _) = result else { throw CheckFailure(description: "Expected rollback failure, got \(result)") }
            try require(reason.contains(retained.path), "Failure omitted the retained file location")
            try require(try String(contentsOf: retained, encoding: .utf8) == "FIRST", "Original file was lost during rollback conflict")
            try require(try String(contentsOf: first, encoding: .utf8) == "NEW SOURCE", "New file at original path was overwritten")
            try require(try String(contentsOf: second, encoding: .utf8) == "SECOND", "Second original changed")
            return "Rollback collision preserves original at reported renamed path and leaves newly created files intact"
        }
        await check("rename-empty-selection") {
            try blocked(await executor.applyBatchRename(plan: plan([], token: "prefix")))
            return "Empty batch rejected"
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(results).write(to: root.appendingPathComponent("swift-results.json"))
        try encoder.encode(archives).write(to: root.appendingPathComponent("archive-expectations.json"))
        print("Artifacts retained at \(root.path)")
    }
}

@main
struct CoreFileActionChecks {
    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass a fresh /tmp/superrclick-functional-core-* directory") }
        let url = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).standardizedFileURL
        guard url.path.hasPrefix("/tmp/superrclick-functional-core-") || url.path.hasPrefix("/private/tmp/superrclick-functional-core-") else {
            fatalError("Fixtures must be confined to /tmp/superrclick-functional-core-*")
        }
        try await CoreFileChecks(root: url).run()
    }
}
