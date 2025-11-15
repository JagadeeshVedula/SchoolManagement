#!/bin/bash

# Install Flutter
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable
export PATH="$PATH:$(pwd)/flutter/bin"

# Verify installation
flutter --version

# Get dependencies and build
echo "Getting dependencies..."
flutter pub get

echo "Building web..."
flutter build web

echo "Build completed!"