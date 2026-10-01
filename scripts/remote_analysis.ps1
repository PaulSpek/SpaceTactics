param(
    [Parameter(Mandatory=$true)][string]$RemoteUser,
    [Parameter(Mandatory=$true)][string]$RemoteHost,
    [Parameter(Mandatory=$true)][string]$RemoteRepo,
    [Parameter(Mandatory=$true)][string]$QuartusMap,
    [Parameter(Mandatory=$true)][string]$Revision,
    [Parameter(Mandatory=$true)][string]$LocalReport,
    [switch]$NoSync,
    [switch]$NoFetch
)

$ErrorActionPreference = 'Stop'
function Invoke-CheckedCommand { param([string[]]$Command); & $Command[0] @($Command | Select-Object -Skip 1); if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" } }
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $NoSync) {
    $remoteTarget = "${RemoteUser}@${RemoteHost}:$RemoteRepo/"
    Get-ChildItem -LiteralPath $RepoRoot -File |
        Where-Object { $_.Extension -in '.qpf','.qsf','.sdc','.sv','.v','.qip' } |
        ForEach-Object { Invoke-CheckedCommand @('scp', $_.FullName, $remoteTarget) }
    foreach ($directory in 'rtl','sys') {
        $source = Join-Path $RepoRoot $directory
        if (Test-Path -LiteralPath $source) { Invoke-CheckedCommand @('scp', '-r', $source, $remoteTarget) }
    }
}
$command = "Set-Location -LiteralPath '$RemoteRepo'; & '$QuartusMap' --analysis_and_elaboration '$Revision'; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
Invoke-CheckedCommand @('ssh', "${RemoteUser}@${RemoteHost}", 'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded)
if (-not $NoFetch) {
    $localDir = Split-Path -Parent $LocalReport
    if (-not (Test-Path -LiteralPath $localDir)) { New-Item -ItemType Directory -Path $localDir | Out-Null }
    Invoke-CheckedCommand @('scp', "${RemoteUser}@${RemoteHost}:$RemoteRepo/output_files/$Revision.map.rpt", $LocalReport)
}
