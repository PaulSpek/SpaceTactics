param(
    [string]$QuartusSh = 'D:\intelFPGA_lite\17.0\quartus\bin64\quartus_sh.exe',
    [string]$Revision = 'SpaceTactics'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $RepoRoot
& $QuartusSh --flow compile $Revision
exit $LASTEXITCODE
