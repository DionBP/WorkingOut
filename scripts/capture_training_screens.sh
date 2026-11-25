#!/bin/bash
set -euo pipefail

device="$1"
app="$2"
output="$3"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")"

xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$app"
mkdir -p "$output"

capture() {
  local screen="$1" file="$2"
  SIMCTL_CHILD_WORKINGOUT_SCREENSHOTS=1 SIMCTL_CHILD_WORKINGOUT_SCREEN="$screen" \
    xcrun simctl launch --terminate-running-process "$device" "$bundle_id" \
    -workingout.language en -appAppearance light -workingout.progress.range 0
  sleep 4
  xcrun simctl io "$device" screenshot "$output/$file.png"
}

capture overview 01-Overview
capture training 02-Training
capture strength 03-Strength
capture running 04-Running
xcrun simctl terminate "$device" "$bundle_id"
