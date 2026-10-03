# Space Tactics for MiSTer

An in-progress FPGA implementation of the 1980s arcade game **Space Tactics** for the MiSTer DE10-Nano, informed by the corresponding MAME driver.

## Status

This is an experimental hardware revision. It includes the 8080 compatible CPU, MAME memory map, four scrolling video planes, palette PROM lookup, cabinet-style mirror movement, a single-pixel red aiming sight, shallow in-raster laser traces, and a compact game-only dashboard. MiSTer ROM loading, SN76477-inspired effects, MN3005-style echo, and separate shot/arrival voices are implemented. Timing closure and broader on-device testing remain to be done.

## Layout

- rtl/ — synthesizable Verilog/SystemVerilog/VHDL.
- sim/ — test benches and simulation fixtures.
- roms/ — locally supplied ROMs; do not commit copyrighted game ROMs.
- docs/ — hardware-research notes and build/development documentation.
- scripts/ — inherited MiSTer build, remote compilation, transfer, and simulation helpers.

## Build configuration

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

The script validates the six program ROMs, `pr54` color PROM, and `epr-217`
beam ROM against the MAME CRCs and writes a 16 KiB bundle. Open the core's OSD
and choose **Load assembled ROM**. Game ROMs and generated bundles are ignored
by Git.

## Controls

Use **Define Space Tactics buttons** in the core OSD to map Fire, cabinet
buttons 2 through 7, Coin, and Start. The default gamepad mapping uses A/B/X/Y,
L/R, Select for Coin, and Start for Start. The D-pad controls the aiming motor.

## Build and install

The MiSTer framework and TV80 CPU were inherited from the Exidy Sorcerer project. Use the configured remote Quartus workstation. The script sends the source tree, builds remotely, and fetches the RBF:

```powershell
. .\local.settings.ps1
.\scripts\remote_compile.ps1 @SpaceTacticsRemoteBuild
```

After the remote build succeeds, transfer the RBF to the MiSTer:

```powershell
.\scripts\transfer_to_mister.ps1 @SpaceTacticsTransfer
```

The transfer script installs the core at `/media/fat/_Arcade/cores/SpaceTactics.rbf`.

### MiSTer installation

1. Obtain a legally dumped `stactics.zip` matching the MAME set.
2. Copy `releases/Space Tactics.mra` to `/media/fat/_Arcade/`.
3. Copy `SpaceTactics.rbf` to `/media/fat/_Arcade/cores/`.
4. Copy `stactics.zip` to `/media/fat/games/mame/`.
5. From the MiSTer menu, open **Arcade** and select **Space Tactics**. The MRA assembles and loads the ROMs automatically.
6. Open the core OSD and use **Define Space Tactics buttons** to map the cabinet controls. The D-pad moves the aiming motor; Fire launches the laser; Coin and Start retain their normal arcade functions.

For a direct development load without the MRA, place a generated `roms/SpaceTactics.rom` in `/media/fat/_Arcade/Space Tactics/` and choose **Load assembled ROM** from the core OSD.

If machine settings change, edit the ignored `local.settings.ps1`. The tracked example shows the same schema without local host details.

See [MAME research](docs/mame-research.md) for hardware mapping and the remaining implementation gaps.
