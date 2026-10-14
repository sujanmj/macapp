import Foundation
import Security
import SwiftUI

struct UtilityError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum APIKeyStore {
    static var service: String { (Bundle.main.bundleIdentifier ?? "com.sujanmj.utility") + ".openai" }
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

/// No analytics, automatic retries, key logging, or background requests.
struct OpenAIClient {
    static func request(path: String) throws -> URLRequest {
        guard let key = APIKeyStore.read(), !key.isEmpty else { throw UtilityError(message: "Add your OpenAI API key in Settings first.") }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/" + path)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        return request
    }
    static func json(_ request: URLRequest) async throws -> [String: Any] {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 120
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UtilityError(message: "Invalid server response.") }
        guard (200..<300).contains(http.statusCode) else {
            // Do not echo server bodies: they may contain submitted private text.
            throw UtilityError(message: "OpenAI request failed (HTTP \(http.statusCode)). Check your key, model access, billing and connection.")
        }
        guard data.count < 10_000_000,
              let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw UtilityError(message: "Invalid response data.") }
        return value
    }
    struct TextResult {
        let text: String
        let inputTokens: Int?
        let outputTokens: Int?
    }
    static func text(input: String, instruction: String, model: String = "gpt-4.1-mini") async throws -> String {
        try await textWithUsage(input: input, instruction: instruction, model: model).text
    }
    static func textWithUsage(input: String, instruction: String, model: String = "gpt-4.1-mini") async throws -> TextResult {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, input.utf8.count < 100_000 else {
            throw UtilityError(message: "Enter text shorter than 100 KB.")
        }
        var request = try request(path: "responses")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "input": input, "instructions": instruction,
                                                                       "store": false, "max_output_tokens": 2048])
        let response = try await json(request)
        return try responseResult(response)
    }
    static func responseResult(_ response: [String: Any]) throws -> TextResult {
        let usage = response["usage"] as? [String: Any]
        return TextResult(text: try responseText(response), inputTokens: usage?["input_tokens"] as? Int,
                          outputTokens: usage?["output_tokens"] as? Int)
    }
    static func responseText(_ response: [String: Any]) throws -> String {
        guard response["status"] as? String == "completed" else { throw UtilityError(message: "The response was incomplete. Shorten the request and try again.") }
        let output = response["output"] as? [[String: Any]] ?? []
        let texts = output.flatMap { $0["content"] as? [[String: Any]] ?? [] }
            .filter { $0["type"] as? String == "output_text" }.compactMap { $0["text"] as? String }
        let result = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw UtilityError(message: "The model did not return text.") }
        return result
    }
    static func transcribe(file: URL, vocabulary: String) async throws -> String {
        let audio = try Data(contentsOf: file)
        guard !audio.isEmpty, audio.count < 24_000_000 else { throw UtilityError(message: "Audio is empty or larger than the 24 MB limit.") }
        var request = try request(path: "audio/transcriptions")
        let boundary = "MacVoice-" + UUID().uuidString
        request.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")
        var body = Data()
        func append(_ text: String) { body.append(Data(text.utf8)) }
        for (key, value) in [("model", "gpt-4o-transcribe"), ("response_format", "json"), ("prompt", String(vocabulary.prefix(2000)))] {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n")
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"dictation.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n")
        body.append(audio); append("\r\n--\(boundary)--\r\n")
        request.httpBody = body
        let response = try await json(request)
        guard let text = response["text"] as? String else { throw UtilityError(message: "No transcript returned.") }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct APISettingsView: View {
    @State private var key = ""
    @State private var status = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Optional OpenAI connection").font(.headline)
            Text("Uses your own API key and API billing, separate from ChatGPT subscriptions. Only Send / AI Edit / cloud dictation sends content. Responses use store=false; provider data policies still apply.").font(.caption).foregroundStyle(.secondary)
            SecureField("OpenAI API key", text: $key)
            HStack {
                Button("Save in Keychain") {
                    do { try APIKeyStore.save(key); key = ""; status = "Saved in this app’s Keychain entry." }
                    catch { status = error.localizedDescription }
                }
                Button("Remove Key") { APIKeyStore.delete(); key = ""; status = "Removed." }
            }
            Text(status).font(.caption)
        }
    }
}
