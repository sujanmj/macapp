import Foundation

@main struct GeminiTests {
    static func main() throws {
        let response: [String: Any] = ["candidates": [["finishReason": "STOP", "content": ["parts": [["thought": true, "text": "hidden reasoning"], ["text": "Hello"], ["text": "World"]]]]], "usageMetadata": ["promptTokenCount": 5, "candidatesTokenCount": 7, "totalTokenCount": 16]]
        let result = try GeminiClient.parse(response)
        precondition(result.text == "Hello\nWorld", "Thought content must not be displayed.")
        precondition(result.inputTokens == 5 && result.outputTokens == 7 && result.totalTokens == 16, "Total usage includes provider-reported reasoning; do not infer it from visible text.")
        let missing = try GeminiClient.parse(["candidates": [["finishReason": "STOP", "content": ["parts": [["text": "OK"]]]]]])
        precondition(missing.totalTokens == nil, "Unknown usage must not become zero.")
        for reason in ["MAX_TOKENS", "SAFETY"] {
            do { _ = try GeminiClient.parse(["candidates": [["finishReason": reason, "content": ["parts": [["text": "partial"]]]]]]); fatalError("Incomplete/blocked output accepted") }
            catch is UtilityError { }
        }
        do { _ = try GeminiClient.parse([:]); fatalError("Empty response accepted") }
        catch is UtilityError { }
        precondition(GeminiKeyStore.service != APIKeyStore.service, "Never send an OpenAI key to Google.")
        print("PASS: Gemini text/thought parsing, real usage totals, missing usage, incomplete/blocked refusal, provider key separation.")
    }
}
