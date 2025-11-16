#!/bin/bash

# Auto-configure Flutter based on current OS

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo "Configuring Flutter for macOS..."
    flutter config --enable-ios --enable-android --enable-macos-desktop \
                   --no-enable-windows-desktop --no-enable-linux-desktop
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows
    echo "Configuring Flutter for Windows..."
    flutter config --enable-android --enable-windows-desktop \
                   --no-enable-ios --no-enable-macos-desktop --no-enable-linux-desktop
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    echo "Configuring Flutter for Linux..."
    flutter config --enable-android --enable-linux-desktop \
                   --no-enable-ios --no-enable-macos-desktop --no-enable-windows-desktop
fi

flutter config --list | grep "enable-"
