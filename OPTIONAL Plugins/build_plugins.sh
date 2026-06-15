#!/bin/bash
# Build all Whisker plugins
# Requires: c3c in PATH
#
# Usage:
#   ./build_plugins.sh          # Build for current platform
#   ./build_plugins.sh linux    # Cross-compile for Linux (from any OS)
#   ./build_plugins.sh windows  # Cross-compile for Windows (from any OS)
#   ./build_plugins.sh all      # Build for both platforms

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Auto-discover plugins: every subdirectory that contains a project.json is a
# buildable plugin (by convention its target/output name matches the folder
# name). Add a new plugin = drop in <name>/project.json + <name>.c3; the build
# (and CI) picks it up automatically — no list to maintain here.
PLUGINS=()
for dir in "$SCRIPT_DIR"/*/; do
    name="$(basename "$dir")"
    if [ -f "$dir/project.json" ]; then
        PLUGINS+=("$name")
    fi
done
echo "Discovered plugins: ${PLUGINS[*]}"

build_native() {
    echo "=== Building plugins for current platform ==="
    for plugin in "${PLUGINS[@]}"; do
        echo "Building $plugin..."
        cd "$SCRIPT_DIR/$plugin"
        c3c build
        # Detect output extension
        if [ -f "out/$plugin.so" ]; then
            cp "out/$plugin.so" "$SCRIPT_DIR/Linux/$plugin.so"
            echo "  -> Linux/$plugin.so"
        elif [ -f "out/$plugin.dll" ]; then
            cp "out/$plugin.dll" "$SCRIPT_DIR/Windows/$plugin.dll"
            echo "  -> Windows/$plugin.dll"
        fi
        rm -rf out build
    done
}

build_linux() {
    echo "=== Building plugins for Linux x64 ==="
    for plugin in "${PLUGINS[@]}"; do
        echo "Building $plugin..."
        cd "$SCRIPT_DIR/$plugin"
        c3c build --target linux-x64
        cp "out/$plugin.so" "$SCRIPT_DIR/Linux/$plugin.so"
        echo "  -> Linux/$plugin.so"
        rm -rf out build
    done
}

build_windows() {
    echo "=== Building plugins for Windows x64 ==="
    for plugin in "${PLUGINS[@]}"; do
        echo "Building $plugin..."
        # Build from the plugin's own dir (keeps the generated headers/ out of
        # OPTIONAL Plugins/headers/). NOTE: we do NOT use the project.json here,
        # because it links libc as "c" — required on Linux, but MSVC (used for
        # the windows-x64 cross-compile) has no c.lib and links its CRT
        # implicitly. So build with a plain dynamic-lib and no -l c.
        cd "$SCRIPT_DIR/$plugin"
        c3c dynamic-lib "../$plugin.c3" --target windows-x64 -o "out/$plugin"
        cp "out/$plugin.dll" "$SCRIPT_DIR/Windows/$plugin.dll"
        echo "  -> Windows/$plugin.dll"
        rm -rf out build headers
    done
}

case "${1:-native}" in
    native)  build_native ;;
    linux)   build_linux ;;
    windows) build_windows ;;
    all)     build_linux; build_windows ;;
    *)       echo "Usage: $0 [native|linux|windows|all]"; exit 1 ;;
esac

echo "=== Done ==="
