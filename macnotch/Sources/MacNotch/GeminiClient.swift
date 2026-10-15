import Foundation
import Security
import SwiftUI

enum GeminiKeyStore {
    static var service: String { (Bundle.main.bundleIdentifier ?? "com.sujanmj.utility") + ".gemini" }
    static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "api-key"]
    }
    static func read() -> String? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ key: String) throws {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw UtilityError(message: "Enter an API key.") }
        let update = [kSecValueData as String: Data(clean.utf8)]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; q[kSecValueData as String] = Data(clean.utf8)
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let created = SecItemAdd(q as CFDictionary, nil)
            guard created == errSecSuccess else { throw UtilityError(message: "Keychain refused saving the key (\(created)).") }
        } else if status != errSecSuccess { throw UtilityError(message: "Keychain refused updating the key (\(status)).") }
    }
    static func delete() { SecItemDelete(query as CFDictionary) }
}

struct GeminiClient {
    struct Result { let text: String; let inputTokens: Int?; let outputTokens: Int?; let totalTokens: Int? }
    static func parse(_ json: [String: Any]) throws -> Result {
        guard let candidates = json["candidates"] as? [[String: Any]], let first = candidates.first,
              first["finishReason"] as? String == "STOP",
              let content = first["content"] as? [String: Any], let parts = content["parts"] as? [[String: Any]] else {
            throw UtilityError(message: "Gemini did not complete an answer. The request may be blocked or incomplete; try a shorter question.")
        }
        let text = parts.filter { ($0["thought"] as? Bool) != true }.compactMap { $0["text"] as? String }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw UtilityError(message: "Gemini returned no answer text.") }
        let usage = json["usageMetadata"] as? [String: Any]
        return Result(text: text, inputTokens: usage?["promptTokenCount"] as? Int,
                      outputTokens: usage?["candidatesTokenCount"] as? Int, totalTokens: usage?["totalTokenCount"] as? Int)
    }
    static func ask(_ input: String, model: String) async throws -> Result {
        guard input.utf8.count < 100_000, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw UtilityError(message: "Enter a question shorter than 100 KB.") }
        guard model.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else { throw UtilityError(message: "Enter a valid Gemini model name in Settings.") }
        guard let key = GeminiKeyStore.read() else { throw UtilityError(message: "Add your Gemini API key in Settings, or use Open Gemini to chat on the web.") }
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent")!)
        request.httpMethod = "POST"; request.timeoutInterval = 90
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["contents": [["role": "user", "parts": [["text": input]]]], "generationConfig": ["maxOutputTokens": 4096]])
        let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForResource = 120
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw UtilityError(message: "Gemini request failed (HTTP \(code)). Check your Google API key, model access, billing and limits.")
        }
        guard data.count < 10_000_000, let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw UtilityError(message: "Invalid Gemini response.") }
        return try parse(json)
    }
}

struct GeminiSettings: View {
    @State private var key = ""
    @State private var status = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gemini").font(.headline)
            SecureField("Google AI Studio API key", text: $key)
            HStack {
                Button("Save key") {
                    do { try GeminiKeyStore.save(key); key = ""; status = "Gemini key saved in Keychain." }
                    catch { status = error.localizedDescription }
                }
                Button("Remove key") { GeminiKeyStore.delete(); key = ""; status = "Gemini key removed." }
                Link("Google AI Studio", destination: URL(string: "https://aistudio.google.com/apikey")!)
            }
            Text(status).font(.caption)
            Text("Ask sends only your typed question to Google. Uses a separate Gemini API key and API billing; a Gemini web subscription does not include API billing. Nothing is uploaded automatically.").font(.caption)
        }
    }
}
