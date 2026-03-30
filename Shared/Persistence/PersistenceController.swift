import Foundation

public final class PersistenceController {
    private let storageDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    public init(storageDirectory: URL, fileManager: FileManager = .default) {
        self.storageDirectory = storageDirectory
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .millisecondsSince1970
        self.decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    public var stateFileURL: URL {
        storageDirectory.appendingPathComponent("super-rclick-state.json")
    }

    public func loadState() throws -> PersistenceState {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            return PersistenceState()
        }

        let data = try Data(contentsOf: stateFileURL)
        return try decoder.decode(PersistenceState.self, from: data)
    }

    public func loadOrCreateState() -> PersistenceState {
        (try? loadState()) ?? PersistenceState()
    }

    public func saveState(_ state: PersistenceState) throws {
        lock.lock()
        defer { lock.unlock() }

        try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true, attributes: nil)
        let data = try encoder.encode(state)
        try data.write(to: stateFileURL, options: .atomic)
    }

    public func updateVisibilityRules(_ rules: [VisibilityRule]) throws {
        var state = loadOrCreateState()
        state.visibilityRules = rules
        try saveState(state)
    }

    public func updatePinnedActions(_ pinnedActions: [PinnedAction]) throws {
        var state = loadOrCreateState()
        state.pinnedActions = pinnedActions
        try saveState(state)
    }

    public func updateWorkspaceProfiles(_ profiles: [WorkspaceProfile]) throws {
        var state = loadOrCreateState()
        state.workspaceProfiles = profiles
        try saveState(state)
    }

    public func updateMonitoredFolders(_ folders: [MonitoredFolder]) throws {
        var state = loadOrCreateState()
        state.monitoredFolders = folders
        try saveState(state)
    }

    public func appendInvocation(_ invocation: ActionInvocationRecord, maxHistoryCount: Int = 500) throws {
        var state = loadOrCreateState()
        state.actionHistory.insert(invocation, at: 0)
        if state.actionHistory.count > maxHistoryCount {
            state.actionHistory = Array(state.actionHistory.prefix(maxHistoryCount))
        }
        try saveState(state)
    }
}
