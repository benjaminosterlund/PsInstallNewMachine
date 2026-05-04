$ghCommand = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghCommand) {
    Write-Warning "gh command not found. Skipping GitHub CLI authentication."
    return
}

$null = & gh auth status 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "GitHub CLI is already authenticated."
    return
}

Write-Host "Starting GitHub CLI authentication..."
& gh auth login

if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI authentication failed."
}

Write-Host "GitHub CLI authentication complete."
