import Foundation
import Shared
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system:
            return L("跟随系统", "System Default")
        case .english:
            return "English"
        case .chinese:
            return "简体中文"
        }
    }
}

@MainActor
@Observable
final class LanguageManager {
    static let shared = LanguageManager()
    
    private let languageKey = "app_selected_language"
    
    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
            // Sync to App Group so Finder extension can read it
            UserDefaults(suiteName: "group.com.haoqiqin.superrclick")?
                .set(currentLanguage.rawValue, forKey: languageKey)
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "app_selected_language"),
           let language = AppLanguage(rawValue: saved) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }
    }
    
    var locale: Locale? {
        if currentLanguage == .system {
            return nil
        } else {
            return Locale(identifier: currentLanguage.rawValue)
        }
    }
}
