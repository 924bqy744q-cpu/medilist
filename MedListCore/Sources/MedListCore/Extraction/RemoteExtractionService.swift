import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Minimal HTTP abstraction so network clients can be tested with canned responses.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let http = response as? HTTPURLResponse {
                    continuation.resume(returning: (data ?? Data(), http))
                } else {
                    continuation.resume(throwing: ExtractionError.invalidResponse)
                }
            }.resume()
        }
    }
}

/// Sends OCR text (never images) to the MedList extraction proxy, which calls the Claude API server-side.
///
/// The app holds no LLM API key. `clientToken` is only a coarse gate for the proxy; see TODO.md for App Attest.
public struct RemoteExtractionService: ExtractionService {
    public static let maxInputCharacters = 8_000

    let endpoint: URL
    let clientToken: String?
    let transport: HTTPTransport

    public init(endpoint: URL, clientToken: String? = nil, transport: HTTPTransport = URLSessionTransport()) {
        self.endpoint = endpoint
        self.clientToken = clientToken
        self.transport = transport
    }

    struct RequestBody: Encodable {
        let text: String
        let language: String
    }

    public func extract(from ocrText: String, languageCode: String) async throws -> [ExtractedMedication] {
        let text = String(ocrText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxInputCharacters))
        guard !text.isEmpty else { throw ExtractionError.emptyInput }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let clientToken { request.setValue(clientToken, forHTTPHeaderField: "X-MedList-Client") }
        request.httpBody = try JSONEncoder().encode(RequestBody(text: text, language: languageCode))

        let (data, response): (Data, HTTPURLResponse)
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw ExtractionError.transport
        }
        guard (200..<300).contains(response.statusCode) else {
            throw ExtractionError.server(status: response.statusCode)
        }
        do {
            return try JSONDecoder().decode(ExtractionResponse.self, from: data).medications.filter { !$0.isEmpty }
        } catch {
            throw ExtractionError.invalidResponse
        }
    }
}
