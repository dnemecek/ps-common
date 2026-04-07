# ps-common

Sdílené PowerShell moduly pro obecné skripty. Přidává se jako git submodul `common/` do jednotlivých skriptových repozitářů.

## Moduly

| Modul | Popis |
|---|---|
| `Add-Log.ps1` | Obecná logovací funkce. Formát: `[YYYY-MM-DD HH:mm:ss.fff] (+n.nnn) [LEVEL] Message` |

## Použití

```powershell
# Import v PS skriptu
. (Join-Path $PSScriptRoot 'common\Add-Log.ps1')

# Volání
Add-Log -Message "Script started" -LogFile $logFile -StartTime $startTime
Add-Log "Error" -Level ERROR -LogFile $logFile -StartTime $startTime
```

## Přidání do repozitáře

```bash
git submodule add https://github.com/dnemecek/ps-common.git common
```

## Autor

David Němeček
