import Foundation

/// The sockseek config file is the single source of truth for settings.
/// Only the keys we touch are rewritten; every other line is kept as-is.
struct SockseekConfig {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".config/sockseek/sockseek.conf")
    static let convertHook = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".local/bin/sockseek-convert").path

    var lines: [String]

    static func load() -> SockseekConfig {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return SockseekConfig(lines: text.components(separatedBy: "\n"))
    }

    subscript(key: String) -> String? {
        get {
            guard let v = lines.lazy.compactMap(Self.parse).first(where: { $0.key == key })?.value,
                  v != "CHANGE_ME" else { return nil }
            return v
        }
        set {
            let i = lines.firstIndex { Self.parse($0)?.key == key }
            let v = newValue.flatMap { $0.isEmpty ? nil : $0 }
            switch (i, v) {
            case let (i?, v?): lines[i] = "\(key) = \(v)"
            case let (i?, nil): lines.remove(at: i)
            case let (nil, v?): lines.append("\(key) = \(v)")
            case (nil, nil): break
            }
        }
    }

    var outputFormat: OutputFormat {
        get {
            guard let hook = self["on-complete"] else { return .flac }
            return hook.contains("sockseek-convert wav") ? .wav : .aiff
        }
        set {
            self["on-complete"] = newValue == .flac ? nil
                : "when=success scope=track update-index -- \(Self.convertHook) \(newValue.rawValue) \"{path}\""
        }
    }

    var outputDir: String {
        ((self["output-dir"] ?? "~/Music/Seekify") as NSString).expandingTildeInPath
    }

    var hasSoulseekLogin: Bool { self["username"] != nil && self["password"] != nil }

    func save() throws {
        try FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try lines.joined(separator: "\n").write(to: Self.url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.url.path)
    }

    private static func parse(_ line: String) -> (key: String, value: String)? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.hasPrefix("#"), let eq = t.firstIndex(of: "=") else { return nil }
        return (t[..<eq].trimmingCharacters(in: .whitespaces),
                t[t.index(after: eq)...].trimmingCharacters(in: .whitespaces))
    }
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case aiff, wav, flac
    var id: Self { self }
    var label: String { rawValue.uppercased() }
}
