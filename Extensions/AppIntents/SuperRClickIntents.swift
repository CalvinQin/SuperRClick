import AppIntents

public struct OpenSuperRClickControlCenterIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Super RClick"
    public static let description = IntentDescription("Open the Super RClick control center.")
    public static let openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        .result()
    }
}

public struct RunSuperRClickPlaceholderActionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Run Placeholder Action"
    public static let description = IntentDescription("Reserved for future Finder and text actions.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        .result()
    }
}

public enum SuperRClickIntentCatalog {
    public static let all: [any AppIntent.Type] = [
        OpenSuperRClickControlCenterIntent.self,
        RunSuperRClickPlaceholderActionIntent.self,
    ]
}
