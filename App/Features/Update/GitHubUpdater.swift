import AppKit
import Foundation
import Shared

@MainActor
final class GitHubUpdater: ObservableObject {
    static let shared = GitHubUpdater()
    private let service = GitHubUpdateService()

    @Published var isChecking = false
    @Published var statusText = ""
    var versionLabel: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["SuperRClickReleaseVersion"] as? String ?? info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(L("构建", "build")) \(build))"
    }

    private init() {}

    func checkForUpdates(manual: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        statusText = L("正在检查更新…", "Checking for updates…")

        Task {
            defer { isChecking = false }
            do {
                let info = Bundle.main.infoDictionary ?? [:]
                let marketing = info["CFBundleShortVersionString"] as? String ?? ""
                let build = Int(info["CFBundleVersion"] as? String ?? "") ?? 0
                guard let current = UpdatePolicy.installedVersion(
                    explicit: info["SuperRClickReleaseVersion"] as? String,
                    marketing: marketing, build: build
                ) else { throw UpdateCheckError.invalidInstalledVersion }
                if let release = try await service.newestUpdate(current: current, currentBuild: build) {
                    statusText = L("发现新版本：", "Update available: ") + release.tag_name
                    showUpdateAlert(release: release)
                } else {
                    statusText = L("当前更新渠道没有更新版本。", "No newer release in your update channel.")
                    if manual { showUpToDateAlert() }
                }
            } catch {
                statusText = L("检查更新失败，请稍后重试。", "Update check failed. Please try again.")
                if manual {
                    let alert = NSAlert()
                    alert.messageText = L("检查更新失败", "Update check failed")
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = L("已是最新版本", "You're up to date")
        alert.informativeText = L("当前更新渠道没有更新版本。", "No newer release is available in your update channel.")
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func showUpdateAlert(release: UpdateRelease) {
        let alert = NSAlert()
        alert.messageText = L("发现新版本：", "New version available:") + " \(release.name ?? release.tag_name)"
        alert.informativeText = L("是否立即前往 GitHub 下载最新版本？\n\n更新内容：\n", "Would you like to download it from GitHub?\n\nRelease notes:\n") + (release.body ?? "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("去下载", "Download"))
        alert.addButton(withTitle: L("取消", "Cancel"))
        
        // Ensure alert pops up even if app is in background mode (menu bar mode)
        NSApp.activate(ignoringOtherApps: true)
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let downloadURL = URL(string: release.html_url) {
                NSWorkspace.shared.open(downloadURL)
            }
        }
    }
}
