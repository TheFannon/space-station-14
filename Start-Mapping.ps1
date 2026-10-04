# Starts SS14 Tools server + client for local mapping.
$ErrorActionPreference = "Stop"
$LogPath = Join-Path $PSScriptRoot "Start-Mapping.log"

function Write-Log([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

try {
    Set-Content -LiteralPath $LogPath -Value ("Start-Mapping log {0}" -f (Get-Date)) -Encoding UTF8

    $RepoRoot = $PSScriptRoot
    Set-Location -LiteralPath $RepoRoot
    Write-Log ("Repo: {0}" -f $RepoRoot)

    # Ensure tools are on PATH even when launched from Explorer
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"

    $dotnet = Get-Command "dotnet" -ErrorAction SilentlyContinue
    if (-not $dotnet) {
        throw ".NET SDK not found on PATH. Install Microsoft.DotNet.SDK.10, then try again."
    }
    Write-Log ("dotnet: {0}" -f $dotnet.Source)

    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot "Content.Server\Content.Server.csproj"))) {
        throw "Content.Server project not found. Is ss14-startrek complete?"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot "Content.Client\Content.Client.csproj"))) {
        throw "Content.Client project not found. Is ss14-startrek complete?"
    }

    $port = 1212
    $alreadyUp = $false
    try {
        $alreadyUp = [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
    } catch {
        Write-Log "Note: could not query TCP ports; will start server anyway."
    }

    if ($alreadyUp) {
        Write-Log ("Server already listening on port {0} - starting client only." -f $port)
    } else {
        Write-Log "Starting Tools server window..."
        $serverCmd = 'title SS14 StarTrek Server (Tools) & echo Starting Content.Server Tools... & dotnet run --project Content.Server --configuration Tools & echo. & echo Server process ended. & pause'
        Start-Process -FilePath "cmd.exe" -ArgumentList @("/k", $serverCmd) -WorkingDirectory $RepoRoot

        Write-Log ("Waiting for server on localhost:{0} (first launch can take several minutes)..." -f $port)
        $deadline = (Get-Date).AddMinutes(10)
        $ready = $false
        while ((Get-Date) -lt $deadline) {
            try {
                $listening = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
                if ($listening) {
                    $ready = $true
                    break
                }
            } catch {
                # Fall back below if cmdlet fails repeatedly
            }

            # Fallback check that does not require Get-NetTCPConnection
            $tcp = $null
            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $iar = $tcp.BeginConnect("127.0.0.1", $port, $null, $null)
                $ok = $iar.AsyncWaitHandle.WaitOne(500, $false)
                if ($ok -and $tcp.Connected) {
                    $ready = $true
                    $tcp.Close()
                    break
                }
            } catch {
            } finally {
                if ($tcp) { $tcp.Dispose() }
            }

            Start-Sleep -Seconds 2
        }

        if (-not $ready) {
            throw ("Server did not open port {0} in time. Check the Server window and Start-Mapping.log." -f $port)
        }

        Write-Log "Server is up."
    }

    Write-Log "Starting Tools client window..."
    $clientCmd = 'title SS14 StarTrek Client (Tools) & echo Starting Content.Client Tools... & dotnet run --project Content.Client --configuration Tools & echo. & echo Client process ended. & pause'
    Start-Process -FilePath "cmd.exe" -ArgumentList @("/k", $clientCmd) -WorkingDirectory $RepoRoot

    Write-Log "Both windows are launching."
    Write-Host ""
    Write-Host "In the client: Direct Connect to localhost (port $port)."
    Write-Host "Mapping tips once connected:"
    Write-Host "  mapping 1000"
    Write-Host "  F5 = entities, F6 = tiles"
    Write-Host "  savemap when finished"
    Write-Host ""
    Write-Host "Leave the Server/Client windows open while you work."
    Write-Host ("Log file: {0}" -f $LogPath)
    Write-Host ""
    Write-Host "This launcher window will close in 20 seconds (or press Enter now)."
    try {
        $null = Read-Host
    } catch {
        Start-Sleep -Seconds 20
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    try { Write-Log ("ERROR: {0}" -f $_.Exception.Message) } catch {}
    Write-Host ""
    Write-Host ("Log file: {0}" -f $LogPath)
    Write-Host "Press Enter to close..."
    try { $null = Read-Host } catch { Start-Sleep -Seconds 30 }
    exit 1
}
