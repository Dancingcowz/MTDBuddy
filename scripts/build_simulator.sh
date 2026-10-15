#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/generate.sh

xcodebuild -project MTDBuddy.xcodeproj -scheme MTDBuddy -configuration Debug \
  -destination "generic/platform=iOS Simulator" build
