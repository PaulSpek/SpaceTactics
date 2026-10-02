# Space Tactics sound control matrix

This matrix records the controls visible to the game CPU and the evidence used
for the first MiSTer sound milestone. It deliberately distinguishes verified
address behavior from inferred analog effect behavior.

## Evidence

- Current MAME driver:
  <https://github.com/mamedev/mame/blob/master/src/mame/sega/stactics.cpp>
- Service manual:
  <https://manualzz.com/doc/13471560/gremlin-sega-space-tactics-video-game-owner-s-manual>
- Static scan of the user's assembled `SpaceTactics.rom`; ROM bytes and
  disassembly are not committed.

## Primary LS259 audio latch

Writes to `0x6010-0x6017` store data bit 0 in the addressed latch output. The
board mirrors this decode through the rest of the `0x6xxx` range as documented
by MAME.

| Address | Latch | MAME label | Current use | Confidence |
| --- | --- | --- | --- | --- |
| `0x6010` | Q0 | MUTE | High suppresses generated audio | Medium; polarity inferred from label |
| `0x6011` | Q1 | INV. DISTANCE A | Preserved, not synthesized yet | High address/label; effect pending |
| `0x6012` | Q2 | INV. DISTANCE B | Preserved, not synthesized yet | High address/label; effect pending |
| `0x6013` | Q3 | UFO | Preserved, not synthesized yet | High address/label; behavior pending |
| `0x6014` | Q4 | INVADER | Preserved, not synthesized yet | High address/label; behavior pending |
| `0x6015` | Q5 | EMERGENCY | Preserved, not synthesized yet | High address/label; behavior pending |
| `0x6016` | Q6 | motor / rocket overlap | Continues to control mirror motor; rocket pending | High |
| `0x6017` | Q7 | SOUND ON | High enables generated gameplay audio | Medium; polarity inferred from label |

The ROM contains direct `STA` writes to Q0 and Q3-Q7. Q1/Q2 may be reached by
computed addressing or other instruction sequences and remain implemented as
normal latch outputs.

## Player shot and beam control

| Address group | Behavior | Current implementation | Confidence |
| --- | --- | --- | --- |
| `0x6040-0x604f` | Fire-beam/shot trigger | One-cycle player-shot trigger and existing beam start | High |
| `0x6050-0x605f` | Clear shot-arrival flag | Existing beam/status behavior; no direct sound effect | High |

The service manual's sound-board schematic labels **PLAYER SHOT SOUND** and
**SHOT ARRIVE PULSE** separately. It also lists two MN3101/MN3005 BBD pairs,
an MB4391, an AN6551, a 94560, an SN76477, and three LM324s. MAME's beam-state
logic identifies two arrival thresholds (`0x08b` and `0x0ca`) and notes that
they are sound triggers not yet implemented there. The current core therefore
uses the hardware event timing rather than an artificial gap in one oscillator:

- A `0x604x` write immediately starts a short, descending high fire voice.
- Each emulated beam arrival threshold starts/restarts a distinct lower,
  longer, lightly noise-coloured arrival voice.

This is a synthesis approximation informed by the supplied recording and
schematic signal names, not an SN76477/BBD netlist emulation. The two voices may
overlap at their real beam timing, but are independently triggered and shaped.

## Secondary sound writes

MAME leaves `sound2_w` commented out, so effect names and pulse/level semantics
are not yet established. Static ROM scanning confirms these direct writes:

| Address | Direct ROM write sites | Current implementation |
| --- | --- | --- |
| `0x60a0` | `0x0a6f`, `0x19a2` | One-cycle secondary pulse A |
| `0x60b0` | `0x0d42`, `0x1992` | One-cycle secondary pulse B |
| `0x60c4` | `0x0d2b`, `0x1a75` | One-cycle secondary pulse C |
| `0x60d0` | `0x0b23` | One-cycle secondary pulse D |
| `0x60e0` | `0x046f`, `0x11c3`, `0x1203`, `0x1264`, `0x126d` | One-cycle secondary pulse E |

The control module preserves the five address groups as testable pulses, but
they intentionally produce no audio until schematic tracing assigns them to
specific bomb, explosion, hit, rocket, or character circuits. The `0x60c4`
low-nibble distinction must be retained when that mapping is implemented.

## Diagnostic control

The MiSTer OSD command `Test player-shot sound` produces the same test voice
without depending on Q0/Q7 state. This distinguishes audio-output problems from
game-latch or ROM-execution problems. It is edge-triggered and does not alter
the emulated CPU-visible latch.

## First-milestone status

- CPU sound latch extracted into `rtl/stactics_sound_ctrl.sv`.
- Five secondary write groups decoded and simulation-tested.
- Independent player-fire and beam-arrival generators implemented in
  `rtl/stactics_sound.sv`.
- Signed dual-mono output connected to MiSTer.
- Mute, sound enable, saturation, reset, and diagnostic behavior tested.
- Existing board/video and CPU-bus simulations pass.
- Remote Quartus analysis and full compilation complete with zero errors.
- Timing is still not closed; this is a pre-existing project-level issue.
