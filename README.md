# Seekify

Mac app: paste a Spotify playlist (or grab Liked Songs) and download every track from Soulseek in lossless quality, saved as AIFF, WAV or FLAC and named `Artist - Title`.

A SwiftUI front end for [sockseek](https://github.com/fiso64/sockseek) (formerly slsk-batchdl). MP3s are never accepted.

## Requirements

- macOS 14+, Xcode / Swift 6
- `sockseek` at `~/.local/bin/sockseek` (osx-arm64 build from its releases page)
- `ffmpeg` (`brew install ffmpeg`), used to convert FLAC → AIFF/WAV
- A Soulseek account (any unused username + password registers on first login)
- A Spotify developer app with redirect URI `http://127.0.0.1:48721/callback`. The app owner needs Spotify Premium.

## Install

```sh
./build.sh   # builds ~/Applications/Seekify.app and installs the convert hook
```

Then open Seekify → Settings (⌘,) and fill in Soulseek + Spotify credentials. They're stored in sockseek's own config, `~/.config/sockseek/sockseek.conf`, so the `sockseek` CLI uses the same settings.

## How it works

- Runs `sockseek <playlist> --write-playlist` and parses its log into the per-track list.
- `sockseek-convert` is a sockseek on-complete hook that converts each downloaded FLAC (keeping bit depth, tags and cover) and deletes the original.
- **Retry Failed** re-runs the same playlist. sockseek's index skips tracks that already succeeded.

Tests: `swift test`
