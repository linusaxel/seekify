#!/bin/sh
# Build Seekify.app and install it to ~/Applications (+ the convert hook to ~/.local/bin).
set -e
cd "$(dirname "$0")"
mkdir -p ~/.local/bin
install -m 755 sockseek-convert ~/.local/bin/sockseek-convert
swift build -c release
app=~/Applications/Seekify.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/Seekify "$app/Contents/MacOS/"
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Seekify</string>
  <key>CFBundleExecutable</key><string>Seekify</string>
  <key>CFBundleIdentifier</key><string>local.lier.seekify</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF
codesign --force --sign - "$app"
echo "Installed $app"
