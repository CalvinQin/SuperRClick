import AppKit
import Foundation
import Shared

struct GitHubRelease: Codable {
    let tag_name: String
    let html_url: String
    let name: String
    let body: String?
}

@MainActor
final class GitHubUpdater: ObservableObject {
    static let shared = GitHubUpdater()
    private let repoURL = "https://api.github.com/repos/haoqiqin/SuperRClick/releases/latest"

    @Published var isChecking = false

    private init() {}

    func checkForUpdates(manual: Bool = false) {
        guard !isChecking else { return }
        isChecking = true

        Task {
            do {
                guard let url = URL(string: repoURL) else { throw URLError(.badURL) }
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    if manual { showUpToDateAlert() }
                    isChecking = false
                    return
                }

                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

                let latestVersionStr = release.tag_name.replacingOccurrences(of: "v", with: "")

                if latestVersionStr.compare(currentVersion, options: .numeric) == .orderedDescending {
                    // Update available
                    showUpdateAlert(release: release)
                } else {
                    if manual { showUpToDateAlert() }
                }

            } catch {
                if manual {
                    let alert = NSAlert()
                    alert.messageText = L("检查更新失败", "Update check failed")
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }

            self.isChecking = false
        }
    }

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = L("已是最新版本", "You're up to date")
        alert.informativeText = L("您当前使用的是最新版 Super RClick。", "You are running the latest version of Super RClick.")
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func showUpdateAlert(release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = L("发现新版本：", "New version available:") + " \(release.name)"
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
