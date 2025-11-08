import Foundation

enum AppConfigurationError: LocalizedError {
    case missingValue(String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let key):
            return "\(key) is not configured. Update MindLock/Info.plist or your build settings."
        case .invalidURL(let value):
            return "Invalid API base URL: \(value)"
        }
    }
}

enum AppConfiguration {
    private static func stringValue(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    static func apiBaseURL() throws -> URL {
        if let raw = stringValue(for: "MindLockAPIBaseURL"), !raw.isEmpty {
            if let url = URL(string: raw) {
                return url
            } else {
                throw AppConfigurationError.invalidURL(raw)
            }
        }
#if DEBUG
        return URL(string: "http://localhost:4000")!
#else
        throw AppConfigurationError.missingValue("MindLockAPIBaseURL")
#endif
    }

    static func appAPIKey() throws -> String {
        if let key = stringValue(for: "MindLockAppAPIKey"), !key.isEmpty {
            return key
        }
#if DEBUG
        return "debug-app-key"
#else
        throw AppConfigurationError.missingValue("MindLockAppAPIKey")
#endif
    }
}
