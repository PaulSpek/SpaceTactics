# Copy to local.settings.ps1, then dot-source it with: . .\local.settings.ps1
# Local settings are ignored by Git. Use SSH keys or a PuTTY saved session.

$SpaceTacticsRemoteBuild = @{
    RemoteUser = 'your-windows-user'
    RemoteHost = 'quartus-workstation.local'
    RemoteRepo = 'D:\Projects\SpaceTactics'
    QuartusSh  = 'D:\intelFPGA_lite\17.0\quartus\bin64\quartus_sh.exe'
    Revision   = 'SpaceTactics'
    LocalRbf   = 'C:\tmp\SpaceTactics.rbf'
}

$SpaceTacticsRemoteAnalysis = @{
    RemoteUser  = $SpaceTacticsRemoteBuild.RemoteUser
    RemoteHost  = $SpaceTacticsRemoteBuild.RemoteHost
    RemoteRepo  = $SpaceTacticsRemoteBuild.RemoteRepo
    QuartusMap  = 'D:\intelFPGA_lite\17.0\quartus\bin64\quartus_map.exe'
    Revision    = $SpaceTacticsRemoteBuild.Revision
    LocalReport = 'C:\tmp\SpaceTactics.remote.map.rpt'
}

$SpaceTacticsTransfer = @{
    LocalRbf   = $SpaceTacticsRemoteBuild.LocalRbf
    MisterHost = 'mister.local'
    MisterUser = 'root'
    # Store the MiSTer password only in local.settings.ps1, which is ignored.
    Password   = ''
    MisterPath = '/media/fat/_Arcade/cores/SpaceTactics.rbf'
    Pscp       = 'C:\Program Files\PuTTY\pscp.exe'
    Plink      = 'C:\Program Files\PuTTY\plink.exe'
}
