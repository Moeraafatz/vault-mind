#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
APP_NAME="VaultMind"
DISPLAY_NAME="Vault Mind"
BUNDLE_ID="com.moeraafatz.vault-mind"
BUILD_BIN=".build/release/${APP_NAME}"
ICONSET_DIR=".build/AppIcon.iconset"
ICNS_PATH=".build/AppIcon.icns"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_STAGING="${DIST_DIR}/dmg-root"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"

if [[ ! -f "${BUILD_BIN}" ]]; then
  echo "Missing release binary at ${BUILD_BIN}" >&2
  exit 1
fi

rm -rf "${DIST_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources" "${DMG_STAGING}"

if [[ -d "${ICONSET_DIR}" ]]; then
  iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_PATH}"
  cp "${ICNS_PATH}" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

cp "${BUILD_BIN}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
strip -S -x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" || true

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${DISPLAY_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${DISPLAY_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "${APP_BUNDLE}"
codesign --verify --deep --strict "${APP_BUNDLE}"

cp -R "${APP_BUNDLE}" "${DMG_STAGING}/${APP_NAME}.app"
ln -s /Applications "${DMG_STAGING}/Applications"
hdiutil create \
  -volname "${DISPLAY_NAME} ${VERSION}" \
  -srcfolder "${DMG_STAGING}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"
rm -rf "${DMG_STAGING}"

ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

(
  cd "${DIST_DIR}"
  shasum -a 256 "${APP_NAME}-${VERSION}.dmg" "${APP_NAME}-${VERSION}.zip" > SHA256SUMS.txt
)

APP_SIZE=$(du -sh "${APP_BUNDLE}" | awk '{print $1}')
DMG_SIZE=$(du -sh "${DMG_PATH}" | awk '{print $1}')
echo "Packaged ${APP_BUNDLE} (${APP_SIZE}) -> ${DMG_PATH} (${DMG_SIZE})"
cat "${DIST_DIR}/SHA256SUMS.txt"
