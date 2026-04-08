import Foundation
import SwiftUI
import Combine

@MainActor
final class TranslationViewModel: ObservableObject {

    @Published var inputText: String = ""
    @Published var outputText: String = ""
    @Published var isTranslating: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isOllamaReachable: Bool = false

    private var provider: TranslationProvider
    private var currentTask: Task<Void, Never>?

    init(provider: TranslationProvider) {
        self.provider = provider
    }

    // MARK: - Public

    func translate() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        currentTask?.cancel()
        outputText = ""
        isTranslating = true
        errorMessage = nil

        let settings = AppSettings.shared
        let text = inputText
        let source = settings.sourceLanguage
        let target = settings.targetLanguage

        let stream = provider.translate(text: text, from: source, to: target)

        currentTask = Task {
            do {
                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    outputText += token
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            isTranslating = false
        }
    }

    func cancelTranslation() {
        currentTask?.cancel()
        isTranslating = false
    }

    func checkOllamaStatus() {
        guard let ollamaProvider = provider as? OllamaProvider else {
            isOllamaReachable = false
            return
        }

        Task {
            do {
                _ = try await ollamaProvider.fetchModels()
                isOllamaReachable = true
                errorMessage = nil
            } catch {
                isOllamaReachable = false
            }
        }
    }

    func updateProvider(_ newProvider: TranslationProvider) {
        provider = newProvider
        checkOllamaStatus()
    }

    func clearAll() {
        inputText = ""
        outputText = ""
        errorMessage = nil
        currentTask?.cancel()
        isTranslating = false
    }
}
