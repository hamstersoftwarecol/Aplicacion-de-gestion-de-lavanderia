#!/usr/bin/env bash
# Source in this cloud environment; HOME remains unchanged.
export PATH="/workspace/toolchains/flutter/bin:$PATH"
export PUB_CACHE=/workspace/toolchains/pub-cache
export XDG_CONFIG_HOME=/workspace/toolchains/config
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
mkdir -p "$PUB_CACHE" "$XDG_CONFIG_HOME"

export ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/toolchains/analyzer
