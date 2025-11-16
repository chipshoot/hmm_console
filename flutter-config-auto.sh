#!/bin/bash

# Auto-configure Flutter for mobile platforms only (Android + iOS)

echo "Configuring Flutter for mobile platforms (Android + iOS)..."
flutter config --enable-android --enable-ios \
               --no-enable-windows-desktop --no-enable-linux-desktop --no-enable-macos-desktop \
               --no-enable-web

echo ""
echo "Enabled platforms:"
flutter config --list | grep "enable-"
