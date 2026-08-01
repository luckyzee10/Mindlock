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
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else {
            return nil
        }
        return trimmed
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

    static func postHogAPIKey() -> String? {
        stringValue(for: "MindLockPostHogAPIKey")
    }

    static func postHogHostURL() -> URL {
        if let raw = stringValue(for: "MindLockPostHogHost"),
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "https://us.i.posthog.com")!
    }
}
