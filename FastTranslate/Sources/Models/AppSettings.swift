import Foundation
import Combine
import ServiceManagement

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

// MARK: - Language model

struct Language: Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let flag: String

    static let auto = Language(id: "auto", code: "auto", name: "Auto-detect", flag: "🌐")
    static let english = Language(id: "en", code: "en", name: "English", flag: "🇬🇧")
    static let russian = Language(id: "ru", code: "ru", name: "Russian", flag: "🇷🇺")
    static let german = Language(id: "de", code: "de", name: "German", flag: "🇩🇪")
    static let french = Language(id: "fr", code: "fr", name: "French", flag: "🇫🇷")
    static let spanish = Language(id: "es", code: "es", name: "Spanish", flag: "🇪🇸")
    static let italian = Language(id: "it", code: "it", name: "Italian", flag: "🇮🇹")
    static let portuguese = Language(id: "pt", code: "pt", name: "Portuguese", flag: "🇵🇹")
    static let chinese = Language(id: "zh", code: "zh", name: "Chinese", flag: "🇨🇳")
    static let japanese = Language(id: "ja", code: "ja", name: "Japanese", flag: "🇯🇵")
    static let polish = Language(id: "pl", code: "pl", name: "Polish", flag: "🇵🇱")
    static let ukrainian = Language(id: "uk", code: "uk", name: "Ukrainian", flag: "🇺🇦")

    static let all: [Language] = [
        .auto, .english, .russian, .german, .french,
        .spanish, .italian, .portuguese, .chinese, .japanese,
        .polish, .ukrainian
    ]

    static let targets: [Language] = all.filter { $0.code != "auto" }
}
