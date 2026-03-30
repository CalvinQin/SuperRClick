import Darwin
import Foundation

public enum RealUserDirectories {
    public static func homeDirectory(fileManager: FileManager = .default) -> URL {
        if let passwdEntry = getpwuid(getuid()) {
            return URL(fileURLWithPath: String(cString: passwdEntry.pointee.pw_dir), isDirectory: true)
                .standardizedFileURL
        }

        return fileManager.homeDirectoryForCurrentUser.standardizedFileURL
    }

    public static func desktop(fileManager: FileManager = .default) -> URL {
        homeDirectory(fileManager: fileManager).appendingPathComponent("Desktop", isDirectory: true)
    }

    public static func documents(fileManager: FileManager = .default) -> URL {
        homeDirectory(fileManager: fileManager).appendingPathComponent("Documents", isDirectory: true)
    }

    public static func downloads(fileManager: FileManager = .default) -> URL {
        homeDirectory(fileManager: fileManager).appendingPathComponent("Downloads", isDirectory: true)
    }

    public static func knownRoots(fileManager: FileManager = .default) -> [MonitoredFolderPreset: URL] {
        [
            .desktop: desktop(fileManager: fileManager),
            .documents: documents(fileManager: fileManager),
            .downloads: downloads(fileManager: fileManager)
        ]
    }

    public static func url(for preset: MonitoredFolderPreset, fileManager: FileManager = .default) -> URL? {
        knownRoots(fileManager: fileManager)[preset]
    }

    public static func migrateSandboxedURLIfNeeded(_ url: URL, fileManager: FileManager = .default) -> URL {
        let normalizedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let normalizedPath = normalizedURL.path(percentEncoded: false)

        guard normalizedPath.contains("/Library/Containers/"),
              normalizedPath.contains("/Data/") else {
            return normalizedURL
        }

        for (_, realURL) in knownRoots(fileManager: fileManager) {
            let suffix = "/Data/\(realURL.lastPathComponent)"
            if normalizedPath.hasSuffix(suffix) || normalizedPath.hasSuffix(suffix + "/") {
                return realURL.standardizedFileURL
            }
        }

        return normalizedURL
    }
}
