#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v quickshell >/dev/null 2>&1; then
    exec quickshell -p "$DIR/App.qml" "$@"
else
    exec qml6 "$DIR/App.qml" "$@"
fi
