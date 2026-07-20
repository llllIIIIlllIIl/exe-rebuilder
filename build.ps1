# Resolves to the script's own folder if run as a .ps1 file,
# or the current directory if pasted directly into the console.
$dir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

$filesDir  = Join-Path $dir "files"
$exportDir = Join-Path $dir "export folder"

if (-not (Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir | Out-Null
}

# 1) Build payload.7z from everything in "files", flattened to the archive root
$payloadPath = Join-Path $dir "payload.7z"
if (Test-Path $payloadPath) { Remove-Item $payloadPath -Force }

Push-Location $filesDir
& (Join-Path $dir "7za.exe") a -t7z "$payloadPath" *
Pop-Location

# 2) Write the install config: silently extract + auto-run app.exe
$configContent = ";!@Install@!UTF-8!`nRunProgram=`"app.exe`"`nProgress=`"no`"`n;!@InstallEnd@!"
$utf8 = [System.Text.Encoding]::UTF8
$configBytes = $utf8.GetPreamble() + $utf8.GetBytes($configContent)
[System.IO.File]::WriteAllBytes((Join-Path $dir "config.7z.ini"), $configBytes)

# 3) Glue 7zSD.sfx + config + payload.7z together
$sfxModule  = [System.IO.File]::ReadAllBytes((Join-Path $dir "7zSD.sfx"))
$configData = [System.IO.File]::ReadAllBytes((Join-Path $dir "config.7z.ini"))
$archive    = [System.IO.File]::ReadAllBytes($payloadPath)

$total = $sfxModule.Length + $configData.Length + $archive.Length
$final = New-Object byte[] $total
[Array]::Copy($sfxModule, $final, $sfxModule.Length)
[Array]::Copy($configData, 0, $final, $sfxModule.Length, $configData.Length)
[Array]::Copy($archive, 0, $final, $sfxModule.Length + $configData.Length, $archive.Length)

$rebuiltPath = Join-Path $exportDir "rebuilt.exe"
[System.IO.File]::WriteAllBytes($rebuiltPath, $final)
Write-Output "Done. $rebuiltPath = $($final.Length) bytes"

# 4) Only delete payload.7z once rebuilt.exe is confirmed on disk
if (Test-Path $rebuiltPath) {
    Remove-Item $payloadPath -Force
    Write-Output "payload.7z removed."
} else {
    Write-Warning "rebuilt.exe wasn't created   keeping payload.7z for debugging."
}