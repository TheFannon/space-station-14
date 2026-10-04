# Starts SS14 Tools server + client for local mapping.
$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
Set-Location -LiteralPath $RepoRoot

# Ensure tools are on PATH even when launched from Explorer
$machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$user = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machine;$user"

function Test-Command($Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Test-Command "dotnet")) {
    Write-Host "ERROR: .NET SDK not found. Install Microsoft.DotNet.SDK.10, then try again." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

$port = 1212
$alreadyUp = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($alreadyUp) {
    Write-Host "Server already listening on port $port — starting client only." -ForegroundColor Yellow
} else {
    Write-Host "Starting Tools server..." -ForegroundColor Cyan
    Start-Process -FilePath "cmd.exe" -ArgumentList @(
        "/k",
        "title SS14 StarTrek Server (Tools) && dotnet run --project Content.Server --configuration Tools"
    ) -WorkingDirectory $RepoRoot

    Write-Host "Waiting for server on localhost:$port (first launch can take a few minutes)..."
    $deadline = (Get-Date).AddMinutes(10)
    while ((Get-Date) -lt $deadline) {
        $listening = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($listening) { break }
        Start-Sleep -Seconds 2
    }

    if (-not (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: Server did not open port $port in time. Check the Server window for errors." -ForegroundColor Red
        Read-Host "Press Enter to close"
        exit 1
    }

    Write-Host "Server is up." -ForegroundColor Green
}

Write-Host "Starting Tools client..." -ForegroundColor Cyan
Start-Process -FilePath "cmd.exe" -ArgumentList @(
    "/k",
    "title SS14 StarTrek Client (Tools) && dotnet run --project Content.Client --configuration Tools"
) -WorkingDirectory $RepoRoot

Write-Host ""
Write-Host "Both windows are launching." -ForegroundColor Green
Write-Host "In the client: Direct Connect to localhost (port $port)."
Write-Host "Mapping tips once connected:"
Write-Host "  mapping 1000"
Write-Host "  F5 = entities, F6 = tiles"
Write-Host "  savemap when finished"
Write-Host ""
Write-Host "This window can be closed. Leave the Server/Client windows open while you work."
Start-Sleep -Seconds 8
