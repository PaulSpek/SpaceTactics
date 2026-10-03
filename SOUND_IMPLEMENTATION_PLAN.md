# Space Tactics sound research and implementation plan

## Goal

Implement the original Sega/Gremlin *Space Tactics* sound system in the MiSTer
core, beginning with correctly triggered, recognizable effects and then improving
fidelity toward the original analog board.

The current core drives its audio outputs to zero, so silence is expected. This
is not a ROM problem: the arcade machine generated sound with analog/discrete
circuitry and an SN76477, not sample ROMs. Current MAME also marks the discrete
sound and SN76477 as unimplemented, so there is no finished MAME audio model to
port directly.

## Execution status

The first end-to-end milestone is implemented:

- the LS259 audio latch and five secondary trigger groups have a dedicated,
  tested control module;
- the player-shot path produces signed dual-mono MiSTer audio;
- mute, sound enable, reset, saturation, and an OSD diagnostic trigger are
  covered by simulation;
- existing board/video and CPU-bus regressions pass;
- remote Quartus compilation completes with zero errors;
- the RBF has been transferred and hash-verified on the MiSTer.

See `docs/sound-control-matrix.md` for address evidence and confidence levels.
The second milestone now adds independent secondary voices, a game-specific
SN76477 model, distance modulation, separate front/back mixes and a filtered
4096-stage MN3005-style echo. Exact component-derived tuning and definitive
naming of the five secondary strobes remain future work.

## Sources and findings

### Service manual and schematics

- Owner/service manual:
  <https://manualzz.com/doc/13471560/gremlin-sega-space-tactics-video-game-owner-s-manual>
- Alternate PDF:
  <https://arcarc.xmission.com/PDF_Misc/Gremlin%20Sega%20Service%20Notes/Space%20Tactics.pdf>

The manual includes sound-board schematics J through N, parts, repair notes, and
adjustments. It identifies circuits for UFO/UFO hit, invader/invader hit, player
fire, bomb, warning, explosion, rocket, character/word sound, BBD echo, and final
amplification.

Sound-board assembly 116-0009 (97211-P) includes:

| Device | Role to investigate/model |
| --- | --- |
| SN76477 | Tone, noise, modulation, mixing, and envelope generation |
| LM324 | Analog shaping and filtering |
| MB4391M | Analog switching/mixing |
| AN6551 | Analog amplifier/filter stages |
| MN3005 | Bucket-brigade delay line |
| MN3101 | MN3005 clock generator/driver |
| 94560AN | Sound-related device; exact role needs schematic tracing |

The manual has separate adjustments for lower/upper explosion, UFO hit, bomb,
player shot, invader, warning, invader hit, rocket, UFO, character, and BBD echo.
The HDL should keep these effects and gains separate even if the first release
exposes only a master volume.

### MAME driver

- Current source:
  <https://github.com/mamedev/mame/blob/master/src/mame/sega/stactics.cpp>

MAME documents two sound-control write groups:

- `0x6010-0x601f`: first sound-trigger/latch group
- `0x60a0-0x60e0`: second sound-trigger group

Its LS259-style audio latch has provisional labels:

| Bit | MAME label | Initial interpretation |
| --- | --- | --- |
| Q0 | MUTE | Global mute |
| Q1 | INV. DISTANCE A | Invader distance/rate control A |
| Q2 | INV. DISTANCE B | Invader distance/rate control B |
| Q3 | UFO | UFO enable/trigger |
| Q4 | INVADER | Invader enable/trigger |
| Q5 | EMERGENCY | Warning/emergency enable |
| Q6 | motor/rocket overlap | Cabinet motor/rocket relationship needs verification |
| Q7 | SOUND ON | Global sound enable |

Active polarity and level-versus-pulse behavior must be verified from the
schematics and CPU writes. These labels are evidence, not a complete behavior
specification.

### SN76477 guidance

- Reverse engineering:
  <https://www.righto.com/2017/04/reverse-engineering-76477-space.html>
- Follow-up analysis:
  <https://www.righto.com/2018/05/inside-76477-space-invaders-sound.html>

These describe the noise source, VCO, super-low-frequency oscillator, envelope,
mixer, and output stages and can guide a synchronous digital approximation.

### Supporting research

- MAMEWorld discussion:
  <https://www.mameworld.info/ubbthreads/showflat.php?Cat=1&Number=387388&o=&page=45&sb=5&vc=1&view=expanded>

This independently identifies the same components and manual pages. Its
emulation-status comments are historical; current MAME source is authoritative.

## Proposed FPGA architecture

Use one synchronous clock domain with clock-enable pulses for audio sample and
oscillator rates. Do not create clocks in FPGA fabric.

```text
CPU writes
   |
   v
address decode -> latch / edge detection -> effect generators
                                                |
                                                v
                                      per-effect gain + mix
                                                |
                                                v
                                       BBD-style echo (later)
                                                |
                                                v
                                      saturate -> AUDIO_L/R
```

Proposed modules:

| Module | Responsibility |
| --- | --- |
| `stactics_sound_ctrl.sv` | Decode writes, hold levels, create pulses, mute/enable |
| `stactics_76477.sv` | Game-specific SN76477 approximation |
| `stactics_discrete_sound.sv` | Shot, explosion, bomb, warning, rocket, hit, and character effects |
| `stactics_echo.sv` | Optional MN3005/MN3101 delay approximation |
| `stactics_sound.sv` | Integration, gain staging, signed mixing, and output |

## Implementation plan

### Phase 0: establish the control specification

1. Transcribe nets, component values, polarities, and trigger names from manual
   sheets J through N.
2. Trace every MAME sound-map write to a latch or pulse output.
3. Capture sound-range CPU writes during attract mode and gameplay, preferably
   in simulation; use static ROM disassembly as a first pass if necessary.
4. Create a matrix of address, bit, polarity, level/pulse behavior, effect, and
   expected duration.
5. Record uncertainty explicitly instead of embedding guesses in HDL.

Acceptance criteria:

- Every sound write maps to a named control or documented unknown.
- Mute and sound-enable polarity are known.
- Sustained controls are distinguished from one-shot triggers.
- Q6 motor/rocket behavior is understood enough to preserve motor control.

### Phase 1: controls and diagnostics

1. Add sound address decoding beside the existing CPU memory decode.
2. Implement the LS259-equivalent latch and pulse extraction.
3. Expose each effect control in simulation.
4. Add a temporary diagnostic mode that cycles through effects without gameplay.
5. Keep output silent until the mixer produces valid signed samples.

Acceptance criteria:

- A testbench proves representative latch writes.
- One-shot controls emit exactly one trigger per event.
- Reset, mute, and disable suppress every voice.
- The game still boots and plays without video/input regressions.

### Phase 2: first audible implementation

Implement recognizable approximations in this order:

1. Player shot: swept tone/noise with a short decay.
2. Warning/emergency: repeating low-frequency or two-tone modulation.
3. Invader and invader hit: rate/pitch influenced by the distance bits.
4. UFO and UFO hit: oscillator/noise combinations with separate envelopes.
5. Bomb and explosion: filtered LFSR noise with different decay and pitch.
6. Rocket: sustained/swept source tied to verified rocket control.
7. Character/word: approximate after its schematic source is understood.

Use phase accumulators, a maximal-length LFSR, fixed-point envelopes, and a wider
signed mixer. Saturate instead of wrapping at the MiSTer output width.

Acceptance criteria:

- No DC offset, numeric wrap, uncontrolled clipping, or stuck voice after reset.
- Effects occur at correct gameplay moments and are audibly distinct.
- Invader-distance controls affect the intended property.
- Dual-mono audio reaches both MiSTer channels.
- FPGA resource use and timing remain acceptable.

### Phase 3: SN76477 behavioral model

Replace basic approximations for SN76477-derived effects with the blocks the game
uses: VCO, SLF modulation oscillator, LFSR noise/filter, mixer selection,
attack/decay envelope, and amplitude control.

Derive initial rates and envelope constants from schematic resistor/capacitor
values, then tune against original-board recordings when available.

Acceptance criteria:

- Parameters have physical or measured justification.
- The model is synchronous and synthesizable without inferred latches or
  fabric-derived clocks.
- Output is deterministic across builds.

### Phase 4: filtering and BBD echo

Translate important RC/op-amp stages into fixed-point IIR filters. Approximate
the MN3005/MN3101 with a circular buffer, bounded feedback, low-pass filtering,
and wet/dry mix. Add this only after the dry signal is correct.

Acceptance criteria:

- Delay and feedback cannot become unstable.
- Echo does not cause clipping or excessive block-RAM use.
- A dry bypass remains available for comparison.

### Phase 5: validation and tuning

1. Test reset, writes, trigger duration, envelope completion, saturation, and
   echo-buffer wraparound in HDL simulation.
2. Capture deterministic PCM sequences for regression measurements.
3. Compare event timing with MAME CPU-write traces.
4. Compare timbre and levels with original-cabinet recordings when available.
5. Test on physical MiSTer after every major phase.

Acceptance criteria:

- Tests cover every control-matrix entry.
- Long attract/gameplay runs produce no stuck voices or overflow.
- Remote Quartus compilation completes and its timing report is reviewed.
- The transferred RBF behaves like simulation.

## Remote build and deployment

Use the existing remote Quartus workflow for synthesis, fitting, timing analysis,
and RBF generation because the development PC has limited resources. Keep local
work to editing, linting where available, and small simulations.

For each milestone:

1. Run lightweight local lint/tests when practical.
2. Commit a small, reviewable change.
3. Run the remote compile workflow.
4. Inspect setup and hold reports; fitter success alone is not verification.
5. Transfer only a reviewed RBF and retain the previous known-good build.
6. Exercise diagnostic effects, attract mode, then a full game.

The project already has known timing violations. Sound logic must not deepen the
CPU/video combinational paths. Register control boundaries and pipeline the
mixer; a few audio samples of latency are preferable to worse core timing.

## Risks and open questions

| Risk or question | Mitigation |
| --- | --- |
| Scan/OCR obscures values or labels | Inspect page images and record uncertainty |
| MAME labels/polarities are incomplete | Verify against schematics and CPU traces |
| Q6 overlaps motor/rocket behavior | Preserve motor behavior until both paths are traced |
| 94560AN function is unclear | Trace pins and find a datasheet/equivalent before modelling |
| Character sound uses unusual circuitry | Implement late; allow a perceptual first version |
| BBD costs RAM or becomes unstable | Bound buffer/feedback and provide a bypass |
| Audio worsens timing | Register boundaries and pipeline mixing |
| No original-board recording | Seek preservation recordings and document provenance |

## Recommended first milestone

1. Produce the verified control matrix.
2. Add `stactics_sound_ctrl.sv` and tests for both write groups.
3. Add one diagnostic voice, preferably player shot or warning, through a
   saturating dual-mono mixer.
4. Provide a diagnostic trigger that does not interfere with normal controls.
5. Remote-compile, review timing, transfer, and test on MiSTer.

This proves the full path from CPU write to audible hardware output before time
is invested in detailed analog modelling.

## Repository hygiene

Do not commit the manual scan or game ROMs to the public repository unless their
redistribution rights are clear. Commit derived documentation, original HDL,
tests, and source links. Keep ROMs, manual scans, generated Quartus databases,
and private captures excluded by the relevant ignore rules.
