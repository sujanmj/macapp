import SwiftUI
import CryptoKit

struct DeveloperTools: View {
    @State private var input = ""
    @State private var output = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Developer tools", systemImage: "curlybraces").font(.headline)
                Spacer()
                Button("UUID") { output = UUID().uuidString.lowercased() }
                Button("Unix time") { output = String(Int(Date().timeIntervalSince1970)) }
            }
            TextEditor(text: $input).font(.system(.caption, design: .monospaced)).frame(height: 70)
                .scrollContentBackground(.hidden).padding(8).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Button("Format JSON") {
                    do {
                        let value = try JSONSerialization.jsonObject(with: Data(input.utf8), options: [.fragmentsAllowed])
                        output = String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]), as: UTF8.self)
                    } catch { output = "Invalid JSON: " + error.localizedDescription }
                }
                Button("SHA-256") { output = SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined() }
                Button("Copy result") { copyText(output) }.disabled(output.isEmpty)
                Spacer()
                Button("Clear") { input = ""; output = "" }
            }
            ScrollView { Text(output.isEmpty ? "Local tools. Paste text above; nothing is uploaded." : output).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 75)
        }
    }
}

struct NotchControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.white.opacity(configuration.isPressed ? 0.16 : 0.07), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
