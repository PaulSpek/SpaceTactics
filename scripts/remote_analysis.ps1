param(
    [Parameter(Mandatory=$true)][string]$RemoteUser,
    [Parameter(Mandatory=$true)][string]$RemoteHost,
    [Parameter(Mandatory=$true)][string]$RemoteRepo,
    [Parameter(Mandatory=$true)][string]$QuartusMap,
    [Parameter(Mandatory=$true)][string]$Revision,
    [Parameter(Mandatory=$true)][string]$LocalReport,
    [switch]$NoFetch
)

$ErrorActionPreference = 'Stop'
function Invoke-CheckedCommand { param([string[]]$Command); & $Command[0] @($Command | Select-Object -Skip 1); if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" } }
$command = "Set-Location -LiteralPath '$RemoteRepo'; & '$QuartusMap' --analysis_and_elaboration '$Revision'; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
Invoke-CheckedCommand @('ssh', "${RemoteUser}@${RemoteHost}", 'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded)
if (-not $NoFetch) {
    $localDir = Split-Path -Parent $LocalReport
    if (-not (Test-Path -LiteralPath $localDir)) { New-Item -ItemType Directory -Path $localDir | Out-Null }
    Invoke-CheckedCommand @('scp', "${RemoteUser}@${RemoteHost}:$RemoteRepo/output_files/$Revision.map.rpt", $LocalReport)
}
