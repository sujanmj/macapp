import Foundation
import AppKit

@main
struct UtilitySmokeTests {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MacUtilityTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let a = directory.appendingPathComponent("one.txt")
        let b = directory.appendingPathComponent("two.txt")
        try Data("one".utf8).write(to: a); try Data("two".utf8).write(to: b)
        let shelf = ShelfStore(persist: false)
        shelf.add([a, b, a])
        precondition(shelf.items.count == 2, "Duplicate file references should collapse.")
        precondition(shelf.batch.count == 2, "No selection means all files.")
        shelf.selected = [a.path]
        precondition(shelf.batch.count == 1 && shelf.batch.first?.url == a)
        shelf.removeSelection()
        precondition(FileManager.default.fileExists(atPath: a.path), "Removing a shelf reference must preserve the original.")
        shelf.clear()
        precondition(FileManager.default.fileExists(atPath: b.path), "Clear must preserve originals.")
        let missing = directory.appendingPathComponent("missing.txt")
        shelf.add([missing]); precondition(shelf.batch.isEmpty, "Missing references must not be exported.")
        shelf.clear()
        shelf.add((0..<350).map { directory.appendingPathComponent("\($0).txt") })
        precondition(shelf.items.count == 300, "Shelf inventory must remain bounded.")
        precondition(shelf.message.contains("50 files were not added"), "Capacity limits must be visible; never silently lose inputs.")
        let text = try OpenAIClient.responseText(["status": "completed", "output": [
            ["type": "reasoning", "summary": []],
            ["type": "message", "content": [["type": "output_text", "text": "One"], ["type": "output_text", "text": "Two"]]]
        ]])
        precondition(text == "One\nTwo", "Responses can contain non-message items before text.")
        do { _ = try OpenAIClient.responseText(["status": "incomplete", "output": []]); fatalError("Incomplete output must be rejected.") }
        catch is UtilityError { }
        do { _ = try OpenAIClient.responseText(["status": "completed", "output": []]); fatalError("Empty output must be rejected.") }
        catch is UtilityError { }
        print("PASS: shelf deduplication, selection, reference-only removal/clear, missing-file refusal, inventory cap; Responses text parsing and incomplete/empty refusal.")
    }
}
