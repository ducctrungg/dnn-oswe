# The script sets the sa password and start the SQL Service 

param(
    [Parameter(Mandatory = $false)]
    [string]$sa_password
)

if (-not $env:SQLCMDSERVER) {
    $env:SQLCMDSERVER = ".\SQLEXPRESS"
}

function Set-DatabaseSqlLogin {
    param(
        [string]$LoginName,
        [string]$LoginPassword,
        [string]$DatabaseName
    )

    if (-not $LoginName -or -not $LoginPassword) {
        Write-Verbose "DB_USER/DB_PASSWORD not provided; skipping custom login provisioning."
        return
    }

    if (-not $DatabaseName) {
        Write-Verbose "No database specified for login [$LoginName]; database user step skipped."
        return
    }

    $setupScript = "C:\Setup.sql"
    
    if (Test-Path $setupScript) {
        Write-Host "Running Setup.sql..."
        & sqlcmd -i $setupScript -v dbName="$DatabaseName" dbUser="$LoginName" dbPwd="$LoginPassword"
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "sqlcmd exited $LASTEXITCODE while running Setup.sql."
        }
        else {
            Write-Host "Setup.sql executed successfully."
        }
    }
    else {
        Write-Warning "Setup.sql not found at $setupScript"
    }

    & sqlcmd -d $DatabaseName -U $LoginName -P $LoginPassword -Q "SELECT SUSER_SNAME() AS LoginName, DB_NAME() AS DatabaseName;" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully signed in to [$DatabaseName] as [$LoginName]."
    }
    else {
        Write-Warning "Test sign-in for [$LoginName] failed (exit $LASTEXITCODE)."
    }
}

if ($sa_password -ne "_") {
    Write-Verbose "Changing SA login credentials"
    $sqlcmd = "ALTER LOGIN sa with password=" + "'" + $sa_password + "'" + ";ALTER LOGIN sa ENABLE;"
    & sqlcmd -Q $sqlcmd
}

Set-DatabaseSqlLogin -LoginName $env:DB_USER -LoginPassword $env:DB_PASSWORD -DatabaseName $env:DB_NAME

$lastCheck = (Get-Date).AddSeconds(-2) 
while ($true) { 
    Get-EventLog -LogName Application -Source "MSSQL*" -After $lastCheck | Select-Object TimeGenerated, EntryType, Message	 
    $lastCheck = Get-Date 
    Start-Sleep -Seconds 2 
}