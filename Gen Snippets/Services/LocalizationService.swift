import Foundation
import Combine

class LocalizationService {
    static let shared = LocalizationService()
    
    @Published var currentLanguage: Language = .english
    
    private init() {
        // Load the saved language or use the system language
        if let savedLanguageCode = UserDefaults.standard.string(forKey: "appLanguage") {
            if savedLanguageCode == "vi" {
                currentLanguage = .vietnamese
            } else {
                currentLanguage = .english
            }
        } else {
            // Use the system language
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            if preferredLanguage.starts(with: "vi") {
                currentLanguage = .vietnamese
            } else {
                currentLanguage = .english
            }
            
            // Save the language
            UserDefaults.standard.set(currentLanguage.code, forKey: "appLanguage")
        }
    }
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
        UserDefaults.standard.set(language.code, forKey: "appLanguage")
        
        // Post a notification to update the UI
        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
    }
    
    func localizedString(for key: String) -> String {
        let path = Bundle.main.path(forResource: currentLanguage.code, ofType: "lproj") ?? Bundle.main.path(forResource: "en", ofType: "lproj")!
        let bundle = Bundle(path: path)!
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }
}

enum Language: String, CaseIterable, Identifiable {
    case english = "English"
    case vietnamese = "Tiếng Việt"
    
    var id: String { self.rawValue }
    
    var code: String {
        switch self {
        case .english:
            return "en"
        case .vietnamese:
            return "vi"
        }
    }
} 