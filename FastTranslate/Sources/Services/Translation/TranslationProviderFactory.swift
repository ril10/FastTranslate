import Foundation

@MainActor
protocol TranslationProviderFactory {
    func make() -> TranslationProvider
}

@MainActor
final class OllamaProviderFactory: TranslationProviderFactory {

    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func make() -> TranslationProvider {
        OllamaProvider(baseURL: settings.ollamaURL, model: settings.selectedModel)
    }
}
