<#
.SYNOPSIS
  Benennt die Objekte eines Tools aus dem Z-Namensraum in einen Kundennamensraum um
  (PowerShell-Variante von rename_namespace.py).

.DESCRIPTION
  Ersetzt in Dateinamen und Dateiinhalten (Gross- und Kleinschreibung):
      ZCL_<KÜRZEL>_  ->  <NS>CL_<KÜRZEL>_
      Z<KÜRZEL>_     ->  <NS><KÜRZEL>_
  und prüft danach die SAP-Längenbeschränkungen der Objektnamen.
  Das Skript ändert die Dateien direkt, deshalb vorher einen Branch oder eine Kopie anlegen.

.EXAMPLE
  .\tools\rename_namespace.ps1 -Ns /ABC/
  .\tools\rename_namespace.ps1 -Ns Y -DryRun
#>
param(
  [Parameter(Mandatory = $true)][string]$Ns,
  [string]$Abbr = 'RRI',
  [string]$Path = 'src\rri_dyn',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Ns = $Ns.ToUpper()
$Abbr = $Abbr.ToUpper()
if ($Ns -cnotmatch '^([ZY]|/[A-Z0-9_]{1,8}/)$') { throw 'Ungültiger Namensraum: erlaubt sind Z, Y oder /NAMESPACE/' }
if (-not (Test-Path $Path -PathType Container)) { throw "Verzeichnis nicht gefunden: $Path" }

$maxLen = @{ tabl = 16; view = 16; vcls = 16; doma = 30; dtel = 30; clas = 30; intf = 30; enho = 30; fugr = 26; tobj = 20; devc = 30 }

$rules = @(
  @("ZCL_$($Abbr)_", "$($Ns)CL_$($Abbr)_"),
  @("Z$($Abbr)_", "$Ns$($Abbr)_")
)
$rules += @($rules | ForEach-Object { , @($_[0].ToLower(), $_[1].ToLower()) })

function Convert-Text([string]$s) {
  # Platzhalter verhindern, dass ZCL_RRI_ anschliessend nochmals von ZRRI_ erfasst wird
  for ($i = 0; $i -lt $rules.Count; $i++) { $s = $s.Replace($rules[$i][0], "<<$i>>") }
  for ($i = 0; $i -lt $rules.Count; $i++) { $s = $s.Replace("<<$i>>", $rules[$i][1]) }
  return $s
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$errors = @()

Get-ChildItem -Path $Path -File -Recurse | Sort-Object FullName | ForEach-Object {
  $old = [System.IO.File]::ReadAllText($_.FullName, $utf8)
  $new = Convert-Text $old
  $newName = (Convert-Text $_.Name).Replace('/', '#')
  $dst = Join-Path $_.DirectoryName $newName

  $parts = $newName.Split('.')
  if ($parts.Count -ge 3 -and $parts[0] -ne 'package') {
    $obj = $parts[0].Replace('#', '/'); $typ = $parts[1]
    if ($maxLen.ContainsKey($typ) -and $obj.Length -gt $maxLen[$typ]) {
      $errors += "$($obj.ToUpper()) ($($typ.ToUpper())): $($obj.Length) > $($maxLen[$typ]) Zeichen"
    }
  }

  if ($new -cne $old -or $newName -cne $_.Name) {
    '{0,-40} -> {1}' -f $_.Name, $newName
    if (-not $DryRun) {
      [System.IO.File]::WriteAllText($dst, $new.Replace("`r`n", "`n"), $utf8)
      if ($dst -cne $_.FullName) { Remove-Item -LiteralPath $_.FullName }
    }
  }
}

if ($errors.Count -gt 0) {
  Write-Host "`nACHTUNG, Namen zu lang:" -ForegroundColor Red
  $errors | ForEach-Object { "  $_" }
  exit 1
}
if ($DryRun) { "`nTestlauf, nichts geändert." } else { "`nFertig." }
