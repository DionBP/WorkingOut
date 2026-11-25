#!/bin/bash
set -euo pipefail

device="$1"
app="$2"
output="$3"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")"

xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$app"
mkdir -p "$output"
data_container="$(xcrun simctl get_app_container "$device" "$bundle_id" data)"
ready="$data_container/tmp/workingout-screenshot-ready"

capture() {
  local screen="$1" file="$2"
  rm -f "$ready"
  SIMCTL_CHILD_WORKINGOUT_SCREENSHOTS=1 SIMCTL_CHILD_WORKINGOUT_SCREEN="$screen" \
    xcrun simctl launch --terminate-running-process "$device" "$bundle_id" \
    -workingout.language en -appAppearance light -workingout.progress.range 0
  for attempt in {1..90}; do
    if [[ -f "$ready" && "$(cat "$ready")" == "$screen" ]]; then
      break
    fi
    sleep 1
  done
  if [[ ! -f "$ready" || "$(cat "$ready")" != "$screen" ]]; then
    echo "::error::The $screen screen did not signal that it rendered."
    return 1
  fi
  xcrun simctl io "$device" screenshot "$output/$file.png"
}

capture overview 01-Overview
capture training 02-Training
capture strength 03-Strength
capture running 04-Running
xcrun simctl terminate "$device" "$bundle_id"
