#!/bin/bash
# Build script for Chess Puzzle game
# Exports for Windows, macOS, and Linux

set -e

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/builds"

echo "=== Chess Puzzle Build Script ==="
echo "Project directory: $PROJECT_DIR"
echo ""

# Check if Godot is available
if [ ! -f "$GODOT" ]; then
    echo "ERROR: Godot not found at $GODOT"
    echo "Please install Godot 4.5.1 or update the GODOT path in this script."
    exit 1
fi

# Check if export templates are installed
TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates/4.5.1.stable"
if [ ! -d "$TEMPLATES_DIR" ] || [ -z "$(ls -A "$TEMPLATES_DIR" 2>/dev/null)" ]; then
    echo "WARNING: Export templates not found!"
    echo ""
    echo "To install export templates:"
    echo "1. Open Godot Editor"
    echo "2. Go to Editor > Manage Export Templates"
    echo "3. Click 'Download and Install'"
    echo ""
    echo "Or download manually from:"
    echo "https://godotengine.org/download/archive/4.5.1-stable/"
    echo ""
    echo "Templates should be installed to:"
    echo "$TEMPLATES_DIR"
    exit 1
fi

# Create build directories
mkdir -p "$BUILD_DIR/windows"
mkdir -p "$BUILD_DIR/macos"
mkdir -p "$BUILD_DIR/linux"

cd "$PROJECT_DIR"

# Parse command line arguments
PLATFORM="$1"
RELEASE_MODE="${2:-debug}"

export_platform() {
    local platform="$1"
    local preset="$2"
    local output="$3"

    echo ""
    echo "Exporting for $platform..."

    if [ "$RELEASE_MODE" = "release" ]; then
        "$GODOT" --headless --export-release "$preset" "$output"
    else
        "$GODOT" --headless --export-debug "$preset" "$output"
    fi

    echo "✓ $platform export complete: $output"
}

case "$PLATFORM" in
    windows)
        export_platform "Windows" "Windows Desktop" "builds/windows/chess-puzzle.exe"
        ;;
    macos)
        export_platform "macOS" "macOS" "builds/macos/chess-puzzle.app"
        ;;
    linux)
        export_platform "Linux" "Linux" "builds/linux/chess-puzzle.x86_64"
        ;;
    all)
        export_platform "Windows" "Windows Desktop" "builds/windows/chess-puzzle.exe"
        export_platform "macOS" "macOS" "builds/macos/chess-puzzle.app"
        export_platform "Linux" "Linux" "builds/linux/chess-puzzle.x86_64"
        ;;
    package)
        # Create distribution packages
        echo ""
        echo "Creating distribution packages..."

        # Windows ZIP
        if [ -f "$BUILD_DIR/windows/chess-puzzle.exe" ]; then
            cd "$BUILD_DIR/windows"
            zip -r "../chess-puzzle-windows.zip" .
            echo "✓ Created chess-puzzle-windows.zip"
        fi

        # Linux tar.gz
        if [ -f "$BUILD_DIR/linux/chess-puzzle.x86_64" ]; then
            cd "$BUILD_DIR/linux"
            tar -czvf "../chess-puzzle-linux.tar.gz" .
            echo "✓ Created chess-puzzle-linux.tar.gz"
        fi

        # macOS DMG (requires create-dmg or just zip)
        if [ -d "$BUILD_DIR/macos/chess-puzzle.app" ]; then
            cd "$BUILD_DIR/macos"
            zip -r "../chess-puzzle-macos.zip" chess-puzzle.app
            echo "✓ Created chess-puzzle-macos.zip"
        fi

        cd "$PROJECT_DIR"
        echo ""
        echo "Distribution packages created in: $BUILD_DIR"
        ls -la "$BUILD_DIR"/*.{zip,tar.gz} 2>/dev/null || true
        ;;
    *)
        echo "Usage: $0 <platform> [mode]"
        echo ""
        echo "Platforms:"
        echo "  windows  - Export for Windows"
        echo "  macos    - Export for macOS"
        echo "  linux    - Export for Linux"
        echo "  all      - Export for all platforms"
        echo "  package  - Create distribution packages (after exporting)"
        echo ""
        echo "Modes:"
        echo "  debug    - Debug build (default)"
        echo "  release  - Release build"
        echo ""
        echo "Examples:"
        echo "  $0 all                # Export all platforms (debug)"
        echo "  $0 all release        # Export all platforms (release)"
        echo "  $0 macos              # Export macOS only"
        echo "  $0 package            # Create zip/tar.gz packages"
        exit 1
        ;;
esac

echo ""
echo "=== Build complete ==="
