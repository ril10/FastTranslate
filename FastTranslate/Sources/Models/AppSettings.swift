import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {

    private let storage: SettingsStorage

    private enum Keys {
        static let ollamaURL = "ollamaURL"
        static let selectedModel = "selectedModel"
        static let sourceLanguage = "sourceLanguage"
        static let targetLanguage = "targetLanguage"
        static let launchAtLogin = "launchAtLogin"
        static let inlineTranslation = "inlineTranslation"
        static let liquidGlassEnabled = "liquidGlassEnabled"
        static let notchOverlayEnabled = "notchOverlayEnabled"
    }

    var ollamaURL: String {
        didSet { storage.set(ollamaURL, forKey: Keys.ollamaURL) }
    }

    var selectedModel: String {
        didSet { storage.set(selectedModel, forKey: Keys.selectedModel) }
    }

    var sourceLanguage: Language {
        didSet { storage.set(sourceLanguage.code, forKey: Keys.sourceLanguage) }
    }

    var targetLanguage: Language {
        didSet { storage.set(targetLanguage.code, forKey: Keys.targetLanguage) }
    }

    var inlineTranslation: Bool {
        didSet { storage.set(inlineTranslation, forKey: Keys.inlineTranslation) }
    }

    var liquidGlassEnabled: Bool {
        didSet { storage.set(liquidGlassEnabled, forKey: Keys.liquidGlassEnabled) }
    }

    var notchOverlayEnabled: Bool {
        didSet { storage.set(notchOverlayEnabled, forKey: Keys.notchOverlayEnabled) }
    }

    var launchAtLogin: Bool {
        didSet {
            storage.set(launchAtLogin, forKey: Keys.launchAtLogin)
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    init(storage: SettingsStorage) {
        self.storage = storage

        ollamaURL = storage.string(forKey: Keys.ollamaURL) ?? "http://localhost:11434"
        selectedModel = storage.string(forKey: Keys.selectedModel) ?? "gemma3:12b"

        let sourceCode = storage.string(forKey: Keys.sourceLanguage) ?? "auto"
        let targetCode = storage.string(forKey: Keys.targetLanguage) ?? "ru"
        sourceLanguage = Language.all.first { $0.code == sourceCode } ?? .auto
        targetLanguage = Language.all.first { $0.code == targetCode } ?? .russian

        if storage.object(forKey: Keys.inlineTranslation) == nil {
            storage.set(true, forKey: Keys.inlineTranslation)
        }
        inlineTranslation = storage.bool(forKey: Keys.inlineTranslation)

        if storage.object(forKey: Keys.liquidGlassEnabled) == nil {
            storage.set(true, forKey: Keys.liquidGlassEnabled)
        }
        liquidGlassEnabled = storage.bool(forKey: Keys.liquidGlassEnabled)

        if storage.object(forKey: Keys.notchOverlayEnabled) == nil {
            storage.set(true, forKey: Keys.notchOverlayEnabled)
        }
        notchOverlayEnabled = storage.bool(forKey: Keys.notchOverlayEnabled)

        if storage.object(forKey: Keys.launchAtLogin) == nil {
            storage.set(true, forKey: Keys.launchAtLogin)
        }
        launchAtLogin = storage.bool(forKey: Keys.launchAtLogin)
        if launchAtLogin {
            try? SMAppService.mainApp.register()
        }
    }
}
