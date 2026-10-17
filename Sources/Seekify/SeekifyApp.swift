import AppKit
import SwiftUI

@main
struct SeekifyApp: App {
    @State private var runner = Runner()

    init() {
        // Launched as a bare SwiftPM binary there's no bundle telling macOS this is a regular app.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(runner)
                .frame(minWidth: 640, minHeight: 520)
        }
        .windowToolbarStyle(.unified)
        Settings { SettingsView() }
    }
}

struct ContentView: View {
    @Environment(Runner.self) private var runner
    @State private var url = ""
    @State private var showLog = false
    @State private var config = SockseekConfig.load()

    var body: some View {
        VStack(spacing: 0) {
            if !config.hasSoulseekLogin {
                banner("Add your Soulseek login in Settings to start downloading.")
            } else if config["spotify-id"] == nil || config["spotify-secret"] == nil {
                banner("Add your Spotify app ID and secret in Settings to read playlists.")
            }
            inputBar
            Divider()
            if runner.tracks.isEmpty {
                emptyState
            } else {
                progressHeader
                List(runner.tracks) { TrackRow(track: $0) }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            Divider()
            footer
            if showLog { logView }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            config = SockseekConfig.load()  // pick up changes saved in Settings
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "link").foregroundStyle(.secondary)
            TextField("Paste a Spotify playlist or album link", text: $url)
                .textFieldStyle(.plain)
                .font(.title3)
                .onSubmit { runner.start(url.trimmingCharacters(in: .whitespaces)) }
            if runner.isRunning {
                Button("Stop", role: .cancel) { runner.stop() }
            } else {
                Button("Liked Songs") { runner.start("spotify-likes") }
                Button("Download") { runner.start(url.trimmingCharacters(in: .whitespaces)) }
                    .buttonStyle(.borderedProminent)
                    .disabled(url.isEmpty)
            }
        }
        .controlSize(.large)
        .disabled(!config.hasSoulseekLogin && !runner.isRunning)
        .padding(14)
    }

    private var progressHeader: some View {
        let total = max(runner.total, runner.tracks.count)
        let finished = runner.doneCount + runner.failedCount
        return VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: Double(finished), total: Double(max(total, 1)))
            HStack {
                Label("\(runner.doneCount) downloaded", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Label("\(runner.failedCount) not found", systemImage: "xmark.circle.fill").foregroundStyle(.secondary)
                Spacer()
                Text(runner.isRunning ? "\(finished) of \(total)" : "Finished")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(runner.isRunning ? "Loading playlist…" : "Nothing downloading", systemImage: "music.note.list")
        } description: {
            Text("Paste a Spotify link above or grab your Liked Songs.\nTracks are fetched from Soulseek as \(config.outputFormat.label).")
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button("Retry Failed", systemImage: "arrow.clockwise") { runner.retry() }
                .disabled(runner.isRunning || runner.failedCount == 0)
            Button("Show in Finder", systemImage: "folder") {
                NSWorkspace.shared.open(URL(filePath: config.outputDir))
            }
            Spacer()
            Toggle("Log", isOn: $showLog.animation()).toggleStyle(.button)
            SettingsLink { Image(systemName: "gearshape") }
        }
        .padding(10)
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(runner.log.suffix(400).joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .id("end")
            }
            .frame(height: 160)
            .background(.black.opacity(0.04))
            .onChange(of: runner.log.count) { proxy.scrollTo("end", anchor: .bottom) }
        }
    }

    private func banner(_ text: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(text)
            Spacer()
            SettingsLink { Text("Open Settings") }
        }
        .padding(10)
        .background(.yellow.opacity(0.12))
    }
}

struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: 10) {
            icon.frame(width: 18)
            Text(track.name).lineLimit(1)
                .foregroundStyle(track.state == .failed ? .secondary : .primary)
            Spacer()
            Text(status).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var icon: some View {
        switch track.state {
        case .searching, .downloading, .converting: ProgressView().controlSize(.small)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "xmark.circle").foregroundStyle(.red)
        }
    }

    private var status: String {
        switch track.state {
        case .searching: "Searching"
        case .downloading: "Downloading"
        case .converting: "Converting"
        case .done: "Done"
        case .failed: track.detail ?? "Failed"
        }
    }
}

struct SettingsView: View {
    @State private var config = SockseekConfig.load()
    @State private var username = ""
    @State private var password = ""
    @State private var spotifyID = ""
    @State private var spotifySecret = ""
    @State private var outputDir = ""
    @State private var format = OutputFormat.aiff
    @State private var saved = false

    var body: some View {
        Form {
            Section("Soulseek") {
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
                Text("No sign-up needed: an unused username + password registers on first login. Quit SoulseekQt while downloading if it uses the same account.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Spotify") {
                TextField("Client ID", text: $spotifyID)
                SecureField("Client secret", text: $spotifySecret)
                Text("Create an app at [developer.spotify.com](https://developer.spotify.com/dashboard) with redirect URI `http://127.0.0.1:48721/callback`. The app owner needs Premium. Your first download opens a browser to log in.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Output") {
                HStack {
                    TextField("Folder", text: $outputDir)
                    Button("Choose…", action: chooseFolder)
                }
                Picker("Format", selection: $format) {
                    ForEach(OutputFormat.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Only lossless sources (FLAC/AIFF/WAV) are downloaded; MP3s are never accepted.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                if saved { Text("Saved").foregroundStyle(.secondary) }
                Button("Save", action: save).keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .onAppear(perform: load)
    }

    private func load() {
        config = SockseekConfig.load()
        username = config["username"] ?? ""
        password = config["password"] ?? ""
        spotifyID = config["spotify-id"] ?? ""
        spotifySecret = config["spotify-secret"] ?? ""
        outputDir = config.outputDir
        format = config.outputFormat
    }

    private func save() {
        config["username"] = username
        config["password"] = password
        config["spotify-id"] = spotifyID
        config["spotify-secret"] = spotifySecret
        config["output-dir"] = outputDir
        config.outputFormat = format
        // Defaults the app relies on, only if the file doesn't set them already.
        if config["format"] == nil { config["format"] = "flac,aiff,aif,wav" }
        if config["pref-format"] == nil { config["pref-format"] = "flac" }
        if config["name-format"] == nil {
            config["name-format"] = "{default-folder}/{sartist( - )stitle|artist( - )title|slsk-filename}"
        }
        do { try config.save(); saved = true } catch { NSSound.beep() }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { outputDir = url.path }
    }
}
