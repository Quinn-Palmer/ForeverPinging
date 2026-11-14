<#
.SYNOPSIS
  Installs ForeverPinging into the WoW: Forever AddOns folder for testing.

.DESCRIPTION
  -Mode Link   (default) Creates a directory junction AddOns\ForeverPinging -> this repo.
               Edits show up after /reload with no copying. No admin rights needed.
  -Mode Copy   Copies only the TOC and the files it lists (a clean, release-like install).
  -Mode Remove Removes the junction or the copied folder.

  The AddOns path defaults to the standard Battle.net location. Override it with
  -AddOnsPath or the FOREVER_ADDONS environment variable.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\install.ps1
  powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Mode Copy
  powershell -ExecutionPolicy Bypass -File tools\install.ps1 -Mode Remove
#>
param(
    [ValidateSet('Link', 'Copy', 'Remove')]
    [string]$Mode = 'Link',
    [string]$AddOnsPath
)

$ErrorActionPreference = 'Stop'

$AddonName = 'ForeverPinging'
$TocName   = 'ForeverPinging_Forever.toc'
$RepoRoot  = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if (-not $AddOnsPath) { $AddOnsPath = $env:FOREVER_ADDONS }
if (-not $AddOnsPath) {
    $AddOnsPath = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns'
}
if (-not (Test-Path -LiteralPath $AddOnsPath -PathType Container)) {
    throw "AddOns folder not found: $AddOnsPath  (pass -AddOnsPath or set FOREVER_ADDONS)"
}

$Target = Join-Path $AddOnsPath $AddonName

function Test-IsJunction([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    return $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

# Removes whatever is installed at $Target, but only if it is ours.
# A junction is removed with rmdir, which never touches the repo it points to
# (Remove-Item -Recurse on a junction in PowerShell 5.1 can delete the target's files).
function Remove-Install {
    if (-not (Test-Path -LiteralPath $Target)) { return }
    if (Test-IsJunction $Target) {
        cmd /c rmdir "`"$Target`"" | Out-Null
        if (Test-Path -LiteralPath $Target) { throw "Could not remove junction: $Target" }
        Write-Host "Removed junction $Target"
        return
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Target $TocName))) {
        throw "$Target exists but doesn't look like ForeverPinging (no $TocName). Not touching it."
    }
    Remove-Item -LiteralPath $Target -Recurse -Force
    Write-Host "Removed folder $Target"
}

switch ($Mode) {
    'Remove' {
        Remove-Install
    }
    'Link' {
        Remove-Install
        New-Item -ItemType Junction -Path $Target -Target $RepoRoot | Out-Null
        Write-Host "Linked $Target -> $RepoRoot"
        Write-Host 'Lua changes: /reload in game. TOC changes: restart the client.'
    }
    'Copy' {
        Remove-Install
        $toc = Join-Path $RepoRoot $TocName
        $files = @($TocName) + (Get-Content -LiteralPath $toc |
            Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' } |
            ForEach-Object { ($_ -replace '\s*\[.*$', '').Trim() })
        # Bindings.xml is auto-loaded by the client, so it isn't in the TOC.
        if (Test-Path -LiteralPath (Join-Path $RepoRoot 'Bindings.xml')) { $files += 'Bindings.xml' }
        foreach ($rel in $files) {
            $src = Join-Path $RepoRoot $rel
            if (-not (Test-Path -LiteralPath $src)) { throw "TOC lists a missing file: $rel" }
            $dst = Join-Path $Target $rel
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            Copy-Item -LiteralPath $src -Destination $dst
        }
        Write-Host "Copied $($files.Count) files to $Target"
        Write-Host 'Re-run after each change. TOC changes need a client restart.'
    }
}
