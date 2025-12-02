# Start Remote Debugger in background
Start-Process "C:\Program Files\Microsoft Visual Studio 17.0\Common7\IDE\Remote Debugger\x64\msvsmon.exe" -ArgumentList "/noauth /anyuser /silent /nostatus /noclarify /timeout:2147483646"

# Start IIS
Start-Service w3svc

# Keep container alive
while ($true) {
    Start-Sleep -Seconds 60
}
