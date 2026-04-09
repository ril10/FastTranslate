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

    // MARK: - Translation State

    enum TranslationState: Equatable {
        case idle
        case translating
        case done
        case error(String)
    }

    // MARK: - Output (Published state for View bindings)

    @Published var inputText: String = ""
    @Published private(set) var outputText: String = ""
    @Published private(set) var translationState: TranslationState = .idle
    @Published private(set) var isOllamaReachable: Bool = false

    var isTranslating: Bool { translationState == .translating }
    var errorMessage: String? {
        if case .error(let msg) = translationState { return msg }
        return nil
    }

    // MARK: - Private

    private var provider: TranslationProvider
    private var currentTask: Task<Void, Never>?
    private var autoTranslateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(provider: TranslationProvider) {
        self.provider = provider
        setupAutoTranslate()
    }

    private func setupAutoTranslate() {
        $inputText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                self.translate()
            }
            .store(in: &cancellables)
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
        translationState = .translating

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
        inputText = ""
        outputText = ""
        currentTask?.cancel()
        translationState = .idle
    }
}
