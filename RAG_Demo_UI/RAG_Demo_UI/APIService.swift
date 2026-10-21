import Foundation

private let baseURL = "http://localhost:8000"

final class APIService {

    func ask(
        question: String,
        model: String,
        history: [HistoryMessage],
        filterSources: [String]?
    ) async throws -> ChatResponse {
        let url = URL(string: "\(baseURL)/ask")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(question: question, model: model, history: history, filterSources: filterSources)
        )
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }

    func listModels() async throws -> [String] {
        let url = URL(string: "\(baseURL)/models")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ModelsResponse.self, from: data).models
    }

    func listDocuments() async throws -> [String] {
        let url = URL(string: "\(baseURL)/documents")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(DocumentsResponse.self, from: data).documents
    }

    func uploadDocument(fileURL: URL) async throws -> String {
        let url = URL(string: "\(baseURL)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(UploadResponse.self, from: data).message
    }

    func deleteDocument(filename: String) async throws -> String {
        let encoded = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
        let url = URL(string: "\(baseURL)/documents/\(encoded)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(DeleteResponse.self, from: data).message
    }
}
