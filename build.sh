#!/bin/bash

# Install Flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable
export PATH="$PATH:$(pwd)/flutter/bin"

# Verify installation
flutter --version

# Get dependencies and build
flutter pub get
flutter build web