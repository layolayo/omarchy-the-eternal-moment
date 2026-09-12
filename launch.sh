#!/bin/sh
set -eu
export PATH="/usr/bin:/bin"
DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
APP="$DIR/App.qml"
if [ ! -f "$APP" ]; then
    echo "Error: App.qml not found at $APP" >&2
    exit 1
fi
if [ -x "/usr/bin/quickshell" ]; then
    exec /usr/bin/quickshell -p "$APP" "$@"
elif [ -x "/usr/bin/qml6" ]; then
    exec /usr/bin/qml6 "$APP" "$@"
else
    echo "Error: No verified absolute runtime (/usr/bin/quickshell or /usr/bin/qml6) found." >&2
    exit 1
fi
