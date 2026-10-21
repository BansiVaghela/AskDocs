import Foundation

struct ChatResponse: Codable {
    let answer: String
    let sources: [String]
    let context: String
}

struct DocumentsResponse: Codable {
    let documents: [String]
}

struct ModelsResponse: Codable {
    let models: [String]
}

struct UploadResponse: Codable {
    let message: String
}

struct DeleteResponse: Codable {
    let message: String
}

struct HistoryMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let question: String
    let model: String
    let history: [HistoryMessage]
    let filterSources: [String]?

    enum CodingKeys: String, CodingKey {
        case question, model, history
        case filterSources = "filter_sources"
    }
}
