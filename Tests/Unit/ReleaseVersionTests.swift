import XCTest
@testable import Shared

final class ReleaseVersionTests: XCTestCase {
    func version(_ value: String) -> ReleaseVersion { ReleaseVersion(value)! }

    func testSemanticPrecedence() {
        let ordered = ["0.2.1", "0.3.0-alpha", "0.3.0-alpha.1", "0.3.0-alpha.beta", "0.3.0-beta.1", "0.3.0-beta.2", "0.3.0-beta.10", "0.3.0-rc.1", "0.3.0", "0.3.1", "0.10.0", "1.0.0"]
        for (a,b) in zip(ordered, ordered.dropFirst()) { XCTAssertLessThan(version(a), version(b), "\(a) < \(b)") }
    }
    func testMetadataDoesNotChangePrecedence() {
        XCTAssertEqual(version("v0.3.0-beta.3+build.6"), version("0.3.0-beta.3+build.7"))
    }
    func testInvalidVersions() {
        for value in ["", "latest", "0.3", "0.03.0", "0.3.0-", "0.3.0-beta.01", "0.3.0+", "0.3.0+bad+meta", "vfoo0.3.0", "0.3.0-β"] { XCTAssertNil(ReleaseVersion(value), value) }
    }
    func testPreviewChannelAndGraduation() {
        let preview = version("0.3.0-beta.3"), stable = version("0.3.0")
        XCTAssertTrue(UpdatePolicy.allows(stable, flaggedPreview: false, current: preview))
        XCTAssertTrue(UpdatePolicy.allows(version("0.4.0-beta.1"), flaggedPreview: true, current: preview))
        XCTAssertFalse(UpdatePolicy.allows(version("0.4.0-beta.1"), flaggedPreview: false, current: stable))
        XCTAssertFalse(UpdatePolicy.allows(version("0.4.0"), flaggedPreview: true, current: stable))
        XCTAssertTrue(UpdatePolicy.allows(version("0.4.0"), flaggedPreview: false, current: stable))
    }
    func testBuildComparisonAndNoDowngrade() {
        let current = version("0.3.0-beta.3")
        XCTAssertTrue(UpdatePolicy.isNewer(current, build: 7, than: current, currentBuild: 6))
        XCTAssertFalse(UpdatePolicy.isNewer(current, build: 6, than: current, currentBuild: 6))
        XCTAssertFalse(UpdatePolicy.isNewer(current, build: 5, than: current, currentBuild: 6))
        XCTAssertFalse(UpdatePolicy.isNewer(current, build: nil, than: current, currentBuild: 6))
        XCTAssertFalse(UpdatePolicy.isNewer(version("0.3.0-beta.2"), build: 99, than: current, currentBuild: 6))
        XCTAssertTrue(UpdatePolicy.isNewer(version("0.3.0"), build: 1, than: current, currentBuild: 6))
    }
    func testLegacyIdentity() {
        XCTAssertEqual(UpdatePolicy.installedVersion(explicit: nil, marketing: "0.3.0", build: 4), version("0.3.0-beta.1"))
        XCTAssertEqual(UpdatePolicy.installedVersion(explicit: nil, marketing: "0.3.0", build: 5), version("0.3.0-beta.2"))
        XCTAssertEqual(UpdatePolicy.installedVersion(explicit: "0.3.0-beta.3", marketing: "0.3.0", build: 6), version("0.3.0-beta.3"))
        XCTAssertNil(UpdatePolicy.installedVersion(explicit: "bad", marketing: "0.3.0", build: 6))
    }
}
