import Foundation
import SwiftUI
import Combine

@MainActor
final class TranslationViewModel: ObservableObject {

    // MARK: - Input

    enum Input {
        case translate
        case cancelTranslation
        case clearAll
        case checkOllamaStatus
        case updateProvider(TranslationProvider)
        case swapTexts(newInput: String, newOutput: String)
    }

    // MARK: - Output (Published state for View bindings)

    @Published var inputText: String = ""
    @Published private(set) var outputText: String = ""
    @Published private(set) var isTranslating: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isOllamaReachable: Bool = false

    // MARK: - Private

    private var provider: TranslationProvider
    private var currentTask: Task<Void, Never>?

    // MARK: - Init

    init(provider: TranslationProvider) {
        self.provider = provider
    }

    // MARK: - Input handling

    func send(_ input: Input) {
        switch input {
        case .translate:
            translate()
        case .cancelTranslation:
            cancelTranslation()
        case .clearAll:
            clearAll()
        case .checkOllamaStatus:
            checkOllamaStatus()
        case .updateProvider(let newProvider):
            updateProvider(newProvider)
        case .swapTexts(let newInput, let newOutput):
            inputText = newInput
            outputText = newOutput
        }
    }

    // MARK: - Private methods

    private func translate() {
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

    private func cancelTranslation() {
        currentTask?.cancel()
        isTranslating = false
    }

    private func checkOllamaStatus() {
        Task {
            let reachable = await provider.checkAvailability()
            isOllamaReachable = reachable
            if reachable { errorMessage = nil }
        }
    }

    private func updateProvider(_ newProvider: TranslationProvider) {
        provider = newProvider
        checkOllamaStatus()
    }

    private func clearAll() {
        inputText = ""
        outputText = ""
        errorMessage = nil
        currentTask?.cancel()
        isTranslating = false
    }
}
