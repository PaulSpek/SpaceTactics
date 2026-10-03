# MAME research log

Primary source: [MAME Space Tactics driver](https://github.com/mamedev/mame/blob/0e0e3b864952e230fca5e591cf8518e58b7b4a32/src/mame/sega/stactics.cpp), revision `0e0e3b864952e230fca5e591cf8518e58b7b4a32`. The MAME driver is BSD-3-Clause. This project implements its documented hardware behavior in RTL.

## Implemented in first revision

- 8080 compatible TV80 core in Mode 2; main ROM at 0000-2fff.
- 256 byte work RAM mirrored through 4000-47ff.
- Read ports and addressed output latches from 5000 through a000.
- Four 4 KiB video RAM planes at b000, d000, e000, and f000.
- Tile and graphics address formation, three scrolling planes, palette bank and color PROM.
- 256 x 232 visible picture from the source raster; the RTL now uses a 336 x 262 output timing with a 32-pixel horizontal sync pulse and retains the 256-pixel active image.

## Still to establish

- Exact cabinet crystal/divider values and CRT geometry.
- Mechanical mirror calibration, beam LED optical spacing, and dashboard dimensions.
- Discrete sound component values and cabinet recordings for final tuning.
- Any protection, discrete logic, or undocumented behavior.

## Evidence

| Topic | Source | Notes |
| --- | --- | --- |
| Driver | MAME `src/mame/sega/stactics.cpp` at revision above | Set name `stactics`. |
| PCB / schematics | TBD | |
| ROM set | MAME `ROM_START(stactics)` | Six 2 KiB program ROMs, `pr54` color PROM, and `epr-217` beam ROM are used now. Never commit ROM images. |

## Known gaps

- MAME itself flags the discrete sound system as missing. The MiSTer core now
  models the service-manual control groups: `0x604x` fire, two beam-arrival
  thresholds, five secondary sound latches, the 76477-style invader voice,
  and one MN3005-style echo path. The analog values remain bounded RTL
  approximations and need cabinet recordings for final calibration.
- The cabinet's LED fire beam is rendered as two shallow traces entering from
  the left and right edges and converging near the red one-pixel sight. The
  `epr-217` ROM still controls the lit segments. The 16-line Energy Barrier,
  six-digit score, and round dashboard are rendered from live latches and are
  shown only while the game motor is active; attract mode receives the full
  raster area.
- The current output timing uses a 336-pixel line and 262 lines per frame,
  with active video in the first 256 by 232 pixels. This is a practical CRT
  alignment choice, not a claim about the original cabinet's exact timing.
- Mechanical mirror movement shifts the composed picture and supplies the
  position/status reads; its speed and limits still need hardware verification.
- Pixel and CPU clocks use simple divisors of the inherited 50.54945 MHz PLL;
  timing reports still contain inherited cross-domain setup/hold violations.
- Hardware gameplay with the user supplied ROM set, final CRT centering, and
  subjective sound fidelity still require on-device verification.
