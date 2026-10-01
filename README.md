# Space Tactics for MiSTer

An in-progress FPGA implementation of the 1980s arcade game **Space Tactics** for the MiSTer DE10-Nano, informed by the corresponding MAME driver.

## Status

Project scaffolding is in place. The next technical milestone is to identify the authoritative MAME driver, document the emulated hardware, and create a minimal CPU/video/audio implementation plan.

## Layout

- rtl/ — synthesizable Verilog/SystemVerilog/VHDL.
- sim/ — test benches and simulation fixtures.
- roms/ — locally supplied ROMs; do not commit copyrighted game ROMs.
- docs/ — hardware-research notes and build/development documentation.
- scripts/ — inherited MiSTer build, remote compilation, transfer, and simulation helpers.

## Local configuration

Copy local.settings.example.ps1 to local.settings.ps1 and set paths and host names for your setup. It is deliberately ignored by Git: do not place passwords, tokens, or ROMs in tracked files.

