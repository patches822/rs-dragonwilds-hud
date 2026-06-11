<#
.SYNOPSIS
    Installs DragonwildsHUD into a local UE4SS-modded copy of RuneScape: Dragonwilds.

.DESCRIPTION
    Locates the game's UE4SS Mods folder (auto-detecting common Steam install locations,
    or using -GamePath if provided), creates a directory junction pointing
    Mods\DragonwildsHUD at this repo (so edits here take effect immediately), and
    registers the mod in mods.txt.

.PARAMETER GamePath
    Path to the RSDragonwilds installation folder (the folder containing
    "Binaries\Win64\ue4ss"). If not provided, common Steam library locations are searched.

.EXAMPLE
    .\install.ps1

.EXAMPLE
    .\install.ps1 -GamePath "C:\Program Files (x86)\Steam\steamapps\common\RSDragonwilds\RSDragonwilds"
#>
param(
    [string]$GamePath
)

function Find-GamePath {
    $candidates = [System.Collections.Generic.List[string]]::new()

    # Steam library folders, discovered via the registry.
    $steamRoots = [System.Collections.Generic.List[string]]::new()
    foreach ($key in @("HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam", "HKLM:\SOFTWARE\Valve\Steam")) {
        $steamPath = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).SteamPath
        if ($steamPath) { $steamRoots.Add($steamPath) }
    }

    foreach ($steamRoot in $steamRoots) {
        $steamRoot = $steamRoot -replace '/', '\'
        $candidates.Add($steamRoot)

        $libraryFile = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path $libraryFile) {
            $matches = Select-String -Path $libraryFile -Pattern '"path"\s+"(.+?)"'
            foreach ($m in $matches) {
                $libPath = $m.Matches[0].Groups[1].Value -replace '\\\\', '\'
                $candidates.Add($libPath)
            }
        }
    }

    foreach ($root in $candidates) {
        $gamePath = Join-Path $root "steamapps\common\RSDragonwilds\RSDragonwilds"
        if (Test-Path (Join-Path $gamePath "Binaries\Win64\ue4ss")) {
            return $gamePath
        }
    }

    return $null
}

if (-not $GamePath) {
    $GamePath = Find-GamePath
}

if (-not $GamePath -or -not (Test-Path $GamePath)) {
    Write-Error "Could not locate the RSDragonwilds installation. Re-run with -GamePath pointing at your 'RSDragonwilds' folder, e.g.:`n  .\install.ps1 -GamePath `"C:\Program Files (x86)\Steam\steamapps\common\RSDragonwilds\RSDragonwilds`""
    exit 1
}

$ue4ssDir = Join-Path $GamePath "Binaries\Win64\ue4ss"
if (-not (Test-Path $ue4ssDir)) {
    Write-Error "UE4SS doesn't appear to be installed at '$ue4ssDir'. Install UE4SS for RSDragonwilds before running this script."
    exit 1
}

$modsDir  = Join-Path $ue4ssDir "Mods"
$modLink  = Join-Path $modsDir "DragonwildsHUD"
$repoRoot = $PSScriptRoot
$modsFile = Join-Path $modsDir "mods.txt"

Write-Host "Installing to: $modsDir"

# Remove existing junction/directory if present
if (Test-Path $modLink) {
    Remove-Item $modLink -Force -Recurse
}

# Create a directory junction (no admin rights required)
# The junction points the mod folder at this repo root, so UE4SS reads Scripts\main.lua directly.
$result = cmd /c mklink /J "$modLink" "$repoRoot" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create junction: $result"
    exit 1
}
Write-Host "Junction created: $modLink -> $repoRoot"

# Add mod entry to mods.txt if not already present
$entry = "DragonwildsHUD : 1"
$content = Get-Content $modsFile -Raw -ErrorAction SilentlyContinue
if ($content -notmatch "DragonwildsHUD") {
    # Ensure a trailing newline exists before appending so the entry lands on its own line
    if ($content -and -not $content.EndsWith("`n")) {
        Add-Content -Path $modsFile -Value ""
    }
    Add-Content -Path $modsFile -Value $entry
    Write-Host "Added '$entry' to mods.txt"
} else {
    Write-Host "mods.txt already contains DragonwildsHUD entry"
}

Write-Host "Install complete. Launch the game and check UE4SS.log for '[DragonwildsHUD] Loaded'."
