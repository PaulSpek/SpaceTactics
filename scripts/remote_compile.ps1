param(
    [Parameter(Mandatory=$true)][string]$RemoteUser,
    [Parameter(Mandatory=$true)][string]$RemoteHost,
    [Parameter(Mandatory=$true)][string]$RemoteRepo,
    [Parameter(Mandatory=$true)][string]$QuartusSh,
    [Parameter(Mandatory=$true)][string]$Revision,
    [Parameter(Mandatory=$true)][string]$LocalRbf,
    [switch]$NoSync,
    [switch]$NoFetch
)

$ErrorActionPreference = 'Stop'

function Invoke-CheckedCommand {
    param([string[]]$Command)
    Write-Host "> $($Command -join ' ')"
    & $Command[0] @($Command | Select-Object -Skip 1)
    if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
}

function ConvertTo-EncodedPowerShellCommand {
    param([string]$Command)
    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $NoSync) {
    $remoteTarget = "${RemoteUser}@${RemoteHost}:$RemoteRepo/"
    Get-ChildItem -LiteralPath $RepoRoot -File -Include '*.qpf','*.qsf','*.sdc','*.sv','*.v','*.qip' |
        ForEach-Object { Invoke-CheckedCommand @('scp', $_.FullName, $remoteTarget) }
    foreach ($directory in 'rtl','sys') {
        $source = Join-Path $RepoRoot $directory
        if (Test-Path -LiteralPath $source) { Invoke-CheckedCommand @('scp', '-r', $source, $remoteTarget) }
    }
}

$remoteCommand = @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath '$RemoteRepo'
`$rbf = Join-Path (Join-Path '$RemoteRepo' 'output_files') '$Revision.rbf'
if (Test-Path -LiteralPath `$rbf) { Remove-Item -LiteralPath `$rbf -Force }
& '$QuartusSh' --flow compile '$Revision'
if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
if (-not (Test-Path -LiteralPath `$rbf)) { throw "Compile completed but RBF was not produced: `$rbf" }
Get-Item -LiteralPath `$rbf | Select-Object FullName, Length, LastWriteTime
"@

Invoke-CheckedCommand @('ssh', "${RemoteUser}@${RemoteHost}", 'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', (ConvertTo-EncodedPowerShellCommand $remoteCommand))

if (-not $NoFetch) {
    $localDir = Split-Path -Parent $LocalRbf
    if (-not (Test-Path -LiteralPath $localDir)) { New-Item -ItemType Directory -Path $localDir | Out-Null }
    Invoke-CheckedCommand @('scp', "${RemoteUser}@${RemoteHost}:$RemoteRepo/output_files/$Revision.rbf", $LocalRbf)
}
