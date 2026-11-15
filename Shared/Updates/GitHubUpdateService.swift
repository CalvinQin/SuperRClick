import Foundation

public struct UpdateRelease: Decodable, Sendable {
    public struct Asset: Decodable, Sendable {
        public let name: String
        public let browser_download_url: String
    }
    public let tag_name: String
    public let html_url: String
    public let name: String?
    public let body: String?
    public let draft: Bool
    public let prerelease: Bool
    public let assets: [Asset]
}

public enum UpdateCheckError: LocalizedError {
    case http(Int), invalidResponse, invalidManifest, tooManyPages, invalidInstalledVersion
    public var errorDescription: String? {
        switch self {
        case .http(let status): return "GitHub returned HTTP \(status). Please try again later."
        case .invalidResponse: return "GitHub returned an invalid update response."
        case .invalidManifest: return "The release update metadata could not be verified."
        case .tooManyPages: return "The release list is too large to check completely."
        case .invalidInstalledVersion: return "This application's release version is invalid."
        }
    }
}

public struct GitHubUpdateService: Sendable {
    public typealias Fetch = @Sendable (URL) async throws -> (Data, Int)
    private let fetch: Fetch
    public init(fetch: @escaping Fetch = { url in
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw UpdateCheckError.invalidResponse }
        return (data, response.statusCode)
    }) { self.fetch = fetch }

    private func load(_ url: URL) async throws -> Data {
        let (data, status) = try await fetch(url)
        guard status == 200 else { throw UpdateCheckError.http(status) }
        return data
    }

    public func newestUpdate(current: ReleaseVersion, currentBuild: Int) async throws -> UpdateRelease? {
        var releases: [UpdateRelease] = []
        for page in 1...10 {
            let url = URL(string: "https://api.github.com/repos/CalvinQin/SuperRClick/releases?per_page=100&page=\(page)")!
            let data = try await load(url)
            let batch = try JSONDecoder().decode([UpdateRelease].self, from: data)
            releases += batch
            if batch.count < 100 { break }
            if page == 10 { throw UpdateCheckError.tooManyPages }
        }
        var best: (release: UpdateRelease, version: ReleaseVersion, build: Int)?
        for release in releases {
            guard !release.draft,
                  let version = ReleaseVersion(release.tag_name),
                  version >= current,
                  UpdatePolicy.allows(version, flaggedPreview: release.prerelease, current: current),
                  let page = URL(string: release.html_url), page.scheme == "https", page.host == "github.com",
                  page.path.hasPrefix("/CalvinQin/SuperRClick/releases/tag/") else { continue }
            var build: Int?
            if let asset = release.assets.first(where: { $0.name == "SuperRClick-update.json" }) {
                guard let url = URL(string: asset.browser_download_url), url.scheme == "https", url.host == "github.com",
                      url.path.hasPrefix("/CalvinQin/SuperRClick/releases/download/"), url.lastPathComponent == "SuperRClick-update.json" else { throw UpdateCheckError.invalidManifest }
                struct Manifest: Decodable { let schema: Int; let version: String; let build: Int }
                let manifest = try JSONDecoder().decode(Manifest.self, from: await load(url))
                guard manifest.schema == 1, manifest.build > 0,
                      ReleaseVersion(manifest.version) == version else { throw UpdateCheckError.invalidManifest }
                build = manifest.build
            }
            guard UpdatePolicy.isNewer(version, build: build, than: current, currentBuild: currentBuild) else { continue }
            if best == nil || version > best!.version || (version == best!.version && (build ?? 0) > best!.build) {
                best = (release, version, build ?? 0)
            }
        }
        return best?.release
    }
}
