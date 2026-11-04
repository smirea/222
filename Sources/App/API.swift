import Foundation
import Security

enum APIError: LocalizedError {
    case unauthorized
    case http(Int, String)
    case reprompt(String, RSVP?)

    var errorDescription: String? {
        switch self {
        case .unauthorized: "222 rejected the token."
        case .http(let code, let body): "HTTP \(code): \(body.prefix(200))"
        case .reprompt(let message, _): message
        }
    }
}

struct API: Sendable {
    let token: String
    private static let base = URL(string: "https://ios.api.222.place")!

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            guard let date = parseDate(string) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(string)"))
            }
            return date
        }
        return decoder
    }()

    // The API mixes second and microsecond precision, which neither ISO8601 formatter accepts alone.
    static func parseDate(_ string: String) -> Date? {
        if let date = try? Date(string, strategy: .iso8601) { return date }
        let trimmed = string.replacing(/\.(\d{3})\d*/) { ".\($0.1)" }
        return try? Date(trimmed, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    func data(_ method: String, _ path: String, query: [String: String] = [:], body: [String: Any]? = nil) async throws -> Data {
        var components = URLComponents(url: Self.base.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body ?? [:])
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw APIError.unauthorized }
        if status == 400, let failure = try? Self.decoder.decode(Failure.self, from: data), failure.errorCode == "SHOULD_REPROMPT" {
            throw APIError.reprompt(failure.errorData?.repromptMessage ?? "The terms changed.", failure.errorData?.rsvp)
        }
        guard (200..<300).contains(status) else { throw APIError.http(status, String(decoding: data, as: UTF8.self)) }
        return data
    }

    private struct Failure: Decodable {
        let errorCode: String?
        let errorData: ErrorData?
        struct ErrorData: Decodable {
            let repromptMessage: String?
            let rsvp: RSVP?
        }
    }
}

enum Keychain {
    private static var query: [String: Any] { [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.stefan.222",
        kSecAttrAccount as String: "token",
    ] }

    static var token: String? {
        get {
            var item: CFTypeRef?
            var lookup = query
            lookup[kSecReturnData as String] = true
            guard SecItemCopyMatching(lookup as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
                return UserDefaults.standard.string(forKey: "token")
            }
            return String(decoding: data, as: UTF8.self)
        }
        set {
            SecItemDelete(query as CFDictionary)
            UserDefaults.standard.removeObject(forKey: "token")
            guard let newValue else { return }
            var item = query
            item[kSecValueData as String] = Data(newValue.utf8)
            // Unsigned simulator builds have no keychain entitlement, so the add fails there.
            if SecItemAdd(item as CFDictionary, nil) != errSecSuccess {
                UserDefaults.standard.set(newValue, forKey: "token")
            }
        }
    }
}
