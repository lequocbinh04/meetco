import Foundation
import Security

public enum SecretIdentifier: String, CaseIterable, Sendable {
    case elevenLabsAPIKey = "elevenlabs-api-key"
    case anthropicAPIKey = "anthropic-api-key"
}

public struct KeychainError: Error, LocalizedError, Equatable, Sendable {
    public let status: OSStatus

    public init(status: OSStatus) {
        self.status = status
    }

    public var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }
        return "Keychain operation failed (\(status))."
    }
}

public struct KeychainStore: Sendable {
    public let service: String

    public init(service: String = "com.meetco.personal") {
        self.service = service
    }

    public func setSecret(_ secret: String, for identifier: SecretIdentifier) throws {
        let encoded = Data(secret.utf8)
        let query = baseQuery(identifier)
        let attributes: [String: Any] = [kSecValueData as String: encoded]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = encoded
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainError(status: updateStatus)
        }
    }

    public func secret(for identifier: SecretIdentifier) throws -> String? {
        var query = baseQuery(identifier)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError(status: status)
        }
        return String(data: data, encoding: .utf8)
    }

    public func deleteSecret(for identifier: SecretIdentifier) throws {
        let status = SecItemDelete(baseQuery(identifier) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private func baseQuery(_ identifier: SecretIdentifier) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identifier.rawValue,
        ]
    }
}
