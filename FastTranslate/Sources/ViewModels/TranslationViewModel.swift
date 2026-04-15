import Foundation
import Observation

@MainActor
@Observable
final class TranslationViewModel {

    enum Input {
        case translate
        case cancelTranslation
        case clearAll
        case checkOllamaStatus
        case updateProvider(TranslationProvider)
        case swapTexts(newInput: String, newOutput: String)
    }

    enum TranslationState: Equatable {
        case idle
        case translating
        case done
        case error(String)
    }

    var inputText: String = "" {
        didSet { scheduleAutoTranslate() }
    }
    private(set) var outputText: String = ""
    private(set) var translationState: TranslationState = .idle
    private(set) var isOllamaReachable: Bool = false

    var isTranslating: Bool { translationState == .translating }
    var errorMessage: String? {
        if case .error(let msg) = translationState { return msg }
        return nil
    }

    private var provider: TranslationProvider
    private let settings: AppSettings
    private var currentTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    init(provider: TranslationProvider, settings: AppSettings) {
        self.provider = provider
        self.settings = settings
    }

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

    private func scheduleAutoTranslate() {
        debounceTask?.cancel()
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.translate()
        }
    }

    private func translate() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        currentTask?.cancel()
        outputText = ""
        translationState = .translating

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
                if !Task.isCancelled {
                    translationState = outputText.isEmpty ? .idle : .done
                }
            } catch {
                if !Task.isCancelled {
                    translationState = .error(error.localizedDescription)
                }
            }
        }
    }

    private func cancelTranslation() {
        currentTask?.cancel()
        translationState = .idle
    }

    private func checkOllamaStatus() {
        Task {
            let reachable = await provider.checkAvailability()
            isOllamaReachable = reachable
        }
    }

    private func updateProvider(_ newProvider: TranslationProvider) {
        provider = newProvider
        checkOllamaStatus()
    }

    private func clearAll() {
        debounceTask?.cancel()
        inputText = ""
        outputText = ""
        currentTask?.cancel()
        translationState = .idle
    }
}
