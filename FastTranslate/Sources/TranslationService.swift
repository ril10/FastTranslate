import Foundation
import SwiftUI
import Combine

@MainActor
final class TranslationService: ObservableObject {

    @Published var inputText: String = ""
    @Published var outputText: String = ""
    @Published var isTranslating: Bool = false
    @Published var errorMessage: String? = nil
    @Published var availableModels: [OllamaModel] = []
    @Published var isOllamaReachable: Bool = false

    private var client: OllamaClient
    private var currentTask: Task<Void, Never>?

    init() {
        let url = AppSettings.shared.ollamaURL
        self.client = OllamaClient(baseURL: url)
    }

    // MARK: - Public

    func translate() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        currentTask?.cancel()
        outputText = ""
        isTranslating = true
        errorMessage = nil

        let settings = AppSettings.shared
        let prompt = buildPrompt(
            text: inputText,
            from: settings.sourceLanguage,
            to: settings.targetLanguage
        )

        currentTask = Task {
            do {
                try await client.generateStream(
                    model: settings.selectedModel,
                    prompt: prompt
                ) { [weak self] token in
                    guard let self else { return }
                    Task { @MainActor in
                        self.outputText += token
                    }
                }
            } catch let error as OllamaError {
                errorMessage = error.localizedDescription
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
        Task {
            do {
                let models = try await client.fetchModels()
                await MainActor.run {
                    self.availableModels = models
                    self.isOllamaReachable = true
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.availableModels = []
                    self.isOllamaReachable = false
                }
            }
        }
    }

    func updateClient() {
        client = OllamaClient(baseURL: AppSettings.shared.ollamaURL)
        checkOllamaStatus()
    }

    func clearAll() {
        inputText = ""
        outputText = ""
        errorMessage = nil
        currentTask?.cancel()
        isTranslating = false
    }

    // MARK: - Prompt building

    private func buildPrompt(text: String, from source: Language, to target: Language) -> String {
        let sourcePart: String
        if source.code == "auto" {
            sourcePart = "Detect the source language automatically."
        } else {
            sourcePart = "The source language is \(source.name)."
        }

        return """
        You are a professional translator. \(sourcePart)
        Translate the following text to \(target.name).
        
        Rules:
        - Respond with ONLY the translation, nothing else
        - No explanations, no original text, no labels
        - Preserve formatting, line breaks, and punctuation style
        - Keep proper nouns and technical terms accurate
        
        Text to translate:
        \(text)
        """
    }
}
