import Foundation

// MARK: - Models

struct OllamaGenerateRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions?
}

struct OllamaOptions: Codable {
    let temperature: Double?
    let numPredict: Int?

    enum CodingKeys: String, CodingKey {
        case temperature
        case numPredict = "num_predict"
    }
}

struct OllamaGenerateResponse: Codable {
    let model: String
    let response: String
    let done: Bool
}

struct OllamaTagsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaModel: Codable, Identifiable {
    var id: String { name }
    let name: String
    let size: Int64?
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case invalidURL
    case noResponse
    case ollamaNotRunning
    case modelNotFound(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Ollama URL"
        case .noResponse: return "No response from Ollama"
        case .ollamaNotRunning: return "Ollama is not running. Start it with: ollama serve"
        case .modelNotFound(let name): return "Model '\(name)' not found. Pull it with: ollama pull \(name)"
        case .decodingFailed(let msg): return "Failed to decode response: \(msg)"
        }
    }
}

// MARK: - Client

final class OllamaClient {

    private let baseURL: String

    init(baseURL: String = "http://localhost:11434") {
        self.baseURL = baseURL
    }

    // MARK: - Fetch available models

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

            let tagsResponse = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            return tagsResponse.models

        } catch let error as OllamaError {
            throw error
        } catch {
            throw OllamaError.ollamaNotRunning
        }
    }

    // MARK: - Generate with streaming

    func generateStream(
        model: String,
        prompt: String,
        onToken: @escaping (String) -> Void
    ) async throws {

        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }

        let request_body = OllamaGenerateRequest(
            model: model,
            prompt: prompt,
            stream: true,
            options: OllamaOptions(temperature: 0.1, numPredict: 512)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(request_body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.noResponse
        }

        if httpResponse.statusCode == 404 {
            throw OllamaError.modelNotFound(model)
        }

        if httpResponse.statusCode != 200 {
            throw OllamaError.ollamaNotRunning
        }

        // Читаем стриминг построчно
        for try await line in bytes.lines {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(OllamaGenerateResponse.self, from: data) else {
                continue
            }

            if !chunk.response.isEmpty {
                onToken(chunk.response)
            }

            if chunk.done { break }
        }
    }
}
