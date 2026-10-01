param(
    [Parameter(Mandatory=$true)][string]$RemoteUser,
    [Parameter(Mandatory=$true)][string]$RemoteHost,
    [Parameter(Mandatory=$true)][string]$RemoteRepo,
    [Parameter(Mandatory=$true)][string]$QuartusSh,
    [Parameter(Mandatory=$true)][string]$Revision,
    [Parameter(Mandatory=$true)][string]$LocalRbf,
    [Parameter(Mandatory=$true)][string]$MisterHost,
    [Parameter(Mandatory=$true)][string]$MisterPath,
    [Parameter(Mandatory=$true)][string]$Pscp,
    [Parameter(Mandatory=$true)][string]$Plink,
    [string]$MisterUser = 'root',
    [string]$Password,
    [string]$HostKey,
    [switch]$NoSync,
    [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'
$compileArgs = @{ RemoteUser=$RemoteUser; RemoteHost=$RemoteHost; RemoteRepo=$RemoteRepo; QuartusSh=$QuartusSh; Revision=$Revision; LocalRbf=$LocalRbf; NoSync=$NoSync }
& (Join-Path $PSScriptRoot 'remote_compile.ps1') @compileArgs
$transferArgs = @{ LocalRbf=$LocalRbf; MisterHost=$MisterHost; MisterUser=$MisterUser; Password=$Password; MisterPath=$MisterPath; Pscp=$Pscp; Plink=$Plink; HostKey=$HostKey; NoVerify=$NoVerify }
& (Join-Path $PSScriptRoot 'transfer_to_mister.ps1') @transferArgs
