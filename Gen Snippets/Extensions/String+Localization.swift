import Foundation

extension String {
    var localized: String {
        return LocalizationService.shared.localizedString(for: self)
    }
} 