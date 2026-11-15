import XCTest
@testable import Shared

final class GitHubUpdateServiceTests: XCTestCase {
    func payload(_ tag: String, preview: Bool = false, draft: Bool = false, manifest: Bool = false) -> String {
        """
        {"tag_name":"\(tag)","html_url":"https://github.com/CalvinQin/SuperRClick/releases/tag/\(tag)","name":"\(tag)","body":"notes","draft":\(draft),"prerelease":\(preview),"assets":\(manifest ? "[{\"name\":\"SuperRClick-update.json\",\"browser_download_url\":\"https://github.com/CalvinQin/SuperRClick/releases/download/\(tag)/SuperRClick-update.json\"}]" : "[]")}
        """
    }
    func testPreviewSeesNewestSemanticVersionNotResponseOrder() async throws {
        let data = Data("[\(payload("v0.3.0-beta.2")),\(payload("v0.3.0-beta.10", preview: true)),\(payload("v0.3.0-beta.3", preview: true))]".utf8)
        let service = GitHubUpdateService { _ in (data, 200) }
        let result = try await service.newestUpdate(current: ReleaseVersion("0.3.0-beta.3")!, currentBuild: 6)
        XCTAssertEqual(result?.tag_name, "v0.3.0-beta.10")
    }
    func testStableIgnoresPreviewEvenWhenFlagIncorrect() async throws {
        let data = Data("[\(payload("v0.4.0-beta.1")),\(payload("v0.4.0", preview: true)),\(payload("v0.3.1")),\(payload("v0.5.0", draft: true))]".utf8)
        let service = GitHubUpdateService { _ in (data, 200) }
        let result = try await service.newestUpdate(current: ReleaseVersion("0.3.0")!, currentBuild: 6)
        XCTAssertEqual(result?.tag_name, "v0.3.1")
    }
    func testSameVersionHigherManifestBuild() async throws {
        let data = Data("[\(payload("v0.3.0-beta.3", preview: true, manifest: true))]".utf8)
        let service = GitHubUpdateService { url in
            url.lastPathComponent == "SuperRClick-update.json" ? (Data("{\"schema\":1,\"version\":\"0.3.0-beta.3\",\"build\":7}".utf8), 200) : (data, 200)
        }
        let result = try await service.newestUpdate(current: ReleaseVersion("0.3.0-beta.3")!, currentBuild: 6)
        XCTAssertNotNil(result)
    }
    func testSameBuildAndOlderVersionsDoNotUpdate() async throws {
        let data = Data("[\(payload("v0.3.0-beta.2")),\(payload("v0.3.0-beta.3", preview: true, manifest: true))]".utf8)
        let service = GitHubUpdateService { url in
            url.lastPathComponent == "SuperRClick-update.json" ? (Data("{\"schema\":1,\"version\":\"0.3.0-beta.3\",\"build\":6}".utf8), 200) : (data, 200)
        }
        let result = try await service.newestUpdate(current: ReleaseVersion("0.3.0-beta.3")!, currentBuild: 6)
        XCTAssertNil(result)
    }
    func testHTTPFailuresAreErrorsNotUpToDate() async {
        for status in [403, 404, 429, 500] {
            let service = GitHubUpdateService { _ in (Data(), status) }
            do { _ = try await service.newestUpdate(current: ReleaseVersion("0.2.1")!, currentBuild: 3); XCTFail("HTTP \(status) accepted") }
            catch { XCTAssertTrue(error is UpdateCheckError) }
        }
    }
    func testMalformedJSONAndManifestFail() async {
        let data = Data("[\(payload("v0.3.0-beta.3", preview: true, manifest: true))]".utf8)
        for bad in [true, false] {
            let service = GitHubUpdateService { url in
                if bad { return (Data("not JSON".utf8), 200) }
                return url.lastPathComponent == "SuperRClick-update.json" ? (Data("{\"schema\":1,\"version\":\"9.0.0\",\"build\":7}".utf8), 200) : (data, 200)
            }
            do { _ = try await service.newestUpdate(current: ReleaseVersion("0.3.0-beta.3")!, currentBuild: 6); XCTFail("Invalid data accepted") }
            catch { }
        }
    }
    func testPaginationFindsUpdateOnLaterPage() async throws {
        let page1 = Data("[\(Array(repeating: payload("v0.1.0"), count: 100).joined(separator: ","))]".utf8)
        let page2 = Data("[\(payload("v0.3.1"))]".utf8)
        let service = GitHubUpdateService { url in (url.query!.contains("page=2") ? page2 : page1, 200) }
        let result = try await service.newestUpdate(current: ReleaseVersion("0.3.0")!, currentBuild: 6)
        XCTAssertEqual(result?.tag_name, "v0.3.1")
    }
    func testTransportFailurePropagates() async {
        let service = GitHubUpdateService { _ in throw URLError(.notConnectedToInternet) }
        do { _ = try await service.newestUpdate(current: ReleaseVersion("0.3.0")!, currentBuild: 6); XCTFail("Transport failure accepted") }
        catch { XCTAssertTrue(error is URLError) }
    }
    func testMissingManifestAtEqualVersionDoesNotOfferUpdate() async throws {
        let data = Data("[\(payload("v0.3.0-beta.3", preview: true))]".utf8)
        let service = GitHubUpdateService { _ in (data, 200) }
        let result = try await service.newestUpdate(current: ReleaseVersion("0.3.0-beta.3")!, currentBuild: 6)
        XCTAssertNil(result)
    }
    func testUntrustedManifestURLFailsWithoutFetchingIt() async {
        let data = Data("[\(payload("v0.3.0-beta.3", preview: true, manifest: true))]".replacingOccurrences(of: "https://github.com/CalvinQin/SuperRClick/releases/download/", with: "https://example.com/").utf8)
        let service = GitHubUpdateService { url in
            XCTAssertEqual(url.host, "api.github.com")
            return (data, 200)
        }
        do { _ = try await service.newestUpdate(current: ReleaseVersion("0.3.0-beta.3")!, currentBuild: 6); XCTFail("Untrusted URL accepted") }
        catch { XCTAssertTrue(error is UpdateCheckError) }
    }
    func testPaginationLimitReportsFailure() async {
        let page = Data("[\(Array(repeating: payload("v0.1.0"), count: 100).joined(separator: ","))]".utf8)
        let service = GitHubUpdateService { _ in (page, 200) }
        do { _ = try await service.newestUpdate(current: ReleaseVersion("0.3.0")!, currentBuild: 6); XCTFail("Incomplete list accepted") }
        catch { XCTAssertTrue(error is UpdateCheckError) }
    }
    func testOlderBrokenManifestDoesNotHideNewerRelease() async throws {
        let data = Data("[\(payload("v0.3.0-beta.3", preview: true, manifest: true)),\(payload("v0.3.0"))]".utf8)
        let service = GitHubUpdateService { url in
            XCTAssertEqual(url.host, "api.github.com", "Older manifest should not be fetched")
            return (data, 200)
        }
        let result = try await service.newestUpdate(current: ReleaseVersion("0.3.0-beta.3")!, currentBuild: 6)
        XCTAssertEqual(result?.tag_name, "v0.3.0")
    }

}
