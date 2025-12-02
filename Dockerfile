# Use the LTSC 2019 image for maximum compatibility with legacy.NET 4.5+
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2019

# Define version
ENV DNN_VERSION=8.0.4
ENV DNN_DOWNLOAD_URL=https://github.com/dnnsoftware/Dnn.Platform/releases/download/v8.0.4/DNN_Platform_8.0.4.226_Install.zip

# Set shell to PowerShell for advanced scripting capabilities
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install IIS
RUN Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# IIS Setup
RUN Remove-Website -Name 'Default Web Site'
RUN New-WebAppPool -Name 'dnnpool'
RUN New-Website -Name 'dnn' -PhysicalPath 'C:\inetpub\wwwroot\dnn' -Port 8000 -ApplicationPool 'dnnpool' -Force

WORKDIR 'C:\inetpub\wwwroot\'

RUN Invoke-WebRequest -Uri $env:DNN_DOWNLOAD_URL -OutFile dnn.zip
RUN Expand-Archive -Path dnn.zip
RUN Remove-Item dnn.zip

# Set full control permissions for the app pool on the webroot
RUN icacls.exe 'dnn' /grant 'IIS APPPOOL\dnnpool:(OI)(CI)F' /T /C /Q

# Install Visual Studio Remote Tools
RUN Invoke-WebRequest -Uri https://aka.ms/vs/17/release/RemoteTools.amd64ret.enu.exe -OutFile RemoteTools.exe
RUN Start-Process -Wait -FilePath .\RemoteTools.exe -ArgumentList '/install', '/quiet', '/norestart'
RUN Remove-Item RemoteTools.exe

# Download ServiceMonitor.exe
RUN Invoke-WebRequest -Uri https://dotnetbinaries.blob.core.windows.net/servicemonitor/2.0.1.10/ServiceMonitor.exe -OutFile C:\ServiceMonitor.exe

# Copy Entrypoint Script
COPY Start.ps1 'C:\Start.ps1'

# Expose the Web Port and Remote Debugger Port
EXPOSE 8000 4026

# Define Entrypoint
ENTRYPOINT ["powershell", "C:\\Start.ps1"]