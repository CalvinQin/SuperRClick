import Foundation

public struct BatchRenamePlanner: Sendable {
    public var fileExistsAtPath: @Sendable (String) -> Bool

    public init(
        fileExistsAtPath: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) {
        self.fileExistsAtPath = fileExistsAtPath
    }

    public func makePlan(for request: BatchRenameRequest) -> BatchRenamePlan {
        guard !request.items.isEmpty else {
            return BatchRenamePlan(
                request: request,
                previews: [],
                conflicts: [
                    BatchRenameConflict(
                        kind: .noSelection,
                        message: L("请至少选择一个文件或文件夹以重命名。", "Select at least one file or folder to rename.")
                    )
                ]
            )
        }

        let plannedItems = request.items.enumerated().map { offset, item in
            makePreviewItem(for: item, request: request, index: offset)
        }

        let validPlannedItems = plannedItems.filter { $0.status != .invalidName }
        let duplicateCounts = Dictionary(grouping: validPlannedItems, by: { $0.proposedURL.path })
            .mapValues(\.count)

        var conflicts: [BatchRenameConflict] = []
        var finalPreviews: [BatchRenamePreviewItem] = []

        for preview in plannedItems {
            var status = preview.status

            if status == .invalidName {
                conflicts.append(
                    BatchRenameConflict(
                        kind: .invalidName,
                        sourceURL: preview.sourceURL,
                        proposedURL: preview.proposedURL,
                        message: L("建议的新名称为空。", "The proposed name is empty after trimming whitespace.")
                    )
                )
            } else if let count = duplicateCounts[preview.proposedURL.path], count > 1 {
                status = .duplicateProposedName
                conflicts.append(
                    BatchRenameConflict(
                        kind: .duplicateProposedName,
                        sourceURL: preview.sourceURL,
                        proposedURL: preview.proposedURL,
                        message: L("新名称与此批次中的另一个项目冲突。", "Proposed name collides with another item in this batch.")
                    )
                )
            }

            if status != .invalidName, preview.proposedURL.path != preview.sourceURL.path, fileExistsAtPath(preview.proposedURL.path) {
                status = .existingFileOnDisk
                conflicts.append(
                    BatchRenameConflict(
                        kind: .existingFileOnDisk,
                        sourceURL: preview.sourceURL,
                        proposedURL: preview.proposedURL,
                        message: L("具有此名称的文件或文件夹已存在。", "A file or folder with this name already exists.")
                    )
                )
            }

            finalPreviews.append(
                BatchRenamePreviewItem(
                    sourceURL: preview.sourceURL,
                    sourceName: preview.sourceName,
                    proposedURL: preview.proposedURL,
                    proposedName: preview.proposedName,
                    sequenceValue: preview.sequenceValue,
                    status: status
                )
            )
        }

        return BatchRenamePlan(
            request: request,
            previews: finalPreviews,
            conflicts: conflicts
        )
    }

    public func makePlan(
        items: [BatchRenameItemInput],
        mode: BatchRenameMode,
        token: String,
        numbering: BatchRenameNumberingOptions = BatchRenameNumberingOptions(),
        preserveFileExtension: Bool = true
    ) -> BatchRenamePlan {
        makePlan(
            for: BatchRenameRequest(
                mode: mode,
                token: token,
                numbering: numbering,
                items: items,
                preserveFileExtension: preserveFileExtension
            )
        )
    }

    private func makePreviewItem(
        for item: BatchRenameItemInput,
        request: BatchRenameRequest,
        index: Int
    ) -> BatchRenamePreviewItem {
        let originalName = displayName(for: item)
        let components = nameComponents(for: item)
        let sequenceValue = request.numbering.formattedValue(for: index)
        let proposedStem = buildProposedStem(
            originalStem: components.stem,
            token: request.token,
            sequenceValue: sequenceValue,
            mode: request.mode,
            separator: request.numbering.separator
        )

        let proposedName = makeProposedName(
            stem: proposedStem,
            fileExtension: request.preserveFileExtension ? components.fileExtension : nil,
            isDirectory: item.isDirectory
        )
        let proposedURL = proposedURL(for: item.url, proposedName: proposedName)

        let status: BatchRenamePreviewStatus
        if proposedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = .invalidName
        } else if proposedURL.path == item.url.path {
            status = .unchanged
        } else {
            status = .ready
        }

        return BatchRenamePreviewItem(
            sourceURL: item.url,
            sourceName: originalName,
            proposedURL: proposedURL,
            proposedName: proposedName,
            sequenceValue: sequenceValue.isEmpty ? nil : sequenceValue,
            status: status
        )
    }

    private func buildProposedStem(
        originalStem: String,
        token: String,
        sequenceValue: String,
        mode: BatchRenameMode,
        separator: String
    ) -> String {
        let fragments: [String]

        switch mode {
        case .prefix:
            fragments = [token, sequenceValue, originalStem]
        case .suffix:
            fragments = [originalStem, token, sequenceValue]
        }

        let nonEmptyFragments = fragments.filter { !$0.isEmpty }
        guard !nonEmptyFragments.isEmpty else {
            return ""
        }

        return nonEmptyFragments.joined(separator: separator)
    }

    private func makeProposedName(
        stem: String,
        fileExtension: String?,
        isDirectory: Bool
    ) -> String {
        guard !stem.isEmpty else { return "" }

        if isDirectory || fileExtension == nil || fileExtension?.isEmpty == true {
            return stem
        }

        return "\(stem).\(fileExtension!)"
    }

    private func proposedURL(for originalURL: URL, proposedName: String) -> URL {
        originalURL.deletingLastPathComponent().appendingPathComponent(proposedName)
    }

    private func nameComponents(for item: BatchRenameItemInput) -> (stem: String, fileExtension: String?) {
        let lastPathComponent = item.url.lastPathComponent

        if item.isDirectory {
            return (stem: lastPathComponent, fileExtension: nil)
        }

        let fileExtension = item.url.pathExtension
        guard !fileExtension.isEmpty else {
            return (stem: lastPathComponent, fileExtension: nil)
        }

        let stem = item.url.deletingPathExtension().lastPathComponent
        return (stem: stem, fileExtension: fileExtension)
    }

    private func displayName(for item: BatchRenameItemInput) -> String {
        item.displayName ?? item.url.lastPathComponent
    }
}
