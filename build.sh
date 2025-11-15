#!/usr/bin/env bash

set -euo pipefail

echo "=== Flutter web build script ==="

# This script downloads a local Flutter SDK (if not present in ./flutter),
# enables web, fetches dependencies and builds the web release into build/web.
# It's intentionally self-contained so CI systems (including Vercel's builders)
# can run it via `npm run build` (which calls this script).

FLUTTER_VERSION="3.16.9"
FLUTTER_DIR="flutter"
FLUTTER_TAR="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_TAR}"

download_flutter() {
    if [ -d "$FLUTTER_DIR" ]; then
        echo "Flutter already present in $FLUTTER_DIR"
        return
    fi

    echo "Downloading Flutter $FLUTTER_VERSION..."
    # Use -f to fail on HTTP errors, -S to show errors, -L to follow redirects, -# for progress
    if ! curl -fSL# "$FLUTTER_URL" -o "$FLUTTER_TAR"; then
        echo "Error: Failed to download Flutter from $FLUTTER_URL"
        exit 1
    fi
    
    # Verify the download is a valid tar
    if ! file "$FLUTTER_TAR" | grep -q "XZ compressed"; then
        echo "Error: Downloaded file is not a valid XZ tar archive"
        echo "File type: $(file "$FLUTTER_TAR")"
        rm -f "$FLUTTER_TAR"
        exit 1
    fi
    
    echo "Extracting Flutter..."
    # Extract with verbose error reporting
    if ! tar -xJf "$FLUTTER_TAR"; then
        echo "Error: Failed to extract Flutter tar archive"
        exit 1
    fi
    
    # Handle the extracted directory
    if [ -d "flutter" ] && [ "$FLUTTER_DIR" != "flutter" ]; then
        mv "flutter" "$FLUTTER_DIR"
    fi
    
    rm -f "$FLUTTER_TAR"
    echo "Flutter extracted successfully to $FLUTTER_DIR"
}

export PATH="$PWD/$FLUTTER_DIR/bin:$PATH"

download_flutter

echo "=== Setting up Flutter for web ==="
flutter config --enable-web || true
flutter --version

echo "=== Getting dependencies ==="
flutter pub get

echo "=== Building web (release) ==="
flutter build web --release

echo "=== Build complete: build/web ==="
ls -la build/web || true

echo "If you plan to deploy on Vercel using @vercel/static-build, ensure that package.json's build script runs this file and vercel.json's distDir is set to build/web."