#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"

FLUTTER_DIR="${HOME}/flutter"
FLUTTER_BIN="${FLUTTER_DIR}/bin/flutter"

if [ ! -x "${FLUTTER_BIN}" ]; then
  mkdir -p "${HOME}"
  cd "${HOME}"
  rm -rf "${FLUTTER_DIR}"

  RELEASES_JSON_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
  FLUTTER_URL="$(python3 - <<'PY'
import json, sys, urllib.request
url = "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
data = json.loads(urllib.request.urlopen(url, timeout=30).read().decode("utf-8"))
base_url = data["base_url"]
stable_hash = data["current_release"]["stable"]
stable_release = next(r for r in data["releases"] if r["hash"] == stable_hash)
print(f"{base_url}/{stable_release['archive']}")
PY
)"

  curl -L "${FLUTTER_URL}" -o flutter.tar.xz
  tar -xf flutter.tar.xz
  rm -f flutter.tar.xz
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter --version
flutter config --enable-web

cd "${MOBILE_DIR}"
flutter pub get
flutter build web --release
