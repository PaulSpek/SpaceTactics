param(
    [Parameter(Mandatory=$true)][string]$LocalRbf,
    [Parameter(Mandatory=$true)][string]$MisterHost,
    [string]$MisterUser = 'root',
    [Parameter(Mandatory=$true)][string]$MisterPath,
    [Parameter(Mandatory=$true)][string]$Pscp,
    [Parameter(Mandatory=$true)][string]$Plink,
    [string]$HostKey,
    [string]$Password,
    [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'
function Invoke-CheckedCommand {
    param([string[]]$Command)
    $display = @($Command)
    for ($i = 0; $i -lt $display.Count - 1; $i++) {
        if ($display[$i] -eq '-pw') { $display[$i + 1] = '***' }
    }
    Write-Host "> $($display -join ' ')"
    & $Command[0] @($Command | Select-Object -Skip 1)
    if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
}
if (-not (Test-Path -LiteralPath $LocalRbf)) { throw "RBF not found: $LocalRbf" }

$hostKeyArgs = if ($HostKey) { @('-hostkey', $HostKey) } else { @() }
$passwordArgs = if ($Password) { @('-pw', $Password) } else { @() }
Invoke-CheckedCommand (@($Pscp, '-batch', '-scp') + $hostKeyArgs + $passwordArgs + @($LocalRbf, "${MisterUser}@${MisterHost}:$MisterPath"))
if (-not $NoVerify) {
    Invoke-CheckedCommand (@($Plink, '-batch', '-ssh') + $hostKeyArgs + $passwordArgs + @('-l', $MisterUser, $MisterHost, "ls -l '$MisterPath'; sha256sum '$MisterPath'"))
}
