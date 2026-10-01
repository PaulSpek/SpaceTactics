# Space Tactics for MiSTer

An in-progress FPGA implementation of the 1980s arcade game **Space Tactics** for the MiSTer DE10-Nano, informed by the corresponding MAME driver.

## Status

This is a first hardware revision. It includes the 8080 compatible CPU, MAME memory map, four scrolling video planes, palette PROM lookup, basic game inputs, MiSTer ROM loading, and a first-pass synthesized player-shot sound. The remaining discrete sounds, SN76477 model, BBD echo, cabinet lamps, score display, LED beam artwork, and accurate motor movement are still pending. The inherited 50.54945 MHz PLL output is divided to approximately 1.944 MHz CPU and 5.055 MHz pixel clocks; exact MAME timing and broader hardware testing remain to be done.

The first remote Quartus 17.0 full compile produced `output_files/SpaceTactics.rbf`, but TimeQuest reported unmet setup and hold timing (worst setup slack -45.509 ns; worst hold slack -332.672 ns, including inherited framework clock domains). Treat this bitstream as experimental; timing closure and on-device testing are still required.

## Layout

- rtl/ — synthesizable Verilog/SystemVerilog/VHDL.
- sim/ — test benches and simulation fixtures.
- roms/ — locally supplied ROMs; do not commit copyrighted game ROMs.
- docs/ — hardware-research notes and build/development documentation.
- scripts/ — inherited MiSTer build, remote compilation, transfer, and simulation helpers.

## Local configuration

Copy local.settings.example.ps1 to local.settings.ps1 and set paths and host names for your setup. It is deliberately ignored by Git: do not place passwords, tokens, or ROMs in tracked files.

## ROM preparation

The normal MiSTer installation uses `releases/Space Tactics.mra` and a legally
obtained `stactics.zip`. Put the MRA in `/media/fat/_Arcade/`, the RBF in
`/media/fat/_Arcade/cores/`, and the ZIP in `/media/fat/games/mame/`. Selecting
**Space Tactics** then assembles and loads the required ROM data automatically.

For direct development/debug loading without an MRA:

```powershell
python scripts/pack_mame_rom.py C:\path\to\stactics.zip roms\SpaceTactics.rom
```

The script validates the six program ROMs and `pr54` color PROM against the MAME CRCs and writes a 14 KiB bundle. Open the core's OSD and choose **Load assembled ROM**. Game ROMs and generated bundles are ignored by Git.

## Controls

Use **Define Space Tactics buttons** in the core OSD to map Fire, cabinet
buttons 2 through 7, Coin, and Start. The default gamepad mapping uses A/B/X/Y,
L/R, Select for Coin, and Start for Start. The D-pad controls the aiming motor.

## Build

The MiSTer framework and TV80 CPU were inherited from the Exidy Sorcerer project. Quartus Prime Lite 17.0 targets the DE10-Nano:

```powershell
& 'D:\intelFPGA_lite\17.0\quartus\bin64\quartus_sh.exe' --flow compile SpaceTactics
```

For the faster Windows workstation, use the example settings. The script sends the Quartus source tree, builds remotely, and fetches the RBF:

```powershell
. .\local.settings.ps1
.\scripts\remote_compile.ps1 @SpaceTacticsRemoteBuild
```

Deployment is a separate step after inspecting the build result:

```powershell
.\scripts\transfer_to_mister.ps1 @SpaceTacticsTransfer
```

If these machine settings change, edit the ignored `local.settings.ps1`. The tracked example shows the same schema without local host details.

See [MAME research](docs/mame-research.md) for hardware mapping and the remaining implementation gaps.
