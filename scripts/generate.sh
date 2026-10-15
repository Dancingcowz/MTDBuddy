#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen not found — installing via Homebrew..."
  brew install xcodegen
fi

if [ ! -f Secrets.xcconfig ]; then
  echo "Secrets.xcconfig is missing. Copy Secrets.xcconfig.example to Secrets.xcconfig and fill in your MTD API key." >&2
  exit 1
fi

xcodegen generate
echo "Generated MTDBuddy.xcodeproj"
