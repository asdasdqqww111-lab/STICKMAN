#!/usr/bin/env bash
# Builds the Android debug APK with the pinned Godot version.
#
# Expects: GOPATH-free environment with
#   GODOT_BIN          - Godot editor binary
#   ANDROID_SDK_ROOT   - Android SDK (cmdline-tools + build-tools + platform 35)
#   JAVA_HOME          - JDK 17
set -euo pipefail

GODOT="${GODOT_BIN:-godot}"
GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
OUT_DIR="${OUT_DIR:-build}"
mkdir -p "$OUT_DIR"

echo "==> Godot: $("$GODOT" --version)"
echo "==> Java: $("$JAVA_HOME/bin/java" -version 2>&1 | head -1)"
echo "==> SDK: ${ANDROID_SDK_ROOT}"
ls "${ANDROID_SDK_ROOT}/build-tools" || true

# Point the editor at the toolchain non-interactively (editor settings file).
SETTINGS_DIR="${HOME}/.config/godot"
mkdir -p "$SETTINGS_DIR"
cat > "${SETTINGS_DIR}/editor_settings-4.7.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "${JAVA_HOME}"
export/android/android_sdk_path = "${ANDROID_SDK_ROOT}"
export/android/debug_keystore = "${HOME}/.android/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/force_system_user = false
export/android/shutdown_adb_on_exit = true
SETTINGS

if [ ! -f "${HOME}/.android/debug.keystore" ]; then
  echo "==> creating debug keystore"
  mkdir -p "${HOME}/.android"
  keytool -genkeypair -v \
    -keystore "${HOME}/.android/debug.keystore" -storepass android -keypass android \
    -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US"
fi

echo "==> importing project"
"$GODOT" --headless --path . --import 2>&1 | tail -5

echo "==> exporting APK"
set +e
"$GODOT" --headless --path . --verbose \
  --export-debug "Android Debug" "${OUT_DIR}/microworld-living-debug.apk" 2>&1 | tee export.log | tail -40
STATUS=${PIPESTATUS[0]}
set -e

if [ ! -s "${OUT_DIR}/microworld-living-debug.apk" ]; then
  echo "!! APK was not produced (godot exit ${STATUS})"
  exit 1
fi
echo "==> APK produced:"
ls -la "${OUT_DIR}/microworld-living-debug.apk"
