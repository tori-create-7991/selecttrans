#!/bin/bash
# Build SelectTrans and package it as a proper .app bundle.
# A real bundle keeps Accessibility permission stable across rebuilds
# (TCC binds to the bundle id, not the raw binary path).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Building (release)…"
swift build -c release

BIN=".build/release/NaniMini"
APP="SelectTrans.app"
LEGACY_APP="NaniMini.app"
MACOS="$APP/Contents/MacOS"

rm -rf "$APP"
mkdir -p "$MACOS"
cp "$BIN" "$MACOS/NaniMini"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>SelectTrans</string>
    <key>CFBundleDisplayName</key><string>SelectTrans</string>
    <key>CFBundleIdentifier</key><string>com.ryo.nanimini</string>
    <key>CFBundleExecutable</key><string>NaniMini</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# --- Code signing -----------------------------------------------------------
# Sign with a STABLE self-signed identity so the Designated Requirement is tied
# to the certificate (not the per-build cdhash). This keeps Accessibility (TCC)
# and Keychain access alive across rebuilds. Falls back to ad-hoc if the cert
# isn't installed yet.
SIGN_IDENTITY="${SELECTTRANS_SIGN_IDENTITY:-${NANIMINI_SIGN_IDENTITY:-NaniMini Self-Signed}}"

# NOTE: no -v here. A self-signed cert is untrusted (CSSMERR_TP_NOT_TRUSTED) so it
# never appears under "valid identities only", but codesign can still sign with it.
if security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
    echo "==> Signing with stable identity: '$SIGN_IDENTITY'"
    codesign --force --sign "$SIGN_IDENTITY" "$APP"
else
    echo "!! Code-signing identity '$SIGN_IDENTITY' not found — using AD-HOC."
    echo "   (Accessibility + Keychain permission will reset on every rebuild.)"
    echo "   One-time fix: Keychain Access → Certificate Assistant → Create a Certificate"
    echo "     Name='$SIGN_IDENTITY', Identity Type='Self Signed Root', Type='Code Signing'."
    codesign --force --sign - "$APP"
fi

codesign --verify --deep --strict "$APP"

# Keep existing local launch commands working after the public app rename.
rm -rf "$LEGACY_APP"
ln -s "$APP" "$LEGACY_APP"

echo "==> Built $APP"
echo "    Run with:  open $APP"
