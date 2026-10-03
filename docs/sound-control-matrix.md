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
| `0x6011` | Q1 | INV. DISTANCE A | Selects one bit of the four-rate invader VCO model | High address/label; curve approximate |
| `0x6012` | Q2 | INV. DISTANCE B | Selects one bit of the four-rate invader VCO model | High address/label; curve approximate |
| `0x6013` | Q3 | UFO | Enables the modulated UFO oscillator | High address/label; waveform approximate |
| `0x6014` | Q4 | INVADER | Enables the game-specific 76477 model | High address/label; constants approximate |
| `0x6015` | Q5 | EMERGENCY | Enables the two-rate warning oscillator | High address/label; waveform approximate |
| `0x6016` | Q6 | motor / rocket overlap | Controls mirror motor and sustained rocket/noise path | High relationship; waveform approximate |
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
**SHOT ARRIVE PULSE** separately. The board assembly list identifies one MN3005
delay IC and one MN3101 clock driver, plus MB4391M switches/mixers, AN6551
amplifiers, a 94560AN, an SN76477 and an LM324. Quantities in the later table
are recommended spares for five games, not the count fitted to one board. MAME's beam-state
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
| `0x60a0` | `0x0a6f`, `0x19a2` | Independent one-shot A; provisional bomb-like voice |
| `0x60b0` | `0x0d42`, `0x1992` | Independent one-shot B; provisional UFO-hit-like voice |
| `0x60c4` | `0x0d2b`, `0x1a75` | Independent one-shot C; provisional invader-hit-like voice; low nibble retained |
| `0x60d0` | `0x0b23` | Independent one-shot D; separate upper/lower explosion mix |
| `0x60e0` | `0x046f`, `0x11c3`, `0x1203`, `0x1264`, `0x126d` | Independent one-shot E; provisional character/word voice |

The five circuits can overlap and no longer pre-empt one another. Their effect
names remain provisional because MAME has no handler and the scan does not make
every input net legible. The complete low nibble is retained for later tracing;
the known `0x60c4` form currently selects a distinct hit timbre.

## Analogue and output model

- `stactics_76477.sv` models the VCO, slow modulation, filtered noise and
  attack/decay blocks used by the invader path. Q1/Q2 select four VCO rates.
- `stactics_echo.sv` models one 4096-stage MN3005 path with low-pass loss,
  bounded feedback and an approximately 83 ms first repeat. The MN3101 is the
  clock driver, not a second delay line.
- Short effects feed the BBD send. Sustained rocket and warning beds do not,
  avoiding permanent feedback.
- Front and back mixes remain separate through MiSTer AUDIO_L and AUDIO_R.
  Explosion has separately shaped upper/lower contributions.
- Oscillator and filter constants remain schematic-informed approximations and
  should be tuned against direct cabinet captures when available.

## Diagnostic control

The MiSTer OSD command `Test player-shot sound` produces the same test voice
without depending on Q0/Q7 state. This distinguishes audio-output problems from
game-latch or ROM-execution problems. It is edge-triggered and does not alter
the emulated CPU-visible latch.

## First-milestone status

- CPU sound latch extracted into `rtl/stactics_sound_ctrl.sv`.
- Five independent secondary voices decoded and simulation-tested, including
  overlap and preservation of the low address nibble.
- Independent player-fire and beam-arrival generators implemented in
  `rtl/stactics_sound.sv`.
- Separate signed front/back mixes connected to MiSTer stereo output.
- Mute, sound enable, saturation, reset, and diagnostic behavior tested.
- Existing board/video and CPU-bus simulations pass.
- Remote Quartus analysis and full compilation complete with zero errors.
- Timing is still not closed; this is a pre-existing project-level issue.
