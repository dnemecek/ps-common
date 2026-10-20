<#
.SYNOPSIS
    Modul pro ochranu proti duplicitnimu spusteni skriptu (flock-style).
    
.DESCRIPTION
    Poskytuje funkce Enter-ScriptLock a Exit-ScriptLock pro exkluzivni
    zamykani skriptu. Pouziva Windows FileStream s exclusive access,
    coz je obdobne jako Linux flock.
    
    Lock se automaticky uvolni pri ukonceni procesu (vcetne crash/kill/BSOD).
    
.NOTES
    Autor: David Nemecek
    
    Historie verzi:
    v1.0 - 2026-01 - Prvni verze
    v1.1 - 2026-10 - Vychozi slozka zamku obecna (%ProgramData%\Scripts\Locks), prevzato do ps-common
    
.EXAMPLE
    Import-Module (Join-Path $PSScriptRoot "modules\Lock-Script.psm1") -Force
    
    if (-not (Enter-ScriptLock -LockName "MyScript")) {
        Write-Host "Another instance is running"
        exit 0
    }
    
    try {
        # ... hlavni kod ...
    }
    finally {
        Exit-ScriptLock
    }
#>

# ============================================================================
# KONFIGURACE MODULU
# ============================================================================

# Vychozi slozka je obecna; skript ji typicky preda parametrem -LockFolder podle sveho korene logu.
$script:DefaultLockFolder = Join-Path $env:ProgramData 'Scripts\Locks'
$script:LockStream = $null
$script:LockWriter = $null

# ============================================================================
# FUNKCE
# ============================================================================

function Enter-ScriptLock {
    <#
    .SYNOPSIS
        Ziska exkluzivni zamek pro skript.
    .DESCRIPTION
        Vytvori exclusive file lock (jako Linux flock). Pokud jiny proces
        uz drzi zamek, vrati $false. Lock se automaticky uvolni pri
        ukonceni procesu (vcetne crash/kill).
    .PARAMETER LockName
        Unikatni jmeno zamku (typicky nazev skriptu bez pripony).
    .PARAMETER LockFolder
        Slozka pro lock soubory. Default: %ProgramData%\Scripts\Locks
    .OUTPUTS
        [bool] $true pokud zamek ziskan, $false pokud uz je zamceno.
    .EXAMPLE
        if (-not (Enter-ScriptLock -LockName "NIC-PowerManagement")) {
            exit 0
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LockName,
        
        [ValidateNotNullOrEmpty()]
        [string]$LockFolder = $script:DefaultLockFolder
    )
    
    # Zajisti existenci slozky pro zamky
    if (-not (Test-Path $LockFolder)) {
        try {
            New-Item -Path $LockFolder -ItemType Directory -Force | Out-Null
        }
        catch {
            Write-Warning "Failed to create lock folder: $LockFolder - $_"
            return $true  # Pokracovat bez zamku
        }
    }
    
    $lockFile = Join-Path $LockFolder "$LockName.lock"
    
    try {
        # Pokus o exclusive lock - jako Linux flock
        # FileShare::None = zadny jiny proces nemuze otevrit soubor
        $script:LockStream = [System.IO.File]::Open(
            $lockFile,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
        
        # Vycisteni souboru pred zapisem novych metadat
        $script:LockStream.SetLength(0)
        
        # Zapis metadata pro diagnostiku
        $script:LockWriter = New-Object System.IO.StreamWriter($script:LockStream)
        $script:LockWriter.WriteLine("PID: $PID")
        $script:LockWriter.WriteLine("Time: $(Get-Date -Format 'o')")
        $script:LockWriter.WriteLine("Computer: $env:COMPUTERNAME")
        $script:LockWriter.WriteLine("User: $env:USERNAME")
        $script:LockWriter.WriteLine("Script: $LockName")
        $script:LockWriter.Flush()
        # NEZAVIRAT writer/stream - drzi lock!
        
        return $true
    }
    catch [System.IO.IOException] {
        # Soubor uz je zamceny jinym procesem
        return $false
    }
    catch {
        # Jina chyba - logovat warning a pokracovat bez zamku
        Write-Warning "Lock acquisition error: $_"
        return $true
    }
}

function Exit-ScriptLock {
    <#
    .SYNOPSIS
        Uvolni zamek skriptu.
    .DESCRIPTION
        Zavira FileStream, cimz uvolni exclusive lock.
        Bezpecne volat i kdyz zamek nebyl ziskan.
    .EXAMPLE
        try {
            # ... kod ...
        }
        finally {
            Exit-ScriptLock
        }
    #>
    [CmdletBinding()]
    param()
    
    try {
        if ($script:LockWriter) {
            $script:LockWriter.Close()
            $script:LockWriter = $null
        }
        if ($script:LockStream) {
            $script:LockStream.Close()
            $script:LockStream = $null
        }
    }
    catch {
        # Best effort - ignorovat chyby pri uvolnovani
    }
}

function Test-ScriptLock {
    <#
    .SYNOPSIS
        Overi zda je zamek aktivni (pro diagnostiku).
    .DESCRIPTION
        Vrati $true pokud tento proces drzi zamek.
    .OUTPUTS
        [bool] $true pokud zamek aktivni.
    .EXAMPLE
        if (Test-ScriptLock) {
            Write-Host "Lock is active"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    return ($null -ne $script:LockStream)
}

function Get-ScriptLockInfo {
    <#
    .SYNOPSIS
        Vrati informace o zamku.
    .DESCRIPTION
        Vrati hashtable s informacemi o zamku nebo $null.
    .PARAMETER LockName
        Jmeno zamku k precteni.
    .PARAMETER LockFolder
        Slozka s lock soubory.
    .OUTPUTS
        [hashtable] Informace o zamku nebo $null.
    .EXAMPLE
        $info = Get-ScriptLockInfo -LockName "NIC-PowerManagement"
        if ($info.IsActive) {
            Write-Host "Locked by PID: $($info.Content)"
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LockName,
        
        [ValidateNotNullOrEmpty()]
        [string]$LockFolder = $script:DefaultLockFolder
    )
    
    $lockFile = Join-Path $LockFolder "$LockName.lock"
    
    if (-not (Test-Path $lockFile)) {
        return $null
    }
    
    try {
        # Pokus o otevreni - pokud uspe, zamek neni aktivni
        $testStream = [System.IO.File]::Open(
            $lockFile,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::None
        )
        $testStream.Close()
        
        # Zamek neni aktivni - soubor existuje ale neni zamceny
        return @{
            LockFile = $lockFile
            IsActive = $false
            Content  = Get-Content $lockFile -Raw -ErrorAction SilentlyContinue
        }
    }
    catch [System.IO.IOException] {
        # Soubor je zamceny - zamek je aktivni
        return @{
            LockFile = $lockFile
            IsActive = $true
            Content  = $null  # Nelze precist, je zamceny
        }
    }
    catch {
        return $null
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function @(
    'Enter-ScriptLock',
    'Exit-ScriptLock',
    'Test-ScriptLock',
    'Get-ScriptLockInfo'
)
