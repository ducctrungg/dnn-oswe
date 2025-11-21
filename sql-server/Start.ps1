# The script sets the sa password and start the SQL Service 

param(
    [Parameter(Mandatory = $false)]
    [string]$sa_password,

    [Parameter(Mandatory = $false)]
    [string]$create_db
)

if (-not $env:SQLCMDSERVER) {
    $env:SQLCMDSERVER = ".\SQLEXPRESS"
}

function Ensure-DatabaseSqlLogin {
    param(
        [string]$LoginName,
        [string]$LoginPassword,
        [string]$DatabaseName
    )

    if (-not $LoginName -or -not $LoginPassword) {
        Write-Verbose "DB_USER/DB_PASSWORD not provided; skipping custom login provisioning."
        return
    }

    $safeLogin = $LoginName.Replace("]", "]]")
    $safePassword = $LoginPassword -replace "'", "''"

    $loginQuery = @"
DECLARE @login sysname = N'$safeLogin';
DECLARE @pwd nvarchar(256) = N'$safePassword';
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @login)
BEGIN
    EXEC(N'CREATE LOGIN ' + QUOTENAME(@login) + N' WITH PASSWORD = ''' + @pwd + N''', CHECK_POLICY = OFF');
END
ELSE
BEGIN
    EXEC(N'ALTER LOGIN ' + QUOTENAME(@login) + N' WITH PASSWORD = ''' + @pwd + N'''');
END
"@

    & sqlcmd -Q $loginQuery
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "sqlcmd exited $LASTEXITCODE while ensuring login $LoginName."
        return
    }

    if (-not $DatabaseName) {
        Write-Verbose "No database specified for login [$LoginName]; database user step skipped."
        return
    }

    $userQuery = @"
DECLARE @login sysname = N'$safeLogin';
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @login)
BEGIN
    EXEC(N'CREATE USER ' + QUOTENAME(@login) + N' FOR LOGIN ' + QUOTENAME(@login));
END
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals rp ON drm.role_principal_id = rp.principal_id
    JOIN sys.database_principals mp ON drm.member_principal_id = mp.principal_id
    WHERE rp.name = 'db_owner' AND mp.name = @login
)
BEGIN
    EXEC(N'ALTER ROLE [db_owner] ADD MEMBER ' + QUOTENAME(@login));
END
"@

    & sqlcmd -d $DatabaseName -Q $userQuery
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "sqlcmd exited $LASTEXITCODE while configuring database access for $LoginName in $DatabaseName."
        return
    }

    Write-Host "SQL login [$LoginName] configured for database [$DatabaseName]."

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

# Create a single database from a plain string parameter if provided.
$createdDbName = $null

if ($create_db) {
    $rawName = $create_db.Trim()
    if (-not $rawName) { Write-Warning "create_db was provided but is empty after trimming; skipping." }
    else {
        # Escape single quotes for safe embedding in T-SQL literal
        $safeName = $rawName -replace "'", "''"

        # Use QUOTENAME inside T-SQL to safely quote the database name and avoid SQL injection
        $sqlCreate = "DECLARE @n sysname = N'$safeName'; IF DB_ID(@n) IS NULL EXEC('CREATE DATABASE ' + QUOTENAME(@n));"

        Write-Verbose "Creating database: $rawName"
        & sqlcmd -Q $sqlCreate
        if ($LASTEXITCODE -ne 0) { Write-Error "sqlcmd failed creating database $rawName (exit $LASTEXITCODE)" }
        else { $createdDbName = $rawName }
    }
}

$targetDb = $null
if ($env:DB_NAME) { 
    $targetDb = $env:DB_NAME 
}
elseif ($createdDbName) {
    $targetDb = $createdDbName
}

Ensure-DatabaseSqlLogin -LoginName $env:DB_USER -LoginPassword $env:DB_PASSWORD -DatabaseName $targetDb

$lastCheck = (Get-Date).AddSeconds(-2) 
while ($true) { 
    Get-EventLog -LogName Application -Source "MSSQL*" -After $lastCheck | Select-Object TimeGenerated, EntryType, Message	 
    $lastCheck = Get-Date 
    Start-Sleep -Seconds 2 
}