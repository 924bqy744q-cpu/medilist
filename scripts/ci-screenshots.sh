#!/usr/bin/env bash
# Installs the built app on a booted simulator, launches it in each demo state and takes a screenshot.
# Demo states are driven by launch arguments handled in AppEnvironment (DEBUG builds only).
set -uo pipefail
UDID="$1"; DERIVED="$2"; OUT="$3"
mkdir -p "$OUT"
APP=$(find "$DERIVED/Build/Products" -name "MedList.app" -path "*iphonesimulator*" | head -1)
[ -z "$APP" ] && { echo "app not built"; exit 0; }
xcrun simctl boot "$UDID" 2>/dev/null || true
perl -e 'alarm 180; exec @ARGV' xcrun simctl bootstatus "$UDID" -b || true
perl -e 'alarm 120; exec @ARGV' xcrun simctl install "$UDID" "$APP" || exit 0
BUNDLE=app.medlist.MedList
shot() {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  perl -e 'alarm 30; exec @ARGV' xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null || { echo "launch failed: $name"; return; }
  sleep 4
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null && echo "saved $name"
}
shot 01-onboarding -uitest-reset
shot 02-list-en -uitest-reset -uitest-seed -AppleLanguages "(en)"
shot 03-list-nl -uitest-reset -uitest-seed -AppleLanguages "(nl)"
shot 04-flags -uitest-reset -uitest-seed -uitest-open flags
shot 05-confirm -uitest-reset -uitest-seed -uitest-open confirm
shot 06-export -uitest-reset -uitest-seed -uitest-open export
shot 07-large-text -uitest-reset -uitest-seed -UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL
exit 0
