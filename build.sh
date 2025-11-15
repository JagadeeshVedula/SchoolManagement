#!/bin/bash

set -e  # Exit on any error

echo "=== Installing Flutter ==="

# Install system dependencies first
apt-get update && apt-get install -y -q --no-install-recommends \
    curl unzip sed git bash xz-utils libglu1-mesa

# Download and install Flutter
FLUTTER_VERSION="3.16.9"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

echo "Downloading Flutter $FLUTTER_VERSION..."
curl -L $FLUTTER_URL -o flutter.tar.xz

echo "Extracting Flutter..."
tar -xf flutter.tar.xz
export PATH="$PATH:$(pwd)/flutter/bin"

# Enable Flutter web and verify
echo "=== Setting up Flutter ==="
flutter config --enable-web
flutter --version

echo "=== Getting dependencies ==="
flutter pub get

echo "=== Building web version ==="
flutter build web --release

echo "=== Build complete! ==="
ls -la build/web/