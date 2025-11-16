# Auto-configure Flutter based on current OS

if ($IsWindows) {
    Write-Host "Configuring Flutter for Windows..."
    flutter config --enable-android --enable-windows-desktop `
                   --no-enable-ios --no-enable-macos-desktop --no-enable-linux-desktop
} elseif ($IsMacOS) {
    Write-Host "Configuring Flutter for macOS..."
    flutter config --enable-ios --enable-android --enable-macos-desktop `
                   --no-enable-windows-desktop --no-enable-linux-desktop
} elseif ($IsLinux) {
    Write-Host "Configuring Flutter for Linux..."
    flutter config --enable-android --enable-linux-desktop `
                   --no-enable-ios --no-enable-macos-desktop --no-enable-windows-desktop
}

flutter config --list | Select-String "enable-"
