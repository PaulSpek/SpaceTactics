# Copy to local.settings.ps1 and customize. This file is intentionally not committed.
# Do not store credentials in this file; use SSH keys and PuTTY saved sessions instead.

$SpaceTacticsSettings = @{
    RemoteUser  = 'your-windows-user'
    RemoteHost  = 'quartus-workstation.local'
    RemoteRepo  = 'D:\Projects\SpaceTactics'
    QuartusSh   = 'D:\intelFPGA_lite\17.0\quartus\bin64\quartus_sh.exe'
    QuartusMap  = 'D:\intelFPGA_lite\17.0\quartus\bin64\quartus_map.exe'
    Revision    = 'SpaceTactics'
    LocalRbf    = 'C:\tmp\SpaceTactics.rbf'
    LocalReport = 'C:\tmp\SpaceTactics.remote.map.rpt'
    MisterHost  = 'mister.local'
    MisterUser  = 'root'
    MisterPath  = '/media/fat/_Arcade/SpaceTactics.rbf'
    Pscp        = 'C:\Program Files\PuTTY\pscp.exe'
    Plink       = 'C:\Program Files\PuTTY\plink.exe'
}

