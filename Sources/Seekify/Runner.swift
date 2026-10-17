import Foundation
import Observation

struct Track: Identifiable {
    enum State { case searching, downloading, converting, done, failed }
    let id: String  // sockseek job number, e.g. "014"
    var name: String
    var state: State
    var detail: String?
}

/// Runs the sockseek CLI and turns its log lines into a per-track list.
@MainActor @Observable
final class Runner {
    static let sockseek = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin/sockseek")

    var tracks: [Track] = []
    var total = 0
    var log: [String] = []
    var isRunning = false
    private(set) var lastInput: String?
    private var process: Process?
    private var buffer = ""

    var doneCount: Int { tracks.count { $0.state == .done } }
    var failedCount: Int { tracks.count { $0.state == .failed } }

    func start(_ input: String) {
        guard !isRunning, !input.isEmpty else { return }
        tracks = []; total = 0; log = []; buffer = ""; lastInput = input

        let p = Process()
        p.executableURL = Self.sockseek
        p.arguments = [input, "--write-playlist"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        let reader = pipe.fileHandleForReading
        reader.readabilityHandler = { h in
            let data = h.availableData
            guard !data.isEmpty else { h.readabilityHandler = nil; return }  // EOF
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in self.ingest(text) }
        }
        p.terminationHandler = { _ in
            Task { @MainActor in
                self.isRunning = false
                self.process = nil
            }
        }
        do {
            try p.run()
            process = p
            isRunning = true
        } catch {
            log.append("Couldn't start sockseek at \(Self.sockseek.path): \(error.localizedDescription)")
        }
    }

    func stop() { process?.terminate() }

    /// sockseek's index skips tracks that already succeeded, so a re-run only retries the misses.
    func retry() { if let lastInput { start(lastInput) } }

    func ingest(_ chunk: String) {
        buffer += chunk
        while let nl = buffer.firstIndex(of: "\n") {
            handle(String(buffer[..<nl]))
            buffer.removeSubrange(...nl)
        }
    }

    private func handle(_ line: String) {
        log.append(line)
        if log.count > 2000 { log.removeFirst(log.count - 2000) }

        if let m = line.firstMatch(of: /Downloading (\d+) tracks/) { total = Int(m.1) ?? total }
        // ponytail: token line format unverified until a real Spotify login; loose match, check the log if it misses
        if let m = line.firstMatch(of: /(?i)refresh[ _-]?token\W+([A-Za-z0-9_\-]{20,})/) {
            var config = SockseekConfig.load()
            config["spotify-refresh"] = String(m.1)
            try? config.save()
        }

        guard let m = line.firstMatch(of: /^\[(\d+)\] SongJob: ([a-z-]+)(?: \[([^\]]*)\])?: (.*)$/) else { return }
        let state: Track.State
        switch m.2 {
        case "searching": state = .searching
        case "downloading": state = .downloading
        case "on-complete": state = .converting
        case "succeeded": state = .done
        case "failed": state = .failed
        case let s where s.contains("skip"): state = .done
        default: return
        }
        // "Artist - Title: user\..\path\file.flac" -> "Artist - Title"
        var name = String(m.4)
        if let r = name.range(of: ": ", options: .backwards), name[r.upperBound...].contains("\\") {
            name = String(name[..<r.lowerBound])
        }
        let detail = m.3.map(String.init)
        if let i = tracks.firstIndex(where: { $0.id == String(m.1) }) {
            tracks[i].state = state
            tracks[i].detail = detail
        } else {
            tracks.append(Track(id: String(m.1), name: name, state: state, detail: detail))
        }
    }
}
