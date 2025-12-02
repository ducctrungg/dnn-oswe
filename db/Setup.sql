/*
-- Install.SQL                                                          
-- Create DB if it doesn't exist                                        
-- Create login and makes the user a member of db_owner                
*/

-- Declare variables for database name, username and password
DECLARE @dbName sysname,
      @dbUser sysname,
      @dbPwd nvarchar(max);

-- Set variables for database name, username and password
SET @dbName = '$(dbName)';
SET @dbUser = '$(dbUser)';
SET @dbPwd = '$(dbPwd)';

DECLARE @cmd nvarchar(max)

-- Create database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = @dbName)
BEGIN
    PRINT '-- Creating database ' + @dbName
    SET @cmd = N'CREATE DATABASE ' + quotename(@dbName)
    EXEC(@cmd)
END

-- Create login
IF( SUSER_SID(@dbUser) is null )
BEGIN
    print '-- Creating login '
    SET @cmd = N'CREATE LOGIN ' + quotename(@dbUser) + N' WITH PASSWORD ='''+ replace(@dbPwd, '''', '''''') + N''''
    EXEC(@cmd)
END

-- Create database user and map to login
-- and add user to the datareader, datawriter, ddladmin and securityadmin roles
--
SET @cmd = N'USE ' + quotename(@DBName) + N'; 
IF( NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = ''' + replace(@dbUser, '''', '''''') + N'''))
BEGIN
    print ''-- Creating user'';
    CREATE USER ' + quotename(@dbUser) + N' FOR LOGIN ' + quotename(@dbUser) + N';
    print ''-- Adding user'';
    EXEC sp_addrolemember ''db_owner'', ''' + replace(@dbUser, '''', '''''') + N''';
END'
EXEC(@cmd)
GO
