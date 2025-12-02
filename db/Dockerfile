FROM mcr.microsoft.com/windows/servercore:ltsc2019

ENV SQL_EXPRESS="https://go.microsoft.com/fwlink/?linkid=829176"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

COPY Start.ps1 'C:\Start.ps1'
COPY Setup.sql 'C:\Setup.sql'

WORKDIR 'C:\'

RUN Invoke-WebRequest -Uri $env:SQL_EXPRESS -OutFile sqlexpress.exe 
RUN Start-Process -Wait -FilePath .\sqlexpress.exe -ArgumentList /QS, /x:setup

# /Q: Quiet mode, no user interaction.
# /ACTION=Install: Performs an installation.
# /INSTANCENAME=SQLEXPRESS: Sets the instance name to SQLEXPRESS.
# /FEATURES=SQLEngine: Installs only the SQL Database Engine.
# /UPDATEENABLED=0: Disables automatic updates.
# /SQLSVCACCOUNT='NT AUTHORITY\System': Sets the SQL Server service account.
# /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS': Grants sysadmin rights to local administrators.
# /TCPENABLED=1: Enables TCP/IP protocol.
# /NPENABLED=0: Disables Named Pipes protocol.
# /IACCEPTSQLSERVERLICENSETERMS: Accepts the SQL Server license terms.
RUN .\setup\setup.exe /Q /ACTION=Install /INSTANCENAME=SQLEXPRESS /FEATURES=SQLEngine /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\System' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS
RUN Remove-Item -Recurse -Force sqlexpress.exe, setup

# Backtick to escape $
RUN Stop-Service MSSQL`$SQLEXPRESS -Force   

# Set Port 1433
RUN Set-Itemproperty -path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL14.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Tcp\IPAll' -name tcpdynamicports -value ''
RUN Set-Itemproperty -path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL14.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Tcp\IPAll' -name tcpport -value 1433

# Set Mixed Mode Authentication
RUN Set-Itemproperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL14.SQLEXPRESS\MSSQLServer' -Name LoginMode -Value 2

EXPOSE 1433

RUN Start-Service MSSQL`$SQLEXPRESS

CMD .\Start.ps1 -sa_password $env:SA_PASSWORD -Verbose