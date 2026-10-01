param(
    [Parameter(Mandatory=$true)][string]$Testbench,
    [Parameter(Mandatory=$true)][string[]]$Sources,
    [string]$ModelSim = 'D:\intelFPGA_lite\17.0\modelsim_ase\win32aloem'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$SimRoot = Join-Path $RepoRoot 'sim'
$Work = Join-Path $SimRoot 'work'
if (-not (Test-Path -LiteralPath $ModelSim)) { throw "ModelSim not found: $ModelSim" }
if (Test-Path -LiteralPath $Work) { Remove-Item -Recurse -Force $Work }
Push-Location $SimRoot
try {
    & "$ModelSim\vlib.exe" work
    if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
    & "$ModelSim\vlog.exe" -sv @Sources
    if ($LASTEXITCODE -ne 0) { throw 'vlog failed' }
    & "$ModelSim\vsim.exe" -c $Testbench -do 'run -all; quit -f'
    if ($LASTEXITCODE -ne 0) { throw 'vsim failed' }
} finally { Pop-Location }
