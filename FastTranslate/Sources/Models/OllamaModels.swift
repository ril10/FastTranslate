import Foundation

// MARK: - Request/Response

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
