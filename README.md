# ps-common

Sdílené PowerShell moduly pro obecné skripty. Přidává se jako git submodul `common/` do jednotlivých skriptových repozitářů.

## Moduly

| Modul | Popis |
|---|---|
| `Add-Log.ps1` | Obecná logovací funkce. Formát: `[YYYY-MM-DD HH:mm:ss.fff] (+n.nnn) [LEVEL] Message` |
| `Lock-Script.psm1` | Ochrana proti souběžnému spuštění skriptu: výhradně otevřený soubor `<LockFolder>\<LockName>.lock`, uvolní se i při pádu procesu. Výchozí složka `%ProgramData%\Scripts\Locks`. |

## Použití

```powershell
# Import v PS skriptu
. (Join-Path $PSScriptRoot 'common\Add-Log.ps1')

# Volání
Add-Log -Message "Script started" -LogFile $logFile -StartTime $startTime
Add-Log "Error" -Level ERROR -LogFile $logFile -StartTime $startTime

# Zamek proti soubehu
Import-Module (Join-Path $PSScriptRoot 'common\Lock-Script.psm1') -Force
if (-not (Enter-ScriptLock -LockName 'MyScript' -LockFolder 'C:\Scripts\Locks')) { exit 0 }  # uz bezi
try { <# hlavni kod #> } finally { Exit-ScriptLock }
```

## Přidání do repozitáře

```bash
git submodule add https://github.com/dnemecek/ps-common.git common
```

## Autor

David Němeček
