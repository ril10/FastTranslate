import Foundation
import Combine
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let ollamaURL = "ollamaURL"
        static let selectedModel = "selectedModel"
        static let sourceLanguage = "sourceLanguage"
        static let targetLanguage = "targetLanguage"
        static let launchAtLogin = "launchAtLogin"
        static let inlineTranslation = "inlineTranslation"
    }

    // MARK: - Published properties

    @Published var ollamaURL: String {
        didSet { defaults.set(ollamaURL, forKey: Keys.ollamaURL) }
    }

    @Published var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: Keys.selectedModel) }
    }

    @Published var sourceLanguage: Language {
        didSet { defaults.set(sourceLanguage.code, forKey: Keys.sourceLanguage) }
    }

    @Published var targetLanguage: Language {
        didSet { defaults.set(targetLanguage.code, forKey: Keys.targetLanguage) }
    }

    @Published var inlineTranslation: Bool {
        didSet { defaults.set(inlineTranslation, forKey: Keys.inlineTranslation) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    // MARK: - Init

    private init() {
        ollamaURL = defaults.string(forKey: Keys.ollamaURL) ?? "http://localhost:11434"
        selectedModel = defaults.string(forKey: Keys.selectedModel) ?? "gemma3:12b"

        let sourceCode = defaults.string(forKey: Keys.sourceLanguage) ?? "auto"
        let targetCode = defaults.string(forKey: Keys.targetLanguage) ?? "ru"

        sourceLanguage = Language.all.first { $0.code == sourceCode } ?? .auto
        targetLanguage = Language.all.first { $0.code == targetCode } ?? .russian

        // Default: inline translation enabled
        if defaults.object(forKey: Keys.inlineTranslation) == nil {
            defaults.set(true, forKey: Keys.inlineTranslation)
        }
        inlineTranslation = defaults.bool(forKey: Keys.inlineTranslation)

        // Default: launch at login enabled
        if defaults.object(forKey: Keys.launchAtLogin) == nil {
            defaults.set(true, forKey: Keys.launchAtLogin)
        }
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        if launchAtLogin {
            try? SMAppService.mainApp.register()
        }
    }
}
