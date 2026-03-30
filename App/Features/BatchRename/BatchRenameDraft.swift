import Foundation
import Shared

public struct BatchRenameDraft: Codable, Hashable, Sendable {
    public var mode: BatchRenameMode
    public var token: String
    public var numbering: BatchRenameNumberingOptions
    public var preserveFileExtension: Bool
    public var items: [BatchRenameItemInput]

    public init(
        mode: BatchRenameMode = .prefix,
        token: String = "",
        numbering: BatchRenameNumberingOptions = BatchRenameNumberingOptions(),
        preserveFileExtension: Bool = true,
        items: [BatchRenameItemInput] = []
    ) {
        self.mode = mode
        self.token = token
        self.numbering = numbering
        self.preserveFileExtension = preserveFileExtension
        self.items = items
    }

    public init(context: ActionContext) {
        self.init(
            items: context.items.map(BatchRenameItemInput.init)
        )
    }

    public var request: BatchRenameRequest {
        BatchRenameRequest(
            mode: mode,
            token: token,
            numbering: numbering,
            items: items,
            preserveFileExtension: preserveFileExtension
        )
    }

    public var isEmpty: Bool {
        items.isEmpty
    }
}
