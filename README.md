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

## ROM preparation

The normal MiSTer installation uses `releases/Space Tactics.mra` and a legally
obtained `stactics.zip`. Put the MRA in `/media/fat/_Arcade/`, the RBF in
`/media/fat/_Arcade/cores/`, and the ZIP in `/media/fat/games/mame/`. Selecting
**Space Tactics** then assembles and loads the required ROM data automatically.

## Controls

Use **Define Space Tactics buttons** in the core OSD to map Fire, cabinet
buttons 2 through 7, Coin, and Start. The default gamepad mapping uses A/B/X/Y,
L/R, Select for Coin, and Start for Start. The D-pad controls the aiming motor.

See [MAME research](docs/mame-research.md) for hardware mapping and the remaining implementation gaps.
