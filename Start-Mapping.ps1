# Starts SS14 Tools server + client for local mapping.
$ErrorActionPreference = "Stop"
$LogPath = Join-Path $PSScriptRoot "Start-Mapping.log"

function Write-Log([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

function Invoke-DotNet([string[]]$DotNetArgs, [string]$Label) {
    Write-Log $Label
    Write-Host ("Running: dotnet {0}" -f ($DotNetArgs -join " "))
    & dotnet @DotNetArgs
    if ($LASTEXITCODE -ne 0) {
        throw ("{0} failed with exit code {1}." -f $Label, $LASTEXITCODE)
    }
}

try {
    Set-Content -LiteralPath $LogPath -Value ("Start-Mapping log {0}" -f (Get-Date)) -Encoding UTF8

    $RepoRoot = $PSScriptRoot
    Set-Location -LiteralPath $RepoRoot
    Write-Log ("Repo: {0}" -f $RepoRoot)

    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"

    $dotnet = Get-Command "dotnet" -ErrorAction SilentlyContinue
    if (-not $dotnet) {
        throw ".NET SDK not found on PATH. Install Microsoft.DotNet.SDK.10, then try again."
    }
    Write-Log ("dotnet: {0}" -f $dotnet.Source)

    $serverProj = Join-Path $RepoRoot "Content.Server\Content.Server.csproj"
    $clientProj = Join-Path $RepoRoot "Content.Client\Content.Client.csproj"
    if (-not (Test-Path -LiteralPath $serverProj)) { throw "Content.Server project not found." }
    if (-not (Test-Path -LiteralPath $clientProj)) { throw "Content.Client project not found." }

    Write-Host ""
    Write-Host "Building Tools projects first so launch is not a silent wait..."
    Write-Host "You should see compile output below. This can take a few minutes on first run."
    Write-Host ""

    Invoke-DotNet @("build", $serverProj, "-c", "Tools") "Building Content.Server (Tools)"
    Invoke-DotNet @("build", $clientProj, "-c", "Tools") "Building Content.Client (Tools)"

    $port = 1212
    $alreadyUp = $false
    try {
        $alreadyUp = [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
    } catch {}

    if ($alreadyUp) {
        Write-Log ("Port {0} already in use - starting client only." -f $port)
    } else {
        Write-Log "Opening Server window..."
        $serverCmd = 'title SS14 StarTrek Server (Tools) & echo Starting Content.Server Tools... & dotnet run --project Content.Server --configuration Tools --no-build & echo. & echo Server process ended. & pause'
        Start-Process -FilePath "cmd.exe" -ArgumentList @("/k", $serverCmd) -WorkingDirectory $RepoRoot
    }

    Write-Log "Opening Client window..."
    $clientCmd = 'title SS14 StarTrek Client (Tools) & echo Starting Content.Client Tools... & dotnet run --project Content.Client --configuration Tools --no-build & echo. & echo Client process ended. & pause'
    Start-Process -FilePath "cmd.exe" -ArgumentList @("/k", $clientCmd) -WorkingDirectory $RepoRoot

    Write-Host ""
    Write-Host "Server and Client windows should now be open."
    Write-Host "Wait until the Server window finishes loading, then in the Client:"
    Write-Host "  Direct Connect -> localhost"
    Write-Host ""
    Write-Host "Mapping tips once connected:"
    Write-Host "  mapping 1000"
    Write-Host "  F5 = entities, F6 = tiles"
    Write-Host "  savemap when finished"
    Write-Host ""
    Write-Host ("Log: {0}" -f $LogPath)
    Write-Host "Press Enter to close this launcher window..."
    try { $null = Read-Host } catch { Start-Sleep -Seconds 15 }
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    try { Write-Log ("ERROR: {0}" -f $_.Exception.Message) } catch {}
    Write-Host ("Log: {0}" -f $LogPath)
    Write-Host "Press Enter to close..."
    try { $null = Read-Host } catch { Start-Sleep -Seconds 30 }
    exit 1
}
