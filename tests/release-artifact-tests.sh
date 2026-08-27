#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/OpenCodexTray.app"
WIDGET="$APP/Contents/PlugIns/OpenCodexWidget.appex"

verify_resources() {
  local output
  output="$(perl -e 'alarm shift @ARGV; exec @ARGV' 10 "$@")" \
    || { print -u2 -- "FAIL: resource verification command failed: $*"; exit 1; }
  [[ "$output" == "Resources OK" ]] \
    || { print -u2 -- "FAIL: unexpected resource verification output: $output"; exit 1; }
}

"$ROOT/scripts/build-app.sh" >/dev/null

if strings -a "$APP/Contents/MacOS/OpenCodexTray" | grep -Eq -- '/Users/|\.build/'; then
  print -u2 -- "FAIL: release binary contains a local build path"
  exit 1
fi

verify_resources "$APP/Contents/MacOS/OpenCodexTray" --verify-resources
verify_resources swift run --package-path "$ROOT" -c release --skip-build OpenCodexTray --verify-resources

[[ -x "$WIDGET/Contents/MacOS/OpenCodexWidget" ]] \
  || { print -u2 -- "FAIL: widget extension is not embedded"; exit 1; }
[[ "$(plutil -extract NSExtension.NSExtensionPointIdentifier raw -o - "$WIDGET/Contents/Info.plist")" == "com.apple.widgetkit-extension" ]] \
  || { print -u2 -- "FAIL: widget extension point is invalid"; exit 1; }
codesign --verify --strict "$WIDGET"
nm -u "$WIDGET/Contents/MacOS/OpenCodexWidget" | grep -qx '_NSExtensionMain' \
  || { print -u2 -- "FAIL: widget was not linked as an app extension"; exit 1; }

print -- "PASS: release artifact is path-clean and resolves resources"
