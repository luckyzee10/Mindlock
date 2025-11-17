import Foundation

struct PurchaseSubmissionRequest: Encodable {
    let userId: String
    let userEmail: String?
    let charityId: String
    let charityName: String
    let productId: String
    let transactionId: String
    let transactionJWS: String
    let receiptData: String?
    let subscriptionTier: String?
}

struct PurchaseSubmissionResponse: Decodable {
    let purchaseId: String
    let status: String
}

struct ImpactSummaryResponse: Decodable {
    struct Charity: Decodable, Identifiable {
        let charityId: String
        let charityName: String
        let donationCents: Int

        var id: String { charityId }
    }

    let totalDonationCents: Int
    let monthDonationCents: Int
    let totalDonations: Int
    let charities: [Charity]
}

struct ImpactReportRequest: Encodable {
    let userId: String
    let userEmail: String?
    let subscriptionTier: String
    let month: String
    let impactPoints: Int
    let streakDays: Int
    let multiplier: Int
}

enum APIError: LocalizedError {
    case invalidResponse
    case server(status: Int, message: String?)
    case misconfigured(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "We couldn't read the response from MindLock."
        case .server(let status, let message):
            if let message, !message.isEmpty {
                return "Server error (\(status)): \(message)"
            }
            return "Server error (\(status)). Please try again."
        case .misconfigured(let key):
            return "\(key) is not configured. Update your build settings before shipping."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func submitPurchase(_ request: PurchaseSubmissionRequest) async throws -> PurchaseSubmissionResponse {
        let baseURL = try AppConfiguration.apiBaseURL()
        let appKey = try AppConfiguration.appAPIKey()
        let endpoint = baseURL.appendingPathComponent("v1/purchases")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(appKey, forHTTPHeaderField: "X-App-Key")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = decodeErrorMessage(from: data)
            throw APIError.server(status: httpResponse.statusCode, message: message)
        }
        return try JSONDecoder().decode(PurchaseSubmissionResponse.self, from: data)
    }

    func fetchImpactSummary(userId: String) async throws -> ImpactSummaryResponse {
        let baseURL = try AppConfiguration.apiBaseURL()
        let appKey = try AppConfiguration.appAPIKey()
        var components = URLComponents(
            url: baseURL.appendingPathComponent("v1/impact/summary"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "userId", value: userId)]
        guard let url = components?.url else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(appKey, forHTTPHeaderField: "X-App-Key")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = decodeErrorMessage(from: data)
            throw APIError.server(status: httpResponse.statusCode, message: message)
        }
        return try JSONDecoder().decode(ImpactSummaryResponse.self, from: data)
    }

    func submitImpactReport(_ requestBody: ImpactReportRequest) async throws {
        let baseURL = try AppConfiguration.apiBaseURL()
        let appKey = try AppConfiguration.appAPIKey()
        let endpoint = baseURL.appendingPathComponent("v1/impact/report")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(appKey, forHTTPHeaderField: "X-App-Key")
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        let (_, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw APIError.server(status: httpResponse.statusCode, message: nil)
        }
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let envelope = try? JSONDecoder().decode(ServerErrorEnvelope.self, from: data) {
            return envelope.error
        }
        return String(data: data, encoding: .utf8)
    }
}

private struct ServerErrorEnvelope: Decodable {
    let error: String?
}
