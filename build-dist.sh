#!/bin/bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────
APP_NAME="Multi-Term"
BUNDLE_ID="com.multiterm.app"
EXECUTABLE="MultiTerminal"
VERSION="1.0.0"
BUILD_DIR=".build/release"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"

echo "══════════════════════════════════════════════"
echo "  Building ${APP_NAME} v${VERSION}"
echo "══════════════════════════════════════════════"

# ─── 1. Build release binary ────────────────────────────────────────────
echo ""
echo "▸ Building release binary..."
swift build -c release 2>&1
echo "  ✓ Binary built at ${BUILD_DIR}/${EXECUTABLE}"

# ─── 2. Create .app bundle ──────────────────────────────────────────────
echo ""
echo "▸ Creating ${APP_NAME}.app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/${EXECUTABLE}" "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE}"

# Copy app icon
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    echo "  ✓ App icon copied"
fi

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
</dict>
</plist>
PLIST

echo "  ✓ App bundle created at ${APP_BUNDLE}"

# ─── 3. Ad-hoc code sign ────────────────────────────────────────────────
echo ""
echo "▸ Ad-hoc code signing..."
codesign --force --deep --sign - "${APP_BUNDLE}" 2>&1 || echo "  ⚠ Code signing skipped (non-fatal)"
echo "  ✓ Signed"

# ─── 4. Create .pkg installer ───────────────────────────────────────────
echo ""
echo "▸ Creating .pkg installer..."
PKG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.pkg"

pkgbuild \
    --root "${APP_BUNDLE}" \
    --identifier "${BUNDLE_ID}" \
    --version "${VERSION}" \
    --install-location "/Applications/${APP_NAME}.app" \
    "${PKG_PATH}" 2>&1

echo "  ✓ Installer created at ${PKG_PATH}"

# ─── 5. Create .zip for direct download ─────────────────────────────────
echo ""
echo "▸ Creating .zip archive..."
ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"
(cd "${DIST_DIR}" && zip -r -y "../${ZIP_PATH}" "${APP_NAME}.app") 2>&1
echo "  ✓ Archive created at ${ZIP_PATH}"

# ─── Summary ────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
echo "  Build complete! Distribution files:"
echo ""
echo "  App:       ${APP_BUNDLE}"
echo "  Installer: ${PKG_PATH}"
echo "  Archive:   ${ZIP_PATH}"
echo ""
echo "  To install manually:"
echo "    cp -R \"${APP_BUNDLE}\" /Applications/"
echo ""
echo "  To install via .pkg:"
echo "    open \"${PKG_PATH}\""
echo "══════════════════════════════════════════════"
