#!/bin/sh
set -eu
export PATH="/usr/bin:/bin"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.layolayo.eternal-moment"
if [ -x "$PLUGIN_DIR/launch.sh" ]; then
    exec "$PLUGIN_DIR/launch.sh" "$@"
else
    echo "Error: The Eternal Moment plugin not found at $PLUGIN_DIR" >&2
    exit 1
fi
