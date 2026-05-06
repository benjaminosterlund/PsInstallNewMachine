    if (-not (Confirm-Action -Message "Open VS Code now and login with your GitHub account?")) {
        Write-Host "Skipping VS Code login step."
        return
    }

    $codeCommand = Get-Command code -ErrorAction SilentlyContinue
    if (-not $codeCommand) {
        Write-Warning "The 'code' command is not available. Open VS Code manually and sign in."
        Write-host "To enable the 'code' command, open VS Code, press Ctrl+Shift+P (CMD+Shift+P on Mac), and run the 'Shell Command: Install 'code' command in PATH' command." -ForegroundColor Yellow
    }

    & $codeCommand.Source
    Read-Host "Log into VS Code with your GitHub account and press Enter to continue"