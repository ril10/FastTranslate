import Foundation

// MARK: - OllamaProvider

nonisolated final class OllamaProvider: TranslationProvider, Sendable {

    private let baseURL: String
    private let model: String

    init(baseURL: String, model: String) {
        self.baseURL = baseURL
        self.model = model
    }

    // MARK: - TranslationProvider

    func translate(text: String, from source: Language, to target: Language) -> AsyncThrowingStream<String, Error> {
        let prompt = buildPrompt(text: text, from: source, to: target)
        let baseURL = self.baseURL
        let model = self.model

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: "\(baseURL)/api/generate") else {
                        continuation.finish(throwing: OllamaError.invalidURL)
                        return
                    }

                    let requestBody = OllamaGenerateRequest(
                        model: model,
                        prompt: prompt,
                        stream: true,
                        options: OllamaOptions(temperature: 0.1, numPredict: 512)
                    )

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(requestBody)
                    request.timeoutInterval = 30

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OllamaError.noResponse)
                        return
                    }

                    if httpResponse.statusCode == 404 {
                        continuation.finish(throwing: OllamaError.modelNotFound(model))
                        return
                    }

                    if httpResponse.statusCode != 200 {
                        continuation.finish(throwing: OllamaError.ollamaNotRunning)
                        return
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard !line.isEmpty,
                              let data = line.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(OllamaGenerateResponse.self, from: data) else {
                            continue
                        }

                        if !chunk.response.isEmpty {
                            continuation.yield(chunk.response)
                        }

                        if chunk.done { break }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func checkAvailability() async -> Bool {
        do {
            _ = try await fetchModels()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Ollama-specific

    func fetchModels() async throws -> [OllamaModel] {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw OllamaError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw OllamaError.ollamaNotRunning
            }

            return try JSONDecoder().decode(OllamaTagsResponse.self, from: data).models
        } catch let error as OllamaError {
            throw error
        } catch {
            throw OllamaError.ollamaNotRunning
        }
    }

    // MARK: - Prompt

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
