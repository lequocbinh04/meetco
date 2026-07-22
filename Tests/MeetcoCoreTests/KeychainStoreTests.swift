import Foundation
import Security
import Testing
@testable import MeetcoCore

@Suite("Keychain storage")
struct KeychainStoreTests {
    @Test
    func secretLifecycleUsesDedicatedService() throws {
        let store = KeychainStore(service: "com.meetco.tests.\(UUID().uuidString)")
        defer { try? store.deleteSecret(for: .elevenLabsAPIKey) }

        do {
            try store.setSecret("test-secret-value", for: .elevenLabsAPIKey)
            #expect(try store.secret(for: .elevenLabsAPIKey) == "test-secret-value")
            try store.deleteSecret(for: .elevenLabsAPIKey)
            #expect(try store.secret(for: .elevenLabsAPIKey) == nil)
        } catch let error as KeychainError where error.status == errSecNotAvailable {
            return
        }
    }

    @Test
    func settingsEncodingDoesNotContainCredentialFields() throws {
        let data = try JSONCoding.encoder().encode(AppSettings())
        let json = String(decoding: data, as: UTF8.self).lowercased()
        #expect(!json.contains("api-key"))
        #expect(!json.contains("apikey"))
        #expect(!json.contains("secret"))
    }
}
