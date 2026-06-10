$modsDir  = "D:\Steam\steamapps\common\RSDragonwilds\RSDragonwilds\Binaries\Win64\ue4ss\Mods"
$modLink  = Join-Path $modsDir "DragonwildsHUD"
$repoRoot = $PSScriptRoot
$modsFile = Join-Path $modsDir "mods.txt"

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
