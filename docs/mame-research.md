# MAME research log

Primary source: [MAME Space Tactics driver](https://github.com/mamedev/mame/blob/0e0e3b864952e230fca5e591cf8518e58b7b4a32/src/mame/sega/stactics.cpp), revision `0e0e3b864952e230fca5e591cf8518e58b7b4a32`. The MAME driver is BSD-3-Clause. This project implements its documented hardware behavior in RTL.

## Implemented in first revision

- 8080 compatible TV80 core in Mode 2; main ROM at 0000-2fff.
- 256 byte work RAM mirrored through 4000-47ff.
- Read ports and addressed output latches from 5000 through a000.
- Four 4 KiB video RAM planes at b000, d000, e000, and f000.
- Tile and graphics address formation, three scrolling planes, palette bank and color PROM.
- 256 x 232 visible picture from MAME's 328 x 262 raster.

## Still to establish

- MAME driver/source path and game set name.
- CPU, clocks, memory map, ROM regions, and input DIP switches.
- Video timing, palette, tile/sprite/object hardware, and priority rules.
- Sound hardware and timing.
- Any protection, discrete logic, or undocumented behavior.

## Evidence

| Topic | Source | Notes |
| --- | --- | --- |
| Driver | MAME `src/mame/sega/stactics.cpp` at revision above | Set name `stactics`. |
| PCB / schematics | TBD | |
| ROM set | MAME `ROM_START(stactics)` | Six 2 KiB program ROMs and `pr54` color PROM are used now. Never commit ROM images. |

## Known gaps

- MAME itself flags discrete and 76477 sound as missing; audio output is silent.
- The cabinet's LED fire beam, score and indicator lamps are not yet rendered.
- Mechanical mirror movement is approximated only for position/status reads; picture shifting and timing need hardware verification.
- Pixel and CPU clocks use simple divisors of the inherited 50.54945 MHz PLL, giving a slightly slower frame rate than MAME's crystal derived timings.
- Hardware gameplay with the user supplied ROM set has not yet been verified.
