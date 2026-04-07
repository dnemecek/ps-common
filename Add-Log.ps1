<#
.SYNOPSIS
    Obecna logovaci funkce pro PowerShell skripty.

.DESCRIPTION
    Zapise zpravu do log souboru ve standardnim formatu.
    - Format: [YYYY-MM-DD HH:mm:ss.fff] (+n.nnn) [LEVEL] Message
    - Vystup do souboru (ASCII) + Write-Verbose
    - Nikdy nepise na stdout (kompatibilni s Ansible JSON vystupem)
    - Automaticky vytvori adresar pro log pokud neexistuje

.PARAMETER Message
    Text zpravy k zalogovani.

.PARAMETER Level
    Uroven logu: INFO, WARNING, ERROR, DEBUG.
    Vychozi: INFO.

.PARAMETER LogFile
    Cesta k log souboru. Povinny parametr.

.PARAMETER StartTime
    Casovy okamzik startu skriptu pro vypocet elapsed time.
    Vychozi: aktualni cas (elapsed bude 0).

.EXAMPLE
    . .\common\Add-Log.ps1
    Add-Log -Message "Script started" -LogFile "C:\Windows\Logs\test.log" -StartTime $startTime

.EXAMPLE
    Add-Log "Error occurred" -Level ERROR -LogFile $logFile -StartTime $startTime

.NOTES
    Nazev: Add-Log.ps1
    Autor: David Nemecek
    Vytvoreno: 2026-04-07
#>

function Add-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory = $true)]
        [string]$LogFile,

        [Parameter(Mandatory = $false)]
        [datetime]$StartTime = (Get-Date)
    )

    $logFolder = Split-Path $LogFile -Parent
    if (-not (Test-Path $logFolder)) {
        New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $elapsed = ((Get-Date) - $StartTime).TotalSeconds.ToString("0.000")
    $logMessage = "[$timestamp] (+$elapsed) [$Level] $Message"

    Add-Content -Path $LogFile -Value $logMessage -Encoding ASCII

    Write-Verbose $logMessage
}
