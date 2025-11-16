# Auto-configure Flutter for mobile platforms only (Android + iOS)

Write-Host "Configuring Flutter for mobile platforms (Android + iOS)..."
flutter config --enable-android --enable-ios `
               --no-enable-windows-desktop --no-enable-linux-desktop --no-enable-macos-desktop `
               --no-enable-web

Write-Host ""
Write-Host "Enabled platforms:"
flutter config --list | Select-String "enable-"
