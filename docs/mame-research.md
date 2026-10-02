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
| ROM set | MAME `ROM_START(stactics)` | Six 2 KiB program ROMs, `pr54` color PROM, and `epr-217` beam ROM are used now. Never commit ROM images. |

## Known gaps

- MAME itself flags discrete and 76477 sound as missing. The MiSTer core now
  gives `0x604x` player fire and the two MAME beam arrival thresholds separate
  synthesized voices, matching the service manual's distinct PLAYER SHOT SOUND
  and SHOT ARRIVE PULSE labels. The other effects, SN76477 model, and BBD echo
  are still pending.
- The cabinet's LED fire beam is rendered as two in-raster converging rails using
  `epr-217`. A single red aiming pixel and a 16-line Energy Barrier, six-digit
  score, and round dashboard strip are rendered from their live latches. The
  dashboard is centred with 24-pixel horizontal safety margins and is visible
  only while the game motor is active. The playfield is not rescaled: source
  lines 8 through 223 are shown directly, cropping eight lines at both the top
  and bottom.
- Mechanical mirror movement now shifts the composed picture and supplies the
  position/status reads; its speed and limits still need hardware verification.
- Pixel and CPU clocks use simple divisors of the inherited 50.54945 MHz PLL, giving a slightly slower frame rate than MAME's crystal derived timings.
- Hardware gameplay with the user supplied ROM set has not yet been verified.
