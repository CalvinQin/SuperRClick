import Foundation

/// Semantic precedence, deliberately independent of Foundation's natural-string ordering.
public struct ReleaseVersion: Equatable, Comparable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: [String]

    public init?(_ value: String) {
        let text = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let metadata = text.split(separator: "+", omittingEmptySubsequences: false)
        guard metadata.count <= 2 else { return nil }
        func validIdentifiers(_ text: Substring) -> Bool {
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            return parts.allSatisfy { !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 } }
        }
        if metadata.count == 2, !validIdentifiers(metadata[1]) { return nil }
        let halves = metadata[0].split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = halves[0].split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3 else { return nil }
        var core: [Int] = []
        for n in numbers {
            guard !n.isEmpty, n.utf8.allSatisfy({ (48...57).contains($0) }), (n.count == 1 || n.first != "0"), let number = Int(n) else { return nil }
            core.append(number)
        }
        var identifiers: [String] = []
        if halves.count == 2 {
            guard validIdentifiers(halves[1]) else { return nil }
            identifiers = halves[1].split(separator: ".").map(String.init)
            for identifier in identifiers where identifier.utf8.allSatisfy({ (48...57).contains($0) }) {
                guard identifier.count == 1 || identifier.first != "0" else { return nil }
            }
        }
        major = core[0]; minor = core[1]; patch = core[2]; prerelease = identifiers
    }

    public var isPreview: Bool { !prerelease.isEmpty }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        for (a, b) in zip([lhs.major, lhs.minor, lhs.patch], [rhs.major, rhs.minor, rhs.patch]) {
            if a != b { return a < b }
        }
        if lhs.prerelease.isEmpty || rhs.prerelease.isEmpty {
            return !lhs.prerelease.isEmpty && rhs.prerelease.isEmpty
        }
        for (a, b) in zip(lhs.prerelease, rhs.prerelease) where a != b {
            let an = a.utf8.allSatisfy { (48...57).contains($0) }
            let bn = b.utf8.allSatisfy { (48...57).contains($0) }
            if an && bn { return a.count == b.count ? a < b : a.count < b.count }
            if an != bn { return an }
            return a < b
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }
}

public enum UpdatePolicy {
    /// Stable installs never silently opt into previews. Preview installs can graduate to stable.
    public static func allows(_ candidate: ReleaseVersion, flaggedPreview: Bool, current: ReleaseVersion) -> Bool {
        current.isPreview || (!candidate.isPreview && !flaggedPreview)
    }

    public static func isNewer(_ candidate: ReleaseVersion, build: Int?, than current: ReleaseVersion, currentBuild: Int) -> Bool {
        if candidate != current { return candidate > current }
        return build.map { $0 > currentBuild } ?? false
    }

    public static func installedVersion(explicit: String?, marketing: String, build: Int) -> ReleaseVersion? {
        if let explicit { return ReleaseVersion(explicit) }
        // These shipped preview builds predate explicit release-channel metadata.
        if marketing == "0.3.0", build == 4 { return ReleaseVersion("0.3.0-beta.1") }
        if marketing == "0.3.0", build == 5 { return ReleaseVersion("0.3.0-beta.2") }
        return ReleaseVersion(marketing)
    }
}
