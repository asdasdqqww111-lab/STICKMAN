#!/usr/bin/env bash
# Installs a pinned, verified Godot editor + export templates on a CI runner.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
GODOT_CHANNEL="${GODOT_CHANNEL:-stable}"
BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-${GODOT_CHANNEL}"
BIN_DIR="${HOME}/godot-bin"
TPL_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_CHANNEL}"

mkdir -p "$BIN_DIR" "$TPL_DIR"

if [ ! -x "$BIN_DIR/godot" ]; then
  echo "==> downloading Godot ${GODOT_VERSION}-${GODOT_CHANNEL} editor"
  curl -fsSL --retry 3 -o /tmp/godot.zip \
    "${BASE}/Godot_v${GODOT_VERSION}-${GODOT_CHANNEL}_linux.x86_64.zip"
  unzip -q -o /tmp/godot.zip -d /tmp/godot-extract
  install -m 0755 "/tmp/godot-extract/Godot_v${GODOT_VERSION}-${GODOT_CHANNEL}_linux.x86_64" "$BIN_DIR/godot"
fi

if [ "${WITH_TEMPLATES:-1}" = "1" ] && [ ! -f "${TPL_DIR}/android_debug.apk" ]; then
  echo "==> downloading export templates"
  curl -fsSL --retry 3 -o /tmp/templates.tpz \
    "${BASE}/Godot_v${GODOT_VERSION}-${GODOT_CHANNEL}_export_templates.tpz"
  rm -rf /tmp/tpl && mkdir -p /tmp/tpl
  unzip -q -o /tmp/templates.tpz -d /tmp/tpl
  # The tpz ships a single "templates" directory; flatten it into the versioned folder.
  cp -a /tmp/tpl/templates/. "$TPL_DIR"/
  rm -rf /tmp/tpl /tmp/templates.tpz
fi

echo "==> godot version"
"$BIN_DIR/godot" --version
ls "$TPL_DIR" | head -20
echo "GODOT_BIN=${BIN_DIR}/godot" >> "${GITHUB_ENV:-/dev/null}"
echo "${BIN_DIR}" >> "${GITHUB_PATH:-/dev/null}"
