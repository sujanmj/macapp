import Foundation

func require(_ condition: Bool, _ message: String) {
    guard condition else { fatalError(message) }
}

@main
struct TrayTransferChecks {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MacNotchTrayTransfer-\(UUID().uuidString)", isDirectory: true)
        let sourceFolder = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = sourceFolder.appendingPathComponent("report.txt")
        try Data("original".utf8).write(to: source)
        let existing = destination.appendingPathComponent("report.txt")
        try Data("keep existing".utf8).write(to: existing)

        let result = TrayTransfer.copy([source, source], to: destination)
        require(result.failures.isEmpty, "Valid files should copy successfully")
        require(result.copied.map(\.lastPathComponent) == ["report (2).txt", "report (3).txt"], "Name collisions should use stable numbered names")
        require(try String(contentsOf: existing, encoding: .utf8) == "keep existing", "Existing destination must never be overwritten")
        require(try String(contentsOf: source, encoding: .utf8) == "original", "Source must remain unchanged")

        let nestedDestination = sourceFolder.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDestination, withIntermediateDirectories: true)
        let nestedResult = TrayTransfer.copy([sourceFolder], to: nestedDestination)
        require(nestedResult.copied.isEmpty && nestedResult.failures.count == 1, "Copying a folder into itself must be rejected")
        print("MacNotch tray transfer checks passed")
    }
}
