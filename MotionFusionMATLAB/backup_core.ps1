param([Parameter(Mandatory=$true)][string]$Label)
$ErrorActionPreference = 'Stop'
$sourceRoot = $PSScriptRoot
$safeLabel = $Label -replace '[^A-Za-z0-9_-]', '_'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$snapshotRoot = Join-Path $sourceRoot ('backups/' + $stamp + '_' + $safeLabel)
New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -File | Where-Object { $_.Extension -in '.m','.py','.ps1','.md' })
$sourceFiles += @(Get-ChildItem -LiteralPath (Join-Path $sourceRoot '+mfm') -File -Recurse)
$manifest = foreach ($sourceFile in $sourceFiles) {
    $relative = $sourceFile.FullName.Substring($sourceRoot.Length + 1)
    $destination = Join-Path $snapshotRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    $before = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
    Copy-Item -LiteralPath $sourceFile.FullName -Destination $destination
    $copied = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    $after = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
    if ($before -ne $copied -or $before -ne $after) { throw "Concurrent change or backup mismatch: $relative" }
    [pscustomobject]@{ path=$relative; sha256=$copied; bytes=$sourceFile.Length; sourceModifiedUtc=$sourceFile.LastWriteTimeUtc.ToString('o') }
}
@{ createdUtc=[DateTime]::UtcNow.ToString('o'); label=$Label; source=$sourceRoot; files=@($manifest) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $snapshotRoot 'manifest.json') -Encoding utf8
Write-Output "Verified source backup: $snapshotRoot ($($manifest.Count) files)"
