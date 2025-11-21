# C:\Start.ps1
$webConfigPath = "C:\inetpub\wwwroot\web.config"

Write-Host "Starting DNN Bootstrapper..."

# Wait loop for SQL Server (Basic)
Write-Host "Waiting for SQL Server..."
Start-Sleep -Seconds 15

if (Test-Path $webConfigPath) {
    Write-Host "Configuring web.config for Unattended Install..."
    $xml = [xml](Get-Content $webConfigPath)
    $root = $xml.configuration

    # 1. Update Connection String
    # Removes legacy AttachDbFilename and inserts Container SQL connection
    $connStr = "Server=$($env:DB_SERVER);Database=$($env:DB_NAME);User ID=$($env:DB_USER);Password=$($env:DB_PASSWORD);"
    $node = $root.connectionStrings.add | Where-Object { $_.name -eq "SiteSqlServer" }
    if ($node) {
        $node.connectionString = $connStr
        $node.providerName = "System.Data.SqlClient"
    }

    # 2. Set AutoUpgrade = True (Triggers DB Install on first request)
    $au = $root.appSettings.add | Where-Object { $_.key -eq "AutoUpgrade" }
    if ($au) { $au.value = "true" }

    # 3. Set UseInstallWizard = False (Disables GUI)
    $wiz = $root.appSettings.add | Where-Object { $_.key -eq "UseInstallWizard" }
    if ($wiz) { 
        $wiz.value = "false" 
    } else {
        $elem = $xml.CreateElement("add")
        $elem.SetAttribute("key", "UseInstallWizard")
        $elem.SetAttribute("value", "false")
        $root.appSettings.AppendChild($elem)
    }

    $xml.Save($webConfigPath)
    Write-Host "Configuration Complete."
}

# Background Job to Monitor Install and Set 404 Page
Start-Job -ScriptBlock {
    $connStr = "Server=$($env:DB_SERVER);Database=$($env:DB_NAME);User ID=$($env:DB_USER);Password=$($env:DB_PASSWORD);"
    $chk = $false
    # Poll until PortalSettings table is created by the Installer
    while (-not $chk) {
        Start-Sleep -Seconds 10
        try {
            $query = "SELECT count(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'PortalSettings'"
            $res = Invoke-SqlCmd -Query $query -ConnectionString $connStr -ErrorAction SilentlyContinue
            if ($res -gt 0) { $chk = $true }
        } catch {}
    }
    
    # Apply 404 Settings
    $updateSql = "IF NOT EXISTS (SELECT * FROM PortalSettings WHERE SettingName = 'AUM_ErrorPage404') INSERT INTO PortalSettings (PortalID, SettingName, SettingValue, CreatedByUserID, CreatedOnDate, LastModifiedByUserID, LastModifiedOnDate) VALUES (0, 'AUM_ErrorPage404', '20', -1, GETDATE(), -1, GETDATE()) ELSE UPDATE PortalSettings SET SettingValue = '20' WHERE SettingName = 'AUM_ErrorPage404'"
    Invoke-SqlCmd -Query $updateSql -ConnectionString $connStr
    Write-Host "404 Page Configured."
}

# Start IIS Service
Write-Host "Starting IIS ServiceMonitor..."
C:\ServiceMonitor.exe w3svc