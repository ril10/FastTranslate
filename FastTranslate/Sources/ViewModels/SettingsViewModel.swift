import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var models: [OllamaModel] = []
    @Published var isLoadingModels = false
    @Published var connectionError = ""

    func refreshModels(url: String, settings: AppSettings) {
        isLoadingModels = true
        connectionError = ""

        Task {
            let provider = OllamaProvider(baseURL: url, model: "")
            do {
                let fetched = try await provider.fetchModels()
                models = fetched
                if !fetched.isEmpty && !fetched.contains(where: { $0.name == settings.selectedModel }) {
                    settings.selectedModel = fetched[0].name
                }
            } catch let error as OllamaError {
                connectionError = error.localizedDescription
                models = []
            } catch {
                connectionError = "Cannot connect to Ollama"
                models = []
            }
            isLoadingModels = false
        }
    }
}
