# Start Remote Debugger in background
Start-Process 'C:\Program Files\Microsoft Visual Studio 17.0\Common7\IDE\Remote Debugger\x64\msvsmon.exe' -ArgumentList '/port 4026 /noauth /anyuser /silent /timeout:2147483646'

# Start IIS
C:\ServiceMonitor.exe w3svc